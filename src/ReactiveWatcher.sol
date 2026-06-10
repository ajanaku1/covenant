// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SomniaEventHandler} from "@somnia-chain/reactivity-contracts/contracts/SomniaEventHandler.sol";
import {SomniaExtensions} from "@somnia-chain/reactivity-contracts/contracts/interfaces/SomniaExtensions.sol";

/// @title ReactiveWatcher
/// @notice Phase-0 de-risk helper: the smallest contract that proves the reactivity leg — it owns a
///         >=32-STT buffer, schedules its own wake at a future timestamp, and the chain auto-invokes
///         `_onEvent` with no transaction sent. Also exercises the event-filter subscription path
///         against InsuredProtocol. Establishes the exact wake mechanism Covenant builds milestones on.
/// @dev The 32-STT minimum is a balance floor on the *subscription owner* (this contract), not a
///      per-subscription stake — the same singleton can own many schedules from one buffer.
contract ReactiveWatcher is SomniaEventHandler {
    using SomniaExtensions for *;

    address public immutable owner;

    uint256 public wakeCount;
    uint256 public lastWakeTimestamp;
    bytes32 public lastTopic0;

    event Scheduled(uint256 indexed subscriptionId, uint256 timestampMillis);
    event Subscribed(uint256 indexed subscriptionId, address emitter);
    event Woke(uint256 wakeCount, address emitter, bytes32 topic0);

    error NotOwner();

    constructor() {
        owner = msg.sender;
    }

    /// @notice Schedule a self-wake at an absolute millisecond timestamp.
    /// @dev Requires this contract to already hold >= 32 STT (SUBSCRIPTION_OWNER_MINIMUM_BALANCE).
    function scheduleWake(uint256 timestampMillis) external returns (uint256 subscriptionId) {
        if (msg.sender != owner) revert NotOwner();
        subscriptionId = SomniaExtensions.scheduleSubscriptionAtTimestamp(
            address(this), timestampMillis, SomniaExtensions.defaultSubscriptionOptions()
        );
        emit Scheduled(subscriptionId, timestampMillis);
    }

    /// @notice Subscribe to a specific emitter's logs (event-filter path).
    function watchEmitter(address emitter, bytes32 eventTopic0) external returns (uint256 subscriptionId) {
        if (msg.sender != owner) revert NotOwner();
        SomniaExtensions.SubscriptionFilter memory filter = SomniaExtensions.SubscriptionFilter({
            eventTopics: [eventTopic0, bytes32(0), bytes32(0), bytes32(0)], origin: address(0), emitter: emitter
        });
        subscriptionId =
            SomniaExtensions.subscribe(address(this), filter, SomniaExtensions.defaultSubscriptionOptions());
        emit Subscribed(subscriptionId, emitter);
    }

    /// @inheritdoc SomniaEventHandler
    /// @dev Base contract already gates msg.sender == reactivity precompile before delegating here.
    function _onEvent(
        address emitter,
        bytes32[] calldata eventTopics,
        bytes calldata /* data */
    )
        internal
        override
    {
        wakeCount++;
        lastWakeTimestamp = block.timestamp;
        lastTopic0 = eventTopics.length > 0 ? eventTopics[0] : bytes32(0);
        emit Woke(wakeCount, emitter, lastTopic0);
    }

    /// @notice Fund the 32-STT subscription buffer.
    receive() external payable {}

    function withdraw() external {
        if (msg.sender != owner) revert NotOwner();
        (bool sent,) = owner.call{value: address(this).balance}("");
        require(sent, "withdraw failed");
    }
}
