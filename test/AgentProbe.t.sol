// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {AgentProbe} from "../src/AgentProbe.sol";
import {IAgentPlatform, Response, Request, ResponseStatus, ConsensusType} from "../src/IAgentPlatform.sol";

/// @dev Minimal platform stand-in: records the last request and lets the test drive the callback.
contract MockPlatform is IAgentPlatform {
    uint256 public nextId = 1;
    uint256 public lastAgentId;
    bytes public lastPayload;

    function createRequest(uint256 agentId, address, bytes4, bytes calldata payload)
        external
        payable
        returns (uint256 requestId)
    {
        lastAgentId = agentId;
        lastPayload = payload;
        return nextId++;
    }

    function createAdvancedRequest(
        uint256 agentId,
        address,
        bytes4,
        bytes calldata payload,
        uint256,
        uint256,
        ConsensusType,
        uint256
    ) external payable returns (uint256 requestId) {
        lastAgentId = agentId;
        lastPayload = payload;
        return nextId++;
    }

    function getRequestDeposit() external pure returns (uint256) {
        return 0;
    }

    /// @dev Deliver a callback as the platform would.
    function deliver(AgentProbe probe, uint256 requestId, Response[] memory responses, ResponseStatus status) external {
        Request memory empty;
        probe.handleResponse(requestId, responses, status, empty);
    }
}

contract AgentProbeTest is Test {
    MockPlatform platform;
    AgentProbe probe;

    function setUp() public {
        platform = new MockPlatform();
        probe = new AgentProbe(IAgentPlatform(address(platform)));
    }

    function _resp(uint256 v, ResponseStatus s, uint256 receipt) internal pure returns (Response memory) {
        return Response({
            validator: address(0xBEEF),
            result: abi.encode(v),
            status: s,
            receipt: receipt,
            timestamp: 0,
            executionCost: 0
        });
    }

    function test_onlyPlatformCanCallback() public {
        Response[] memory rs = new Response[](1);
        rs[0] = _resp(42, ResponseStatus.Success, 7);
        Request memory empty;
        vm.expectRevert(AgentProbe.NotPlatform.selector);
        probe.handleResponse(1, rs, ResponseStatus.Success, empty);
    }

    function test_successTakesMedianAndFirstReceipt() public {
        Response[] memory rs = new Response[](3);
        rs[0] = _resp(10, ResponseStatus.Success, 100);
        rs[1] = _resp(90, ResponseStatus.Success, 101);
        rs[2] = _resp(50, ResponseStatus.Success, 102);
        platform.deliver(probe, 1, rs, ResponseStatus.Success);

        (uint256 requestId, ResponseStatus status, uint256 value, uint256 count, uint256 receipt) = probe.last();
        assertEq(requestId, 1);
        assertEq(uint256(status), uint256(ResponseStatus.Success));
        assertEq(value, 50, "median of 10/50/90");
        assertEq(count, 3);
        assertEq(receipt, 100, "first responding validator's receipt");
    }

    function test_ignoresFailedAndMalformedResults() public {
        Response[] memory rs = new Response[](3);
        rs[0] = _resp(10, ResponseStatus.Success, 100);
        rs[1] = _resp(90, ResponseStatus.Failed, 101); // dropped: not Success
        rs[2] = Response({ // dropped: malformed length
            validator: address(0xBEEF),
            result: hex"1234",
            status: ResponseStatus.Success,
            receipt: 102,
            timestamp: 0,
            executionCost: 0
        });
        platform.deliver(probe, 2, rs, ResponseStatus.Success);

        (,, uint256 value, uint256 count,) = probe.last();
        assertEq(count, 1, "only one usable result");
        assertEq(value, 10);
    }

    function test_nonSuccessStatusZeroesResult() public {
        Response[] memory rs = new Response[](0);
        platform.deliver(probe, 3, rs, ResponseStatus.TimedOut);
        (uint256 requestId, ResponseStatus status, uint256 value, uint256 count,) = probe.last();
        assertEq(requestId, 3);
        assertEq(uint256(status), uint256(ResponseStatus.TimedOut));
        assertEq(value, 0);
        assertEq(count, 0);
    }

    function test_evenCountTakesLowerMedian() public {
        Response[] memory rs = new Response[](4);
        rs[0] = _resp(10, ResponseStatus.Success, 1);
        rs[1] = _resp(20, ResponseStatus.Success, 2);
        rs[2] = _resp(30, ResponseStatus.Success, 3);
        rs[3] = _resp(40, ResponseStatus.Success, 4);
        platform.deliver(probe, 4, rs, ResponseStatus.Success);
        (,, uint256 value,,) = probe.last();
        assertEq(value, 20, "lower-mid for even count: index (4-1)/2 = 1");
    }
}
