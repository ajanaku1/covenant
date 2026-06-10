// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {Covenant} from "../src/Covenant.sol";
import {IAgentPlatform} from "../src/IAgentPlatform.sol";

/// @notice Deploy the singleton Covenant and fund its >=32-STT subscription buffer in one shot.
/// @dev Usage:
///   forge script script/Deploy.s.sol:Deploy --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
/// Env:
///   PLATFORM_ADDRESS  agent platform (testnet 0x037Bb9C718F3f7fe5eCBDB0b600D607b52706776)
///   BUFFER_WEI        optional; value to send as the subscription buffer (default 33 STT)
contract Deploy is Script {
    function run() external {
        address platform = vm.envAddress("PLATFORM_ADDRESS");
        uint256 buffer = vm.envOr("BUFFER_WEI", uint256(33 ether));

        vm.startBroadcast();
        Covenant covenant = new Covenant(IAgentPlatform(platform));
        if (buffer > 0) {
            (bool sent,) = address(covenant).call{value: buffer}("");
            require(sent, "buffer funding failed");
        }
        vm.stopBroadcast();

        console2.log("Covenant deployed:", address(covenant));
        console2.log("platform:", platform);
        console2.log("buffer funded (wei):", buffer);
        console2.log("freeBalance (wei):", covenant.freeBalance());
    }
}
