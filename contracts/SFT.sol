// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@solvprotocol/erc-3525/ERC3525SlotApprovable.sol";

contract SFT is Context, ERC3525SlotApprovable, Ownable {
    uint256 public offchainReferenceID;
    string public baseURI;
    address public ownerAddress;
    uint256 public queryPrice;

    event QueryPriceChanged(uint256 newprice_);

    constructor(
        address kip_address,
        uint256 reference_id,
        address owner_,
        uint8 price_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC3525SlotApprovable(name_, symbol_, decimals_)
      Ownable(kip_address) {
        ownerAddress = owner_;
        queryPrice = price_;
        offchainReferenceID = reference_id;
    }

    function mint(
        address mintTo_,
        uint256 slot_,
        uint256 value_
    ) public onlyOwner {
        ERC3525._mint(mintTo_, slot_, value_);
    }

    function mintValue(
        uint256 tokenId_,
        uint256 value_
    ) public onlyOwner {
        ERC3525._mintValue(tokenId_, value_);
    }

    function setQueryPrice(uint256 _newprice) public {
        require(_msgSender() == ownerAddress, "Not an Owner");
        queryPrice = _newprice;
        emit QueryPriceChanged(_newprice);
    }

    function _baseURI() internal override view returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory newuri) public onlyOwner {
        baseURI = newuri;
    }

    function _offchainReferenceID() public view returns (uint256) {
        return offchainReferenceID;
    }

    function _ownerAddress() public view returns (address) {
        return ownerAddress;
    }

    function _queryPrice() public view returns (uint256) {
        return queryPrice;
    }
}
