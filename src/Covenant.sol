// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SomniaEventHandler} from "@somnia-chain/reactivity-contracts/contracts/SomniaEventHandler.sol";
import {SomniaExtensions} from "@somnia-chain/reactivity-contracts/contracts/interfaces/SomniaExtensions.sol";
import {
    ISomniaReactivityPrecompile
} from "@somnia-chain/reactivity-contracts/contracts/interfaces/ISomniaReactivityPrecompile.sol";
import {IAgentPlatform, IAgentConsumer, Response, Request, ResponseStatus, ConsensusType} from "./IAgentPlatform.sol";
import {IParseWebsiteAgent} from "./IParseWebsiteAgent.sol";

/// @title Covenant
/// @notice A single standing contract that holds escrow for plain-English agreements and enforces
///         them autonomously on Somnia — no keeper, no oracle, no human after deploy. Each milestone
///         keeps its clause in English; at check-time a validator subcommittee reads the real evidence
///         (LLM Parse Website agent) and scores the clause, and the median score releases escrow or,
///         past the deadline, refunds the funder. The contract schedules its own wakes, so no
///         transaction is ever sent to it after the agreement is funded.
/// @dev One singleton owns every schedule and a single >=32-STT buffer (the subscription-owner floor
///      is a balance floor, not a per-subscription stake). `reservedEscrow` walls off agreement funds
///      so validator/agent fees and reactive-tick gas are only ever paid from free balance.
contract Covenant is SomniaEventHandler, IAgentConsumer {
    using SomniaExtensions for *;

    // ---------------------------------------------------------------------
    // Types
    // ---------------------------------------------------------------------

    enum MilestoneState {
        Pending, // armed, waiting for its scheduled check
        Checking, // an agent request is in flight
        Met, // clause satisfied, payout released to payee
        Refunded // deadline passed unmet, payout returned to funder
    }

    /// @notice Caller-supplied milestone definition (one per stage of an agreement).
    struct MilestoneInput {
        string clause; // plain-English condition the panel rules on
        string dataSource; // URL the agent fetches as evidence
        uint64 checkAt; // unix seconds: first check time
        uint64 deadline; // unix seconds: refund the funder if unmet by here
        uint64 checkInterval; // seconds between re-checks until met or past deadline
        uint256 payout; // escrow released to payee on success
        uint8 passThreshold; // median score (0..100) at/above which the clause is "met"
        uint8 subSize; // validator subcommittee size for the judge panel
        uint8 threshold; // validators that must agree for platform-level consensus
    }

    struct Milestone {
        string clause;
        string dataSource;
        uint64 deadline;
        uint64 checkInterval;
        uint64 nextCheckAt;
        uint64 armedMs; // scheduled wake timestamp (ms); 0 = not currently armed
        uint256 payout;
        uint8 passThreshold;
        uint8 subSize;
        uint8 threshold;
        MilestoneState state;
        // last judgment (for the watch dashboard + receipt links)
        uint8 lastScore;
        uint8 lastResponders;
        uint256 lastRequestId;
    }

    struct Agreement {
        address funder;
        address payee;
        uint64 createdAt;
        uint8 settledCount;
        Milestone[] milestones;
    }

    // ---------------------------------------------------------------------
    // Storage
    // ---------------------------------------------------------------------

    IAgentPlatform public immutable platform;
    address public immutable owner;

    /// @notice LLM Parse Website agent id (Somnia testnet default; owner-updatable for forward-compat).
    uint256 public parseAgentId = 12875401142070969085;
    /// @notice Value sent per validator to cover agent execution (Parse Website ~0.10 STT).
    uint256 public perValidatorFee = 0.1 ether;
    /// @notice Per-request agent timeout in seconds (owner-tunable; 0 reverts InvalidTimeout on-chain).
    uint256 public requestTimeout = 120;
    /// @notice Gas/fee headroom that must stay free so reactive ticks and agent fees never touch escrow.
    uint256 public constant GAS_BUFFER = 0.2 ether;
    /// @notice Upper bound on milestones per agreement (bounds the create loop and the index packing).
    uint256 public constant MAX_MILESTONES = 64;

    /// @notice Total escrow owed across all live milestones — never spent on gas or agent fees.
    uint256 public reservedEscrow;

    uint256 public nextAgreementId = 1;
    mapping(uint256 => Agreement) private _agreements;

    /// @dev Scheduled-wake routing: SECOND timestamp -> packed (agreementId, milestoneIndex)+1.
    ///      Keyed by seconds, not milliseconds: the chain dispatches Schedule wakes with the actual
    ///      tick time in topic[1] (observed ~25ms after the requested ms), so exact-ms routing misses.
    ///      We always arm at second-boundary+1ms, so requested and dispatched times share a second.
    mapping(uint256 => uint256) private _checkAt;
    /// @dev In-flight agent request -> packed (agreementId, milestoneIndex)+1.
    mapping(uint256 => uint256) private _requestCtx;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event AgreementCreated(
        uint256 indexed agreementId, address indexed funder, address indexed payee, uint256 totalEscrow
    );
    event CheckScheduled(uint256 indexed agreementId, uint256 indexed milestoneIndex, uint256 timestampMillis);
    event CheckArmDeferred(uint256 indexed agreementId, uint256 indexed milestoneIndex);
    event CheckFired(uint256 indexed agreementId, uint256 indexed milestoneIndex, uint256 requestId);
    event JudgmentRecorded(
        uint256 indexed agreementId, uint256 indexed milestoneIndex, uint256 requestId, uint8 score, uint8 responders
    );
    event MilestoneReleased(uint256 indexed agreementId, uint256 indexed milestoneIndex, address payee, uint256 payout);
    event MilestoneRefunded(
        uint256 indexed agreementId, uint256 indexed milestoneIndex, address funder, uint256 payout
    );

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------

    error NotPlatform();
    error NotOwner();
    error NoMilestones();
    error EscrowMismatch(uint256 expected, uint256 sent);
    error BadMilestone();
    error BufferTooLow();
    error UnknownRequest();
    error NotArmable();

    constructor(IAgentPlatform _platform) {
        platform = _platform;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    // ---------------------------------------------------------------------
    // Authoring: fund escrow and arm the first milestone
    // ---------------------------------------------------------------------

    /// @notice Create and fund an agreement; arms the first milestone's scheduled check.
    /// @dev msg.value must equal the sum of milestone payouts. The 32-STT buffer is funded separately
    ///      by the owner via `receive`; this call must leave free balance >= 32 STT + GAS_BUFFER so
    ///      reactive ticks and agent fees never draw on escrow.
    function createAgreement(address payee, MilestoneInput[] calldata milestones)
        external
        payable
        returns (uint256 agreementId)
    {
        if (milestones.length == 0) revert NoMilestones();
        if (milestones.length > MAX_MILESTONES) revert BadMilestone();

        uint256 total;
        for (uint256 i = 0; i < milestones.length; i++) {
            MilestoneInput calldata m = milestones[i];
            if (
                m.payout == 0 || m.subSize == 0 || m.threshold == 0 || m.threshold > m.subSize || m.passThreshold == 0
                    || m.passThreshold > 100 || m.deadline <= m.checkAt
            ) revert BadMilestone();
            total += m.payout;
        }
        if (msg.value != total) revert EscrowMismatch(total, msg.value);

        agreementId = nextAgreementId++;
        Agreement storage a = _agreements[agreementId];
        a.funder = msg.sender;
        a.payee = payee;
        a.createdAt = uint64(block.timestamp);

        for (uint256 i = 0; i < milestones.length; i++) {
            MilestoneInput calldata mi = milestones[i];
            a.milestones
                .push(
                    Milestone({
                        clause: mi.clause,
                        dataSource: mi.dataSource,
                        deadline: mi.deadline,
                        checkInterval: mi.checkInterval,
                        nextCheckAt: mi.checkAt,
                        armedMs: 0,
                        payout: mi.payout,
                        passThreshold: mi.passThreshold,
                        subSize: mi.subSize,
                        threshold: mi.threshold,
                        state: MilestoneState.Pending,
                        lastScore: 0,
                        lastResponders: 0,
                        lastRequestId: 0
                    })
                );
        }

        reservedEscrow += total;
        // Escrow just landed as msg.value; it must never end up subsidizing gas or agent fees.
        if (freeBalance() < GAS_BUFFER) revert BufferTooLow();

        emit AgreementCreated(agreementId, msg.sender, payee, total);

        // A check that is already due fires inside the funding transaction itself (agent leg only —
        // no owner floor needed). Future checks self-schedule via the reactivity layer, which
        // requires the 32-STT subscription-owner floor at scheduling time and defers below it.
        if (a.milestones[0].nextCheckAt <= block.timestamp) {
            _fireCheck(agreementId, 0);
        } else {
            _scheduleCheck(agreementId, 0);
        }
    }

    // ---------------------------------------------------------------------
    // Wake: the chain invokes this at the scheduled timestamp (no tx sent)
    // ---------------------------------------------------------------------

    /// @inheritdoc SomniaEventHandler
    /// @dev Base contract already gated msg.sender == reactivity precompile. For scheduled wakes,
    ///      topic[0] is Schedule.selector and topic[1] is the millisecond timestamp we routed on.
    function _onEvent(address, bytes32[] calldata eventTopics, bytes calldata) internal override {
        if (eventTopics.length < 2) return;
        if (eventTopics[0] != ISomniaReactivityPrecompile.Schedule.selector) return;

        uint256 tsSec = uint256(eventTopics[1]) / 1000; // dispatch carries the actual tick ms
        uint256 packed = _checkAt[tsSec];
        if (packed == 0) return; // already handled or unknown timestamp
        delete _checkAt[tsSec];

        (uint256 agreementId, uint256 mIdx) = _unpack(packed);
        _fireCheck(agreementId, mIdx);
    }

    // ---------------------------------------------------------------------
    // Perceive + Judge: fire one consensus request, or refund if past deadline
    // ---------------------------------------------------------------------

    function _fireCheck(uint256 agreementId, uint256 mIdx) private {
        Agreement storage a = _agreements[agreementId];
        Milestone storage m = a.milestones[mIdx];
        m.armedMs = 0; // the scheduled wake has fired and is being consumed
        if (m.state != MilestoneState.Pending) return; // settled or already in flight

        // Past the deadline and still unmet -> refund the funder; no need to spend on a judgment.
        if (block.timestamp >= m.deadline) {
            _refund(agreementId, mIdx);
            return;
        }

        // Pay agent fees from free balance only, keeping GAS_BUFFER headroom so reactive-tick gas and
        // the 32-STT floor are never drawn from escrow. If the buffer is too thin, retry later rather
        // than stranding the milestone (the scheduled wake was already consumed) — it degrades to a
        // deadline refund if the owner never tops up.
        uint256 fee = perValidatorFee * m.subSize;
        if (freeBalance() < fee + GAS_BUFFER) {
            _rearmOrRefund(agreementId, mIdx);
            return;
        }

        bytes memory payload = abi.encodeWithSelector(
            IParseWebsiteAgent.ExtractANumber.selector,
            "covenant_score",
            m.clause,
            uint256(0),
            uint256(100),
            _judgePrompt(m.clause),
            m.dataSource,
            false, // scrape the URL directly
            uint8(1), // one page
            uint8(0) // we apply our own pass threshold over the median
        );

        uint256 requestId = platform.createAdvancedRequest{value: fee}(
            parseAgentId,
            address(this),
            this.handleResponse.selector,
            payload,
            m.subSize,
            m.threshold,
            ConsensusType.Threshold,
            requestTimeout
        );

        m.state = MilestoneState.Checking;
        _requestCtx[requestId] = _pack(agreementId, mIdx);
        emit CheckFired(agreementId, mIdx, requestId);
    }

    // ---------------------------------------------------------------------
    // Act: the platform delivers the panel's verdict here
    // ---------------------------------------------------------------------

    /// @inheritdoc IAgentConsumer
    function handleResponse(
        uint256 requestId,
        Response[] memory responses,
        ResponseStatus status,
        Request memory /* details */
    )
        external
        override
    {
        if (msg.sender != address(platform)) revert NotPlatform();

        uint256 packed = _requestCtx[requestId];
        if (packed == 0) revert UnknownRequest();
        delete _requestCtx[requestId];

        (uint256 agreementId, uint256 mIdx) = _unpack(packed);
        Milestone storage m = _agreements[agreementId].milestones[mIdx];
        if (m.state != MilestoneState.Checking) return; // stale callback

        // Agent failed/timed out: drop back to Pending and re-arm a later retry (or deadline refund).
        if (status != ResponseStatus.Success) {
            m.state = MilestoneState.Pending;
            _rearmOrRefund(agreementId, mIdx);
            return;
        }

        (uint256 medianScore, uint256 responders) = _median(responses);
        m.lastScore = uint8(medianScore > 100 ? 100 : medianScore);
        m.lastResponders = uint8(responders > 255 ? 255 : responders);
        m.lastRequestId = requestId;
        emit JudgmentRecorded(agreementId, mIdx, requestId, m.lastScore, m.lastResponders);

        if (responders > 0 && medianScore >= m.passThreshold) {
            _release(agreementId, mIdx);
        } else {
            m.state = MilestoneState.Pending;
            _rearmOrRefund(agreementId, mIdx);
        }
    }

    // ---------------------------------------------------------------------
    // Settlement (checks-effects-interactions; payouts after state + escrow updates)
    // ---------------------------------------------------------------------

    function _release(uint256 agreementId, uint256 mIdx) private {
        Agreement storage a = _agreements[agreementId];
        Milestone storage m = a.milestones[mIdx];
        uint256 payout = m.payout;

        m.state = MilestoneState.Met;
        reservedEscrow -= payout;
        a.settledCount++;

        emit MilestoneReleased(agreementId, mIdx, a.payee, payout);
        _payout(a.payee, payout);
        _armNext(agreementId, mIdx);
    }

    function _refund(uint256 agreementId, uint256 mIdx) private {
        Agreement storage a = _agreements[agreementId];
        Milestone storage m = a.milestones[mIdx];
        if (m.state == MilestoneState.Met || m.state == MilestoneState.Refunded) return;
        uint256 payout = m.payout;

        m.state = MilestoneState.Refunded;
        reservedEscrow -= payout;
        a.settledCount++;

        emit MilestoneRefunded(agreementId, mIdx, a.funder, payout);
        _payout(a.funder, payout);
        _armNext(agreementId, mIdx);
    }

    /// @dev Re-arm the same milestone for its next interval, or refund the funder once past deadline.
    function _rearmOrRefund(uint256 agreementId, uint256 mIdx) private {
        Milestone storage m = _agreements[agreementId].milestones[mIdx];
        uint64 next = m.nextCheckAt + m.checkInterval;
        if (m.checkInterval == 0 || next >= m.deadline || block.timestamp >= m.deadline) {
            // No further useful re-check before the deadline: do a final wake at the deadline to refund.
            m.nextCheckAt = m.deadline;
        } else {
            m.nextCheckAt = next;
        }
        _scheduleCheck(agreementId, mIdx);
    }

    /// @dev Reactive cascade: once a milestone is terminal, arm the next milestone's first check.
    function _armNext(uint256 agreementId, uint256 mIdx) private {
        Agreement storage a = _agreements[agreementId];
        uint256 nextIdx = mIdx + 1;
        if (nextIdx >= a.milestones.length) return;
        if (a.milestones[nextIdx].state == MilestoneState.Pending) {
            _scheduleCheck(agreementId, nextIdx);
        }
    }

    // ---------------------------------------------------------------------
    // Scheduling (self-wake via the reactivity precompile)
    // ---------------------------------------------------------------------

    /// @dev Best-effort: arms a self-wake for a milestone. Critically NON-reverting on a thin buffer —
    ///      the precompile rejects a subscribe below the 32-STT floor, and a revert here would unwind a
    ///      legitimate settlement that called it via _armNext. Instead it leaves the milestone Pending
    ///      and un-armed; anyone can re-arm it with `poke` once the owner tops the buffer up.
    function _scheduleCheck(uint256 agreementId, uint256 mIdx) private {
        Milestone storage m = _agreements[agreementId].milestones[mIdx];

        // Mirror SomniaExtensions._subscribe's balance guard so we never call into a guaranteed revert.
        if (address(this).balance < SomniaExtensions.SUBSCRIPTION_OWNER_MINIMUM_BALANCE) {
            m.armedMs = 0;
            emit CheckArmDeferred(agreementId, mIdx);
            return;
        }

        uint256 whenSec = m.nextCheckAt;
        if (whenSec <= block.timestamp) whenSec = block.timestamp + 1;
        if (whenSec > m.deadline) whenSec = uint256(m.deadline) + 1; // final wake to trigger refund

        // Routing is second-granular (see _checkAt); keep each routed second unique, and arm the
        // wake at second-boundary+1ms so the chain's actual tick lands inside the same second.
        while (_checkAt[whenSec] != 0) whenSec++;
        uint256 whenMs = whenSec * 1000 + 1;

        _checkAt[whenSec] = _pack(agreementId, mIdx);
        m.armedMs = uint64(whenMs);
        SomniaExtensions.scheduleSubscriptionAtTimestamp(
            address(this), whenMs, SomniaExtensions.defaultSubscriptionOptions()
        );
        emit CheckScheduled(agreementId, mIdx, whenMs);
    }

    /// @notice Permissionless recovery: re-arm a milestone that's Pending but lost its schedule
    ///         (e.g. armed during a thin-buffer window). Self-heals once the buffer is topped up.
    function poke(uint256 agreementId, uint256 mIdx) external {
        Milestone storage m = _agreements[agreementId].milestones[mIdx];
        if (m.state != MilestoneState.Pending || m.armedMs != 0) revert NotArmable();
        _scheduleCheck(agreementId, mIdx);
    }

    /// @notice Permissionless recovery: refund a milestone whose deadline passed while still
    ///         Pending (e.g. its wake was lost). Mirrors the autonomous deadline refund exactly;
    ///         it cannot fire early and pays the same party the contract would have paid.
    function reclaimExpired(uint256 agreementId, uint256 mIdx) external {
        Milestone storage m = _agreements[agreementId].milestones[mIdx];
        if (m.state != MilestoneState.Pending || block.timestamp < m.deadline) revert NotArmable();
        m.armedMs = 0;
        _refund(agreementId, mIdx);
    }

    // ---------------------------------------------------------------------
    // Owner: buffer management + config
    // ---------------------------------------------------------------------

    /// @notice Fund the singleton's 32-STT subscription buffer (and gas headroom).
    receive() external payable {}

    /// @notice Withdraw free balance only — reserved escrow and the subscription floor stay put.
    function withdrawFree(uint256 amount) external onlyOwner {
        uint256 floor = SomniaExtensions.SUBSCRIPTION_OWNER_MINIMUM_BALANCE + GAS_BUFFER;
        require(freeBalance() >= amount + floor, "would breach buffer");
        _payout(owner, amount);
    }

    /// @notice Decommission the singleton: recover the entire buffer once no escrow is live.
    ///         Owner-only and blocked while any agreement holds unsettled escrow, so it can never
    ///         touch user funds — it only frees the owner's own 32-STT floor for redeployment.
    function shutdown() external onlyOwner {
        require(reservedEscrow == 0, "live escrow");
        _payout(owner, address(this).balance);
    }

    function setParseAgentId(uint256 id) external onlyOwner {
        parseAgentId = id;
    }

    function setPerValidatorFee(uint256 fee) external onlyOwner {
        perValidatorFee = fee;
    }

    function setRequestTimeout(uint256 secs) external onlyOwner {
        requestTimeout = secs;
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------

    /// @notice Balance not committed to escrow — what's available for gas, agent fees and withdrawal.
    function freeBalance() public view returns (uint256) {
        uint256 bal = address(this).balance;
        return bal > reservedEscrow ? bal - reservedEscrow : 0;
    }

    function getAgreement(uint256 agreementId)
        external
        view
        returns (address funder, address payee, uint64 createdAt, uint8 settledCount, uint256 milestoneCount)
    {
        Agreement storage a = _agreements[agreementId];
        return (a.funder, a.payee, a.createdAt, a.settledCount, a.milestones.length);
    }

    function getMilestone(uint256 agreementId, uint256 mIdx) external view returns (Milestone memory) {
        return _agreements[agreementId].milestones[mIdx];
    }

    // ---------------------------------------------------------------------
    // Internal helpers
    // ---------------------------------------------------------------------

    function _judgePrompt(string memory clause) private pure returns (string memory) {
        return string.concat(
            "Score from 0 to 100 how fully this condition is satisfied by the page content. ",
            "100 = fully satisfied, 0 = not at all. Condition: ",
            clause
        );
    }

    /// @dev Median of successful, 32-byte (uint256) validator results. Even count -> lower-mid.
    function _median(Response[] memory responses) private pure returns (uint256 median, uint256 ok) {
        uint256 n = responses.length;
        uint256[] memory vals = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            Response memory r = responses[i];
            if (r.status != ResponseStatus.Success || r.result.length != 32) continue;
            vals[ok++] = abi.decode(r.result, (uint256));
        }
        if (ok == 0) return (0, 0);
        for (uint256 i = 1; i < ok; i++) {
            uint256 key = vals[i];
            uint256 j = i;
            while (j > 0 && vals[j - 1] > key) {
                vals[j] = vals[j - 1];
                j--;
            }
            vals[j] = key;
        }
        median = vals[(ok - 1) / 2];
    }

    function _payout(address to, uint256 amount) private {
        (bool sent,) = to.call{value: amount}("");
        require(sent, "payout failed");
    }

    function _pack(uint256 agreementId, uint256 mIdx) private pure returns (uint256) {
        return ((agreementId << 16) | mIdx) + 1;
    }

    function _unpack(uint256 packed) private pure returns (uint256 agreementId, uint256 mIdx) {
        uint256 v = packed - 1;
        return (v >> 16, v & 0xffff);
    }
}
