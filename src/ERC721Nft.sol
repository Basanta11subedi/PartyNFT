// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract ERC721Nft is ERC721, ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;
    string public collectionName;
    string public collectionSymbol;

    constructor(string memory _tokenName, string memory _tokenSymbol, address initialOwner)
        ERC721(_tokenName, _tokenSymbol) Ownable(initialOwner)
    {
        collectionName = _tokenName;
        collectionSymbol = _tokenSymbol;
    }

    function safeMint(address to, string memory uri) external  {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    // The following functions are overrides required by Solidity.

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
