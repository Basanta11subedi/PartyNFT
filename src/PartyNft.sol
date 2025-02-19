// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC721Nft} from "./ERC721Nft.sol";


interface IExternalContract {
     function safeMint(address to, string memory uri) external;
     function setApprovalForAll(address operator, bool approved) external;
}

contract PartyNft {
    uint256 public partyNum = 0;
    address public owner;
    address public user;


    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "Not owner");
        _;
    }

    modifier onlyAdmin(address _admin) {
        require(admins[_admin] == true, "Not admin");
        _;
    }

    struct Party {
        string name;
        string desc;
        string sym;
        address host;
        bool approve;
        address collection;
        mapping(address => bool) users;
    }

    mapping(uint256 => Party) public parties;
    mapping(address => bool) public admins;

    function createParty(string memory _name, string memory _desc, address _host) public onlyAdmin(msg.sender) {
        partyNum ++;
        Party storage newParty = parties[partyNum];
        newParty.name = _name;
        newParty.desc = _desc;
        newParty.host = _host;
        newParty.approve = false;
    }


    function joinParty( uint256 _partyId) public {
        require(parties[_partyId].users[msg.sender] == false, "Already joined");
        Party storage userJoinParty = parties[_partyId];
        userJoinParty.users[msg.sender] = true;
    }

    function addAdmin(address _admin) public onlyOwner(){
        require(admins[_admin] == false, "Already admin");
        admins[_admin] = true;
    }

    function removeAdmin(address _admin) public onlyOwner() {
        require(admins[_admin] == true, "Not admin");
        admins[_admin] = false;
    }

    function approveParty(uint256 _partyId) public onlyOwner() {
        require(partyNum > 0 && _partyId > 0, "No party to approve");
        Party storage approvedParty = parties[_partyId];
        approvedParty.approve = true;
        createNFTCollection(parties[_partyId].name, parties[_partyId].sym, _partyId);
    }

    function deleteParty(uint256 _partyId) public onlyOwner() {
        require(partyNum > 0 && _partyId > 0, "No party to delete");
        delete parties[_partyId];
    }

    function createNFTCollection(string memory name, string memory symbol, uint256 _partyId) internal {
        ERC721Nft newCollection = new ERC721Nft(name, symbol, address(this));  // Deploy new ERC721NFT contract
        parties[_partyId].collection = address(newCollection);  // Store the address of the new NFT collection
    }

    function userMintNft(uint256 _partyId, string memory _uri) public {
        require(parties[_partyId].approve == true, "Party not approved");
        require(parties[_partyId].users[msg.sender] == true, "Not a member of party");
        IExternalContract externalContract = IExternalContract(parties[_partyId].collection);
        externalContract.safeMint(msg.sender, _uri);
    }

    

    function userListNft()

    
}
