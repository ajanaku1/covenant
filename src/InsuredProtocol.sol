// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title InsuredProtocol
/// @notice Phase-0 de-risk helper: a stand-in "real world" contract that emits an event a reactive
///         watcher can subscribe to. Lets us prove the event-filter subscription path without waiting
///         on a third-party contract. Covenant itself wakes on scheduled timestamps rather than events,
///         but proving both reactivity modes here keeps the spine honest.
contract InsuredProtocol {
    event ClaimTriggered(bytes32 indexed policyId, uint256 amount);

    /// @notice Emit a claim event for a policy; a subscribed watcher reacts to this log.
    function triggerClaim(bytes32 policyId, uint256 amount) external {
        emit ClaimTriggered(policyId, amount);
    }
}
