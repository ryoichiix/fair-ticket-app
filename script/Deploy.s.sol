// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/FairTicket.sol";

/// Deploys FairTicket and creates one demo event:
/// "Demo Concert 2026" - face price 0.01 MON, resale capped at 110%,
/// 100 tickets max, 2 tickets max per wallet.
contract Deploy is Script {
    function run() external returns (FairTicket) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        FairTicket ticket = new FairTicket();

        ticket.createEvent(
            "Demo Concert 2026",   // name
            0.01 ether,            // facePrice (MON uses 18 decimals, same as ETH)
            11000,                 // maxResaleBps -> 110% of face price
            100,                   // maxSupply
            2                      // maxPerWallet
        );

        vm.stopBroadcast();

        console.log("FairTicket deployed at:", address(ticket));
        return ticket;
    }
}
