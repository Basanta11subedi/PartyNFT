// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PartyNft} from "../src/PartyNft.sol";

contract PartyNftScript is Script {
    PartyNft public partyNft;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        partyNft = new PartyNft();

        vm.stopBroadcast();
    }
}
