// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {Covenant} from "../src/Covenant.sol";

/// @notice Create and fund the canonical demo agreement on a deployed Covenant singleton.
/// @dev Usage:
///   forge script script/CreateDemo.s.sol:CreateDemo --rpc-url $RPC_URL --private-key $PRIVATE_KEY \
///     --broadcast --skip-simulation --gas-estimate-multiplier 1600
/// Env:
///   COVENANT_ADDRESS  deployed singleton
///   PAYEE             payout recipient
///   DATA_SOURCE       URL the judge panel reads (default: the live Covenant frontend)
contract CreateDemo is Script {
    function run() external {
        Covenant covenant = Covenant(payable(vm.envAddress("COVENANT_ADDRESS")));
        address payee = vm.envAddress("PAYEE");
        string memory dataSource = vm.envOr("DATA_SOURCE", string("https://covenant-beta.vercel.app"));

        Covenant.MilestoneInput[] memory ms = new Covenant.MilestoneInput[](1);
        ms[0] = Covenant.MilestoneInput({
            clause: "The website is live and its content mentions Somnia",
            dataSource: dataSource,
            checkAt: uint64(block.timestamp + 240),
            deadline: uint64(block.timestamp + 1800),
            checkInterval: 300,
            payout: 0.02 ether,
            passThreshold: 70,
            subSize: 3,
            threshold: 2
        });

        vm.startBroadcast();
        uint256 id = covenant.createAgreement{value: 0.02 ether}(payee, ms);
        vm.stopBroadcast();

        console2.log("agreementId:", id);
        console2.log("first check at:", block.timestamp + 240);
        console2.log("deadline:", block.timestamp + 1800);
    }
}
