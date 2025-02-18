// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

contract PartyManagement is Ownable {
    
    struct Party {
        uint256 id;
        string description;
        string venue;
        uint256 startTime;
        uint256 endTime;
        uint256 maxAttendees;
        bool approved;
    }

    mapping(address => bool) public admins;
    mapping(uint256 => Party) public parties;
    uint256 public partyCounter;
    
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event PartyCreated(uint256 indexed partyId, address indexed createdBy);
    event PartyApproved(uint256 indexed partyId);
    event PartyDeleted(uint256 indexed partyId);

    modifier onlyAdmin() {
        require(admins[msg.sender], "Not an admin");
        _;
    }

    constructor() {
        // The deployer (superadmin) is the owner
    }

    function addAdmin(address _admin) external onlyOwner {
        require(!admins[_admin], "Already an admin");
        admins[_admin] = true;
        emit AdminAdded(_admin);
    }

    function removeAdmin(address _admin) external onlyOwner {
        require(admins[_admin], "Not an admin");
        admins[_admin] = false;
        emit AdminRemoved(_admin);
    }

    function createParty(
        string memory _description,
        string memory _venue,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxAttendees
    ) external onlyAdmin {
        require(_startTime < _endTime, "Invalid time range");
        
        partyCounter++;
        parties[partyCounter] = Party(
            partyCounter,
            _description,
            _venue,
            _startTime,
            _endTime,
            _maxAttendees,
            false // Default: not approved
        );
        
        emit PartyCreated(partyCounter, msg.sender);
    }

    function approveParty(uint256 _partyId) external onlyOwner {
        require(parties[_partyId].id != 0, "Party does not exist");
        parties[_partyId].approved = true;
        emit PartyApproved(_partyId);
    }

    function deleteParty(uint256 _partyId) external onlyOwner {
        require(parties[_partyId].id != 0, "Party does not exist");
        delete parties[_partyId];
        emit PartyDeleted(_partyId);
    }
}
