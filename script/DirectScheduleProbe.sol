// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SomniaEventHandler} from "@somnia-chain/reactivity-contracts/contracts/SomniaEventHandler.sol";
import {ISomniaReactivityPrecompile} from
    "@somnia-chain/reactivity-contracts/contracts/interfaces/ISomniaReactivityPrecompile.sol";
import {ISomniaEventHandler} from
    "@somnia-chain/reactivity-contracts/contracts/interfaces/ISomniaEventHandler.sol";

/// @title DirectScheduleProbe
/// @notice Verification-only probe. Calls the reactivity precompile (0x0100) DIRECTLY to schedule a
///         self-wake, deliberately BYPASSING the SomniaExtensions library's 32-STT balance guard.
///         Funded with well under 32 STT, it tells us empirically whether that floor is enforced by
///         the protocol (subscribe reverts / wake never fires) or is only a conservative library check
///         (subscribe succeeds and the wake fires anyway). Not product code.
contract DirectScheduleProbe is SomniaEventHandler {
    address public constant PRECOMPILE = address(0x0100);
    address public immutable owner;

    uint256 public wakeCount;
    uint256 public lastWakeTs;

    event Woke(uint256 wakeCount, bytes32 topic0);

    constructor() {
        owner = msg.sender;
    }

    /// @notice Schedule a self-wake at `whenMs` (unix ms) via a raw precompile.subscribe — no balance guard.
    function scheduleDirect(uint256 whenMs) external returns (uint256 subId) {
        require(msg.sender == owner, "not owner");
        ISomniaReactivityPrecompile.SubscriptionData memory d = ISomniaReactivityPrecompile.SubscriptionData({
            eventTopics: [
                ISomniaReactivityPrecompile.Schedule.selector,
                bytes32(whenMs),
                bytes32(0),
                bytes32(0)
            ],
            origin: address(0),
            caller: address(0),
            emitter: PRECOMPILE,
            handlerContractAddress: address(this),
            handlerFunctionSelector: ISomniaEventHandler.onEvent.selector,
            priorityFeePerGas: 0,
            maxFeePerGas: 20 gwei,
            gasLimit: 10_000_000,
            isGuaranteed: false,
            isCoalesced: false
        });
        subId = ISomniaReactivityPrecompile(PRECOMPILE).subscribe(d);
    }

    function _onEvent(address, bytes32[] calldata topics, bytes calldata) internal override {
        wakeCount++;
        lastWakeTs = block.timestamp;
        emit Woke(wakeCount, topics.length > 0 ? topics[0] : bytes32(0));
    }

    receive() external payable {}

    function withdraw() external {
        require(msg.sender == owner, "not owner");
        (bool s,) = owner.call{value: address(this).balance}("");
        require(s, "withdraw failed");
    }
}
