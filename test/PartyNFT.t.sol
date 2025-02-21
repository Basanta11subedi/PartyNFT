// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {PartyManager} from "../src/PartyManagement.sol";

contract PartyManagerTest is Test {
    PartyManager public partyManager;
    address public owner;
    address public admin;
    address public host;
    address public user1;
    address public user2;

    event AdminAdded(address indexed admin);
    event PartyCreated(uint256 indexed partyId, address indexed admin);
    event PartyApproved(uint256 indexed partyId);
    event UserJoinedParty(uint256 indexed partyId, address indexed user);
    event NFTMinted(uint256 indexed partyId, address indexed user, uint256 nftId);
    event NFTListed(uint256 indexed partyId, uint256 indexed tokenId, uint256 price);
    event NFTSold(uint256 indexed partyId, uint256 indexed tokenId, address indexed buyer, uint256 price);

    function setUp() public {
        owner = makeAddr("owner");
        admin = makeAddr("admin");
        host = makeAddr("host");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.startPrank(owner);
        partyManager = new PartyManager();
        vm.stopPrank();
    }

    function test_AddAdmin() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, false);
        emit AdminAdded(admin);
        partyManager.addAdmin(admin);
        assertTrue(partyManager.admins(admin));
        vm.stopPrank();
    }

    function test_CreateParty() public {
        // First add admin
        vm.prank(owner);
        partyManager.addAdmin(admin);

        // Create party as admin
        vm.startPrank(admin);
        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = startTime + 4 hours;
        uint256 entryFee = 0.1 ether;
        uint256 maxParticipants = 100;

        vm.expectEmit(true, true, false, false);
        emit PartyCreated(1, admin);
        
        partyManager.createParty(
            "Test Party",
            "A test party description",
            "Test Venue",
            startTime,
            endTime,
            entryFee,
            maxParticipants,
            host
        );
        vm.stopPrank();

        // Verify party details
        (
            uint256 id,
            string memory name,
            string memory description,
            string memory venue,
            uint256 start,
            uint256 end,
            uint256 fee,
            uint256 maxPart,
            address partyAdmin,
            address partyHost,
            bool approved
        ) = partyManager.parties(1);

        assertEq(id, 1);
        assertEq(name, "Test Party");
        assertEq(description, "A test party description");
        assertEq(venue, "Test Venue");
        assertEq(start, startTime);
        assertEq(end, endTime);
        assertEq(fee, entryFee);
        assertEq(maxPart, maxParticipants);
        assertEq(partyAdmin, admin);
        assertEq(partyHost, host);
        assertFalse(approved);
    }

    function test_ApproveParty() public {
        // Setup party
        test_CreateParty();

        // Approve party
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit PartyApproved(1);
        partyManager.approveParty(1);

        // Verify approval
        (,,,,,,,,,,bool approved) = partyManager.parties(1);
        assertTrue(approved);
    }

    function test_JoinParty() public {
        // Setup and approve party
        test_ApproveParty();

        // Join party as user1
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectEmit(true, true, false, false);
        emit UserJoinedParty(1, user1);
        partyManager.joinParty{value: 0.1 ether}(1);
    }

    function test_MintNFT() public {
        // Setup party and join
        test_JoinParty();

        // Warp to party time
        (,,,,uint256 startTime,,,,,,) = partyManager.parties(1);
        vm.warp(startTime + 1 hours);

        // Mint NFT
        vm.prank(user1);
        vm.expectEmit(true, true, false, false);
        emit NFTMinted(1, user1, 1);
        partyManager.mintNFT(1, "ipfs://test-uri");

        // Verify NFT ownership
        assertEq(partyManager.ownerOf(1), user1);
    }

    function test_NFTMarketplace() public {
        // Setup party and mint NFT
        test_MintNFT();

        uint256 listingPrice = 0.5 ether;
        uint256 tokenId = 1;

        // List NFT
        vm.prank(user1);
        vm.expectEmit(true, true, false, false);
        emit NFTListed(1, tokenId, listingPrice);
        partyManager.listNFT(1, tokenId, listingPrice);

        // Buy NFT
        vm.deal(user2, 1 ether);
        vm.prank(user2);
        vm.expectEmit(true, true, true, false);
        emit NFTSold(1, tokenId, user2, listingPrice);
        partyManager.buyNFT{value: listingPrice}(1, tokenId);

        // Verify new ownership
        assertEq(partyManager.ownerOf(tokenId), user2);
    }

    function testFail_CreatePartyWithInvalidTimeRange() public {
        vm.prank(owner);
        partyManager.addAdmin(admin);

        vm.prank(admin);
        partyManager.createParty(
            "Failed Party",
            "Should fail",
            "Venue",
            block.timestamp + 2 days, // end time before start time
            block.timestamp + 1 days,
            0.1 ether,
            100,
            host
        );
    }

    function testFail_JoinPartyWithIncorrectFee() public {
        test_ApproveParty();

        vm.deal(user1, 1 ether);
        vm.prank(user1);
        partyManager.joinParty{value: 0.2 ether}(1); // incorrect fee
    }

    function testFail_UnauthorizedPartyApproval() public {
        test_CreateParty();

        vm.prank(user1);
        partyManager.approveParty(1);
    }

    function testFail_MintNFTBeforePartyStarts() public {
        test_JoinParty();

        vm.prank(user1);
        partyManager.mintNFT(1, "ipfs://test-uri");
    }

    function testFail_DoubleMintNFT() public {
        test_MintNFT();

        vm.prank(user1);
        partyManager.mintNFT(1, "ipfs://test-uri-2");
    }

    receive() external payable {}
}