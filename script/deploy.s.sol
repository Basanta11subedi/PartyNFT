// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {PartyManager} from "../src/PartyManagement.sol";

contract DeployPartyManager is Script {
    PartyManager public  partyManager;
    function run() public {
        vm.startBroadcast();
        
        // Deploy the contract
        partyManager = new PartyManager();
        
        vm.stopBroadcast();
      
    }
}