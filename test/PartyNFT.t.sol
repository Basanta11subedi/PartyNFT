// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/PartyManagement.sol";

contract PartyManagerTest is Test {
    PartyManager public partyManager;
    address public owner;
    address public admin;
    address public host;
    address public user1;
    address public user2;
    
    // Events for testing
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event PartyCreated(uint256 indexed partyId, address indexed admin);
    event PartyApproved(uint256 indexed partyId);
    event PartyDeleted(uint256 indexed partyId);
    event UserJoinedParty(uint256 indexed partyId, address indexed user);
    event NFTMinted(uint256 indexed partyId, address indexed user, uint256 nftId);
    event NFTListed(uint256 indexed partyId, uint256 indexed tokenId, uint256 price);
    event NFTSold(uint256 indexed partyId, uint256 indexed tokenId, address indexed buyer, uint256 price);
    event NFTUnlisted(uint256 indexed partyId, uint256 indexed tokenId);

    function setUp() public {
        owner = address(this);
        admin = makeAddr("admin");
        host = makeAddr("host");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        partyManager = new PartyManager();
        
        // Fund test addresses
        vm.deal(admin, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(address(this), 100 ether);
    }

    // Admin Management Tests
    function testAddAdmin() public {
        vm.expectEmit(true, false, false, false);
        emit AdminAdded(admin);
        
        partyManager.addAdmin(admin);
        assertTrue(partyManager.admins(admin));
        
        address[] memory admins = partyManager.getAllAdmins();
        assertEq(admins.length, 1);
        assertEq(admins[0], admin);
    }

    function testRemoveAdmin() public {
        partyManager.addAdmin(admin);
        
        vm.expectEmit(true, false, false, false);
        emit AdminRemoved(admin);
        
        partyManager.removeAdmin(admin);
        assertFalse(partyManager.admins(admin));
        
        address[] memory admins = partyManager.getAllAdmins();
        assertEq(admins.length, 0);
    }

    function testFailAddAdminNotOwner() public {
        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        partyManager.addAdmin(admin);
    }

    // Party Creation and Management Tests
    function testCreateParty() public {
        partyManager.addAdmin(admin);
        
        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = startTime + 1 days;
        uint256 entryFee = 0.1 ether;
        uint256 maxParticipants = 100;
        
        vm.prank(admin);
        vm.expectEmit(true, true, false, false);
        emit PartyCreated(1, admin);
        
        partyManager.createParty(
            "Test Party",
            "Test Description",
            "Test Venue",
            startTime,
            endTime,
            entryFee,
            maxParticipants,
            host
        );
        
        (
            uint256 id,
            string memory name,
            string memory description,
            string memory venue,
            uint256 pStartTime,
            uint256 pEndTime,
            uint256 pEntryFee,
            uint256 pMaxParticipants,
            address pAdmin,
            address pHost,
            bool approved,
            uint256 participantCount
        ) = partyManager.getParty(1);
        
        assertEq(id, 1);
        assertEq(name, "Test Party");
        assertEq(description, "Test Description");
        assertEq(venue, "Test Venue");
        assertEq(pStartTime, startTime);
        assertEq(pEndTime, endTime);
        assertEq(pEntryFee, entryFee);
        assertEq(pMaxParticipants, maxParticipants);
        assertEq(pAdmin, admin);
        assertEq(pHost, host);
        assertFalse(approved);
        assertEq(participantCount, 0);
    }

    function testApproveParty() public {
        // Create party first
        partyManager.addAdmin(admin);
        
        vm.prank(admin);
        partyManager.createParty(
            "Test Party",
            "Test Description",
            "Test Venue",
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.1 ether,
            100,
            host
        );
        
        vm.expectEmit(true, false, false, false);
        emit PartyApproved(1);
        
        partyManager.approveParty(1);
        
        (,,,,,,,,,,bool approved,) = partyManager.getParty(1);
        assertTrue(approved);
    }

    function testJoinParty() public {
        // Setup party
        partyManager.addAdmin(admin);
        
        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = startTime + 1 days;
        uint256 entryFee = 0.1 ether;
        
        vm.prank(admin);
        partyManager.createParty(
            "Test Party",
            "Test Description",
            "Test Venue",
            startTime,
            endTime,
            entryFee,
            100,
            host
        );
        
        partyManager.approveParty(1);
        
        // Store admin's initial balance
        uint256 adminInitialBalance = admin.balance;
        
        vm.prank(user1);
        vm.expectEmit(true, true, false, false);
        emit UserJoinedParty(1, user1);
        partyManager.joinParty{value: entryFee}(1);
        
        // Verify admin received the entry fee
        assertEq(admin.balance, adminInitialBalance + entryFee);
        
        (,,,,,,,,,,,uint256 participantCount) = partyManager.getParty(1);
        assertEq(participantCount, 1);
    }

    function testMintNFT() public {
        // Setup party and join
        partyManager.addAdmin(admin);
        
        uint256 startTime = block.timestamp + 1 hours;
        uint256 endTime = startTime + 1 days;
        uint256 entryFee = 0.1 ether;
        
        vm.prank(admin);
        partyManager.createParty(
            "Test Party",
            "Test Description",
            "Test Venue",
            startTime,
            endTime,
            entryFee,
            100,
            host
        );
        
        partyManager.approveParty(1);
        
        vm.prank(user1);
        partyManager.joinParty{value: entryFee}(1);
        
        // Warp to party time
        vm.warp(startTime + 1);
        
        string memory tokenURI = "ipfs://test-uri";
        
        vm.prank(user1);
        vm.expectEmit(true, true, false, false);
        emit NFTMinted(1, user1, 1);
        
        partyManager.mintNFT(1, tokenURI);
        
        assertEq(partyManager.ownerOf(1), user1);
        assertEq(partyManager.tokenURI(1), tokenURI);
    }

    function testListAndBuyNFT() public {
        // Setup party, join, and mint NFT
        partyManager.addAdmin(admin);
        
        uint256 startTime = block.timestamp + 1 hours;
        uint256 endTime = startTime + 1 days;
        uint256 entryFee = 0.1 ether;
        
        vm.prank(admin);
        partyManager.createParty(
            "Test Party",
            "Test Description",
            "Test Venue",
            startTime,
            endTime,
            entryFee,
            100,
            host
        );
        
        partyManager.approveParty(1);
        
        vm.prank(user1);
        partyManager.joinParty{value: entryFee}(1);
        
        // Warp to party time
        vm.warp(startTime + 1);
        
        vm.prank(user1);
        partyManager.mintNFT(1, "ipfs://test-uri");
        
        // List NFT
        uint256 salePrice = 1 ether;
        vm.prank(user1);
        vm.expectEmit(true, true, false, false);
        emit NFTListed(1, 1, salePrice);
        
        partyManager.listNFT(1, 1, salePrice);
        
        // Store initial balances
        uint256 sellerInitialBalance = user1.balance;
        uint256 ownerInitialBalance = address(this).balance;
        
        // Buy NFT
        vm.prank(user2);
        vm.expectEmit(true, true, true, false);
        emit NFTSold(1, 1, user2, salePrice);
        
        partyManager.buyNFT{value: salePrice}(1, 1);
        
        // Check balances after sale
        uint256 superAdminFee = (salePrice * partyManager.SUPERADMIN_NFT_FEE()) / 100;
        uint256 sellerAmount = salePrice - superAdminFee;
        
        assertEq(user1.balance, sellerInitialBalance + sellerAmount);
        assertEq(address(this).balance, ownerInitialBalance + superAdminFee);
        assertEq(partyManager.ownerOf(1), user2);
    }

    function testUnlistNFT() public {
        // Setup party, join, mint and list NFT
        partyManager.addAdmin(admin);
        
        uint256 startTime = block.timestamp + 1 hours;
        uint256 endTime = startTime + 1 days;
        uint256 entryFee = 0.1 ether;
        
        vm.prank(admin);
        partyManager.createParty(
            "Test Party",
            "Test Description",
            "Test Venue",
            startTime,
            endTime,
            entryFee,
            100,
            host
        );
        
        partyManager.approveParty(1);
        
        vm.prank(user1);
        partyManager.joinParty{value: entryFee}(1);
        
        // Warp to party time
        vm.warp(startTime + 1);
        
        vm.prank(user1);
        partyManager.mintNFT(1, "ipfs://test-uri");
        
        vm.prank(user1);
        partyManager.listNFT(1, 1, 1 ether);
        
        vm.prank(user1);
        vm.expectEmit(true, true, false, false);
        emit NFTUnlisted(1, 1);
        
        partyManager.unlistNFT(1, 1);
    }


    // Failure Tests
    function testFailCreatePartyInvalidTimeRange() public {
        partyManager.addAdmin(admin);
        
        vm.prank(admin);
        partyManager.createParty(
            "Test Party",
            "Test Description",
            "Test Venue",
            block.timestamp + 2 days, // end time before start time
            block.timestamp + 1 days,
            0.1 ether,
            100,
            host
        );
    }

    function testFailJoinPartyIncorrectFee() public {
        partyManager.addAdmin(admin);
        
        vm.prank(admin);
        partyManager.createParty(
            "Test Party",
            "Test Description",
            "Test Venue",
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.1 ether,
            100,
            host
        );
        
        partyManager.approveParty(1);
        
        vm.prank(user1);
        partyManager.joinParty{value: 0.05 ether}(1); // Incorrect fee
    }

    function testFailMintNFTBeforeParty() public {
        partyManager.addAdmin(admin);
        
        vm.prank(admin);
        partyManager.createParty(
            "Test Party",
            "Test Description",
            "Test Venue",
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            0.1 ether,
            100,
            host
        );
        
        partyManager.approveParty(1);
        
        vm.prank(user1);
        partyManager.joinParty{value: 0.1 ether}(1);
        
        vm.prank(user1);
        partyManager.mintNFT(1, "ipfs://test-uri"); // Should fail as party hasn't started
    }

    function testFailBuyNFTIncorrectPrice() public {
        // Setup party, join, and mint NFT
        partyManager.addAdmin(admin);
        
        vm.prank(admin);
        partyManager.createParty(
            "Test Party",
            "Test Description",
            "Test Venue",
            block.timestamp,
            block.timestamp + 1 days,
            0.1 ether,
            100,
            host
        );
        
        partyManager.approveParty(1);
        
        vm.prank(user1);
        partyManager.joinParty{value: 0.1 ether}(1);
        
        vm.prank(user1);
        partyManager.mintNFT(1, "ipfs://test-uri");
        
        vm.prank(user1);
        partyManager.listNFT(1, 1, 1 ether);
        
        vm.prank(user2);
        partyManager.buyNFT{value: 0.5 ether}(1, 1); // Incorrect price
    }

    receive() external payable {}
}