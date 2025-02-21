// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";


contract PartyManager is ERC721URIStorage, Ownable, ReentrancyGuard {
    struct Party {
        uint256 id;
        string name;
        string description;
        string venue;
        uint256 startTime;
        uint256 endTime;
        uint256 entryFee;
        uint256 maxParticipants;
        address admin;
        address host;
        bool approved;
        address[] participants;
        mapping(address => bool) hasMintedNFT;
    }

    mapping(uint256 => Party) public parties;
    mapping(address => bool) public admins;
    mapping(uint256 => mapping(uint256 => uint256)) public salePrices; // partyId => tokenId => price
    mapping(uint256 => mapping(uint256 => address)) public nftOwners; // partyId => tokenId => owner

    uint256 public partyCount;
    uint256 public nftCounter;
    uint256 public constant SUPERADMIN_NFT_FEE = 10; // 10% fee on NFT sales

    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event PartyCreated(uint256 indexed partyId, address indexed admin);
    event PartyApproved(uint256 indexed partyId);
    event PartyDeleted(uint256 indexed partyId);
    event UserJoinedParty(uint256 indexed partyId, address indexed user);
    event NFTMinted(uint256 indexed partyId, address indexed user, uint256 nftId);
    event NFTListed(uint256 indexed partyId, uint256 indexed tokenId, uint256 price);
    event NFTUnlisted(uint256 indexed partyId, uint256 indexed tokenId);
    event NFTSold(uint256 indexed partyId, uint256 indexed tokenId, address indexed buyer, uint256 price);

    modifier onlyAdmin() {
        require(admins[msg.sender], "Not an admin");
        _;
    }

    modifier onlyDuringParty(uint256 _partyId) {
        require(block.timestamp >= parties[_partyId].startTime && block.timestamp <= parties[_partyId].endTime, "Party time over");
        _;
    }

    modifier onlyApprovedParty(uint256 _partyId) {
        require(parties[_partyId].approved, "Party not approved");
        _;
    }

    constructor() ERC721("PartyNFT", "PNFT") Ownable(msg.sender) {}

    // SuperAdmin Functions
    function addAdmin(address _admin) external onlyOwner {
        admins[_admin] = true;
        emit AdminAdded(_admin);
    }

    function removeAdmin(address _admin) external onlyOwner {
        admins[_admin] = false;
        emit AdminRemoved(_admin);
    }

    function approveParty(uint256 _partyId) external onlyOwner {
        parties[_partyId].approved = true;
        emit PartyApproved(_partyId);
    }

    function deleteParty(uint256 _partyId) external onlyOwner {
        delete parties[_partyId];
        emit PartyDeleted(_partyId);
    }

    // Admin Functions
    function createParty(
        string memory _name,
        string memory _description,
        string memory _venue,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _entryFee,
        uint256 _maxParticipants,
        address _host
    ) external onlyAdmin {
        require(_startTime < _endTime, "Invalid time range");

        partyCount++;
        Party storage party = parties[partyCount];
        party.id = partyCount;
        party.name = _name;
        party.description = _description;
        party.venue = _venue;
        party.startTime = _startTime;
        party.endTime = _endTime;
        party.entryFee = _entryFee;
        party.maxParticipants = _maxParticipants;
        party.admin = msg.sender;
        party.host = _host;
        party.approved = false;

        emit PartyCreated(partyCount, msg.sender);
    }

    // User Functions
    function joinParty(uint256 _partyId) external payable onlyApprovedParty(_partyId) {
        Party storage party = parties[_partyId];
        require(msg.value == party.entryFee, "Incorrect entry fee");
        require(party.participants.length < party.maxParticipants, "Party full");

        payable(party.admin).transfer(msg.value);
        party.participants.push(msg.sender);

        emit UserJoinedParty(_partyId, msg.sender);
    }

    function mintNFT(uint256 _partyId, string memory _tokenURI) external onlyDuringParty(_partyId) onlyApprovedParty(_partyId) {
        Party storage party = parties[_partyId];
        require(!party.hasMintedNFT[msg.sender], "NFT already minted");

        nftCounter++;
        _mint(msg.sender, nftCounter);
        _setTokenURI(nftCounter, _tokenURI);
        nftOwners[_partyId][nftCounter] = msg.sender;
        party.hasMintedNFT[msg.sender] = true;

        emit NFTMinted(_partyId, msg.sender, nftCounter);
    }

    // NFT Marketplace Functions
    function listNFT(uint256 _partyId, uint256 _tokenId, uint256 price) external {
        require(ownerOf(_tokenId) == msg.sender, "Not NFT owner");
        require(price > 0, "Price must be greater than zero");

        salePrices[_partyId][_tokenId] = price;
        emit NFTListed(_partyId, _tokenId, price);
    }

    function unlistNFT(uint256 _partyId, uint256 _tokenId) external {
        require(nftOwners[_partyId][_tokenId] == msg.sender, "Not seller");

        delete salePrices[_partyId][_tokenId];
        emit NFTUnlisted(_partyId, _tokenId);
    }

    function buyNFT(uint256 _partyId, uint256 _tokenId) external payable {
        uint256 price = salePrices[_partyId][_tokenId];
        require(price > 0, "NFT not for sale");
        require(msg.value == price, "Incorrect price");

        address seller = nftOwners[_partyId][_tokenId];
        uint256 superAdminFee = (price * SUPERADMIN_NFT_FEE) / 100;
        uint256 sellerAmount = price - superAdminFee;

        payable(owner()).transfer(superAdminFee);
        payable(seller).transfer(sellerAmount);

        _transfer(seller, msg.sender, _tokenId);
        nftOwners[_partyId][_tokenId] = msg.sender;
        delete salePrices[_partyId][_tokenId];

        emit NFTSold(_partyId, _tokenId, msg.sender, price);
    }
    function getParty(uint256 _partyId) external view returns (
    uint256 id,
    string memory name,
    string memory description,
    string memory venue,
    uint256 startTime,
    uint256 endTime,
    uint256 entryFee,
    uint256 maxParticipants,
    address admin,
    address host,
    bool approved,
    uint256 participantCount
) {
    Party storage party = parties[_partyId];

    return (
        party.id,
        party.name,
        party.description,
        party.venue,
        party.startTime,
        party.endTime,
        party.entryFee,
        party.maxParticipants,
        party.admin,
        party.host,
        party.approved,
        party.participants.length
    );
}

}