// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {Covenant} from "../src/Covenant.sol";
import {IAgentPlatform, Response, Request, ResponseStatus, ConsensusType} from "../src/IAgentPlatform.sol";
import {
    ISomniaReactivityPrecompile
} from "@somnia-chain/reactivity-contracts/contracts/interfaces/ISomniaReactivityPrecompile.sol";
import {SomniaExtensions} from "@somnia-chain/reactivity-contracts/contracts/interfaces/SomniaExtensions.sol";

/// @dev Stand-in for the reactivity precompile at 0x0100: hands back incrementing subscription ids.
contract MockReactivity {
    uint256 public counter;

    function subscribe(ISomniaReactivityPrecompile.SubscriptionData calldata) external returns (uint256) {
        return ++counter;
    }

    function unsubscribe(uint256) external {}
}

/// @dev Stand-in for the agent platform: records the last request and replays callbacks on demand.
contract MockPlatform is IAgentPlatform {
    uint256 public nextId = 1;
    uint256 public lastAgentId;
    uint256 public lastValue;

    function createRequest(uint256 agentId, address, bytes4, bytes calldata) external payable returns (uint256) {
        lastAgentId = agentId;
        lastValue = msg.value;
        return nextId++;
    }

    function createAdvancedRequest(
        uint256 agentId,
        address,
        bytes4,
        bytes calldata,
        uint256,
        uint256,
        ConsensusType,
        uint256
    ) external payable returns (uint256) {
        lastAgentId = agentId;
        lastValue = msg.value;
        return nextId++;
    }

    function getRequestDeposit() external pure returns (uint256) {
        return 0;
    }

    function deliver(Covenant c, uint256 requestId, Response[] memory rs, ResponseStatus status) external {
        Request memory empty;
        c.handleResponse(requestId, rs, status, empty);
    }
}

contract CovenantTest is Test {
    MockPlatform platform;
    Covenant covenant;
    address constant PRECOMPILE = address(0x0100);

    address funder = address(0xF00D);
    address payee = address(0xBEEF);

    uint64 checkAt;
    uint64 deadline;
    uint64 interval = 1 days;
    uint256 payout = 5 ether;

    function setUp() public {
        vm.etch(PRECOMPILE, address(new MockReactivity()).code);
        platform = new MockPlatform();
        covenant = new Covenant(IAgentPlatform(address(platform)));
        // Fund the singleton's 32-STT buffer + headroom.
        vm.deal(address(covenant), 40 ether);
        vm.deal(funder, 100 ether);

        checkAt = uint64(block.timestamp + 1 hours);
        deadline = uint64(block.timestamp + 7 days);
    }

    function _oneMilestone() internal view returns (Covenant.MilestoneInput[] memory ms) {
        ms = new Covenant.MilestoneInput[](1);
        ms[0] = Covenant.MilestoneInput({
            clause: "The site at https://x.com is live and mentions Somnia",
            dataSource: "https://x.com",
            checkAt: checkAt,
            deadline: deadline,
            checkInterval: interval,
            payout: payout,
            passThreshold: 70,
            subSize: 3,
            threshold: 2
        });
    }

    function _create() internal returns (uint256 id) {
        vm.prank(funder);
        id = covenant.createAgreement{value: payout}(payee, _oneMilestone());
    }

    function _whenMs(uint64 sec) internal pure returns (uint256) {
        return uint256(sec) * 1000 + 1;
    }

    function _wake(uint256 whenMs) internal {
        bytes32[] memory topics = new bytes32[](2);
        topics[0] = ISomniaReactivityPrecompile.Schedule.selector;
        topics[1] = bytes32(whenMs);
        vm.prank(PRECOMPILE);
        covenant.onEvent(PRECOMPILE, topics, "");
    }

    function _resp(uint256 v, ResponseStatus s) internal pure returns (Response memory) {
        return Response(address(0xABCD), abi.encode(v), s, 999, 0, 0);
    }

    // ---------------------------------------------------------------- create

    function test_createReservesEscrowAndStores() public {
        uint256 id = _create();
        assertEq(covenant.reservedEscrow(), payout);
        assertEq(covenant.freeBalance(), 40 ether); // 45 - 5 reserved
        (address f, address p,, uint8 settled, uint256 count) = covenant.getAgreement(id);
        assertEq(f, funder);
        assertEq(p, payee);
        assertEq(settled, 0);
        assertEq(count, 1);
        assertEq(uint256(covenant.getMilestone(id, 0).state), uint256(Covenant.MilestoneState.Pending));
    }

    function test_revertOnEscrowMismatch() public {
        vm.prank(funder);
        vm.expectRevert(abi.encodeWithSelector(Covenant.EscrowMismatch.selector, payout, payout + 1));
        covenant.createAgreement{value: payout + 1}(payee, _oneMilestone());
    }

    function test_revertWhenBufferWouldBreak() public {
        // Drain the buffer so the incoming escrow can't keep 32 + GAS_BUFFER free.
        vm.prank(address(covenant));
        (bool ok,) = funder.call{value: 40 ether}("");
        assertTrue(ok);
        vm.prank(funder);
        vm.expectRevert(Covenant.BufferTooLow.selector);
        covenant.createAgreement{value: payout}(payee, _oneMilestone());
    }

    function test_revertOnBadMilestone() public {
        Covenant.MilestoneInput[] memory ms = _oneMilestone();
        ms[0].threshold = 4; // > subSize
        vm.prank(funder);
        vm.expectRevert(Covenant.BadMilestone.selector);
        covenant.createAgreement{value: payout}(payee, ms);
    }

    // ------------------------------------------------------------------ wake

    function test_wakeFiresConsensusRequest() public {
        uint256 id = _create();
        _wake(_whenMs(checkAt));
        assertEq(uint256(covenant.getMilestone(id, 0).state), uint256(Covenant.MilestoneState.Checking));
        assertEq(platform.lastAgentId(), covenant.parseAgentId());
        assertEq(platform.lastValue(), covenant.perValidatorFee() * 3); // fee per validator * subSize
    }

    function test_unknownTimestampIsNoop() public {
        _create();
        _wake(_whenMs(checkAt) + 12345); // never scheduled
        // milestone stays Pending, no request fired
        assertEq(platform.lastAgentId(), 0);
    }

    // --------------------------------------------------------------- release

    function test_releaseOnPassingMedian() public {
        uint256 id = _create();
        _wake(_whenMs(checkAt));

        Response[] memory rs = new Response[](3);
        rs[0] = _resp(60, ResponseStatus.Success);
        rs[1] = _resp(80, ResponseStatus.Success); // median = 80 >= 70
        rs[2] = _resp(95, ResponseStatus.Success);

        uint256 before = payee.balance;
        platform.deliver(covenant, 1, rs, ResponseStatus.Success);

        assertEq(payee.balance, before + payout);
        assertEq(covenant.reservedEscrow(), 0);
        Covenant.Milestone memory m = covenant.getMilestone(id, 0);
        assertEq(uint256(m.state), uint256(Covenant.MilestoneState.Met));
        assertEq(m.lastScore, 80);
        assertEq(m.lastResponders, 3);
        assertEq(m.lastRequestId, 1);
    }

    function test_belowThresholdRearmsSameMilestone() public {
        uint256 id = _create();
        _wake(_whenMs(checkAt));

        Response[] memory rs = new Response[](3);
        rs[0] = _resp(10, ResponseStatus.Success);
        rs[1] = _resp(20, ResponseStatus.Success); // median 20 < 70
        rs[2] = _resp(30, ResponseStatus.Success);
        platform.deliver(covenant, 1, rs, ResponseStatus.Success);

        Covenant.Milestone memory m = covenant.getMilestone(id, 0);
        assertEq(uint256(m.state), uint256(Covenant.MilestoneState.Pending), "re-armed");
        assertEq(m.nextCheckAt, checkAt + interval, "advanced one interval");
        assertEq(covenant.reservedEscrow(), payout, "escrow still held");
    }

    function test_agentFailureRearms() public {
        uint256 id = _create();
        _wake(_whenMs(checkAt));
        Response[] memory rs = new Response[](0);
        platform.deliver(covenant, 1, rs, ResponseStatus.TimedOut);
        Covenant.Milestone memory m = covenant.getMilestone(id, 0);
        assertEq(uint256(m.state), uint256(Covenant.MilestoneState.Pending));
        assertEq(covenant.reservedEscrow(), payout);
    }

    function test_unaffordableCheckRearmsNotStranded() public {
        uint256 id = _create();
        // Make the per-validator fee unaffordable from free balance.
        vm.prank(covenant.owner());
        covenant.setPerValidatorFee(20 ether); // 20 * 3 = 60 > free 40
        _wake(_whenMs(checkAt));
        // No request fired, but the milestone re-armed for a later interval instead of stranding.
        assertEq(platform.lastAgentId(), 0);
        Covenant.Milestone memory m = covenant.getMilestone(id, 0);
        assertEq(uint256(m.state), uint256(Covenant.MilestoneState.Pending));
        assertEq(m.nextCheckAt, checkAt + interval);
    }

    function test_thinBufferDefersThenPokeRecovers() public {
        uint256 id = _create(); // armed at checkAt
        _wake(_whenMs(checkAt)); // fires request 1 (free balance still ample)

        // Simulate the buffer eroding below the 32-STT floor between wake and verdict.
        vm.deal(address(covenant), 10 ether);

        // A below-threshold verdict re-arms via _scheduleCheck, which must DEFER (not revert) here.
        Response[] memory rs = new Response[](1);
        rs[0] = _resp(20, ResponseStatus.Success);
        platform.deliver(covenant, 1, rs, ResponseStatus.Success);

        Covenant.Milestone memory m = covenant.getMilestone(id, 0);
        assertEq(uint256(m.state), uint256(Covenant.MilestoneState.Pending));
        assertEq(m.armedMs, 0, "deferred: not currently armed");

        // poke before top-up still defers (balance < floor), milestone stays recoverable.
        covenant.poke(id, 0);
        assertEq(covenant.getMilestone(id, 0).armedMs, 0);

        // Owner tops the buffer back up; anyone can now re-arm it.
        vm.deal(address(covenant), 40 ether);
        covenant.poke(id, 0);
        assertTrue(covenant.getMilestone(id, 0).armedMs != 0, "re-armed after top-up");

        // Cannot poke an already-armed milestone.
        vm.expectRevert(Covenant.NotArmable.selector);
        covenant.poke(id, 0);
    }

    // ---------------------------------------------------------------- refund

    function test_refundWhenWokePastDeadline() public {
        uint256 id = _create();
        vm.warp(uint256(deadline) + 1);
        uint256 before = funder.balance;
        // The final wake lands at deadline; _fireCheck sees the deadline and refunds without an agent call.
        _wake(_whenMs(checkAt));

        assertEq(funder.balance, before + payout);
        assertEq(covenant.reservedEscrow(), 0);
        assertEq(uint256(covenant.getMilestone(id, 0).state), uint256(Covenant.MilestoneState.Refunded));
        assertEq(platform.lastAgentId(), 0, "no agent spend on a deadline refund");
    }

    // ------------------------------------------------------------- callbacks

    function test_handleResponseRejectsNonPlatform() public {
        _create();
        _wake(_whenMs(checkAt));
        Response[] memory rs = new Response[](1);
        rs[0] = _resp(80, ResponseStatus.Success);
        Request memory empty;
        vm.expectRevert(Covenant.NotPlatform.selector);
        covenant.handleResponse(1, rs, ResponseStatus.Success, empty);
    }

    function test_handleResponseRejectsUnknownRequest() public {
        Response[] memory rs = new Response[](1);
        rs[0] = _resp(80, ResponseStatus.Success);
        vm.expectRevert(Covenant.UnknownRequest.selector);
        platform.deliver(covenant, 999, rs, ResponseStatus.Success);
    }

    function test_staleCallbackIgnoredAfterSettlement() public {
        _create();
        _wake(_whenMs(checkAt));
        Response[] memory rs = new Response[](1);
        rs[0] = _resp(90, ResponseStatus.Success);
        platform.deliver(covenant, 1, rs, ResponseStatus.Success); // releases, deletes ctx
        // Replaying the same requestId now reverts as unknown (ctx consumed) — no double payout.
        vm.expectRevert(Covenant.UnknownRequest.selector);
        platform.deliver(covenant, 1, rs, ResponseStatus.Success);
        assertEq(covenant.reservedEscrow(), 0);
    }

    // ---------------------------------------------------------------- cascade

    function test_cascadeArmsNextMilestoneOnSettle() public {
        Covenant.MilestoneInput[] memory ms = new Covenant.MilestoneInput[](2);
        ms[0] = _oneMilestone()[0];
        ms[1] = _oneMilestone()[0];
        ms[1].payout = 3 ether;

        vm.prank(funder);
        uint256 id = covenant.createAgreement{value: payout + 3 ether}(payee, ms);
        assertEq(covenant.reservedEscrow(), payout + 3 ether);

        // Settle milestone 0 -> milestone 1 should arm (request id 1 was milestone 0's check).
        _wake(_whenMs(checkAt));
        Response[] memory rs = new Response[](1);
        rs[0] = _resp(90, ResponseStatus.Success);
        platform.deliver(covenant, 1, rs, ResponseStatus.Success);

        assertEq(uint256(covenant.getMilestone(id, 0).state), uint256(Covenant.MilestoneState.Met));
        assertEq(uint256(covenant.getMilestone(id, 1).state), uint256(Covenant.MilestoneState.Pending));
        // Wake milestone 1 and confirm a fresh request fires for it.
        _wake(_whenMs(checkAt));
        assertEq(uint256(covenant.getMilestone(id, 1).state), uint256(Covenant.MilestoneState.Checking));
    }

    // -------------------------------------------------------------- owner ops

    function test_withdrawFreeCannotBreachBuffer() public {
        _create(); // balance 45, reserves 5, free = 40
        vm.prank(covenant.owner());
        vm.expectRevert("would breach buffer");
        covenant.withdrawFree(8 ether); // 8 + 33 floor = 41 > 40 free
    }

    function test_withdrawFreeWithinHeadroom() public {
        _create();
        address o = covenant.owner();
        uint256 before = o.balance;
        vm.prank(o);
        covenant.withdrawFree(7 ether); // 7 + 33 = 40 == free, ok
        assertEq(o.balance, before + 7 ether);
    }

    // ------------------------------------------------- dispatch-time routing

    /// @dev Regression: the chain dispatches Schedule wakes with the ACTUAL tick ms (observed
    ///      ~25ms after the requested second-boundary+1ms). Routing must still find the check.
    function test_wakeRoutesDespiteDispatchMsOffset() public {
        uint256 id = _create();
        _wake(_whenMs(checkAt) + 25); // actual tick lands later within the same second
        assertEq(uint256(covenant.getMilestone(id, 0).state), uint256(Covenant.MilestoneState.Checking));
        assertEq(platform.lastValue(), covenant.perValidatorFee() * 3);
    }

    // ------------------------------------------------------ reclaimExpired

    function test_reclaimExpiredRefundsFunder() public {
        uint256 id = _create();
        vm.warp(deadline); // wake was lost; deadline reached with milestone still Pending
        uint256 before = funder.balance;
        covenant.reclaimExpired(id, 0);
        assertEq(uint256(covenant.getMilestone(id, 0).state), uint256(Covenant.MilestoneState.Refunded));
        assertEq(funder.balance, before + payout);
        assertEq(covenant.reservedEscrow(), 0);
    }

    function test_reclaimExpiredRevertsBeforeDeadline() public {
        uint256 id = _create();
        vm.expectRevert(Covenant.NotArmable.selector);
        covenant.reclaimExpired(id, 0);
    }

    function test_reclaimExpiredRevertsOnceSettled() public {
        uint256 id = _create();
        vm.warp(deadline);
        covenant.reclaimExpired(id, 0);
        vm.expectRevert(Covenant.NotArmable.selector);
        covenant.reclaimExpired(id, 0);
    }

    // ------------------------------------------------------------ shutdown

    function test_shutdownRevertsWithLiveEscrow() public {
        _create();
        vm.prank(covenant.owner());
        vm.expectRevert("live escrow");
        covenant.shutdown();
    }

    function test_shutdownRecoversFullBufferWhenEscrowClear() public {
        uint256 id = _create();
        vm.warp(deadline);
        covenant.reclaimExpired(id, 0); // settle the only milestone
        address o = covenant.owner();
        uint256 contractBal = address(covenant).balance;
        uint256 before = o.balance;
        vm.prank(o);
        covenant.shutdown();
        assertEq(o.balance, before + contractBal);
        assertEq(address(covenant).balance, 0);
    }

    function test_shutdownOnlyOwner() public {
        vm.prank(funder);
        vm.expectRevert(Covenant.NotOwner.selector);
        covenant.shutdown();
    }

    /// @dev The owner here is this test contract; accept its withdrawal.
    receive() external payable {}
}
