// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@solvprotocol/erc-3525/ERC3525SlotApprovable.sol";
// import "./IKnowledgeFi.sol";

contract SFT is Context, ERC3525SlotApprovable, Ownable {

    string public baseURI;

    constructor(
        address owner_,
        string memory name_,
        string memory symbol_
    ) ERC3525SlotApprovable(name_, symbol_, 18)
      Ownable(owner_) {
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

    function _baseURI() internal override view returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory newuri) public onlyOwner {
        baseURI = newuri;
    }

    // function _profitEstimate() public view returns (uint256) {
    //     IKipProtocol Kip = IKipProtocol(owner());
    //     return Kip._profitAmount(address(this));
    // }

    // function tokenIncome(uint256 token_id) public view returns (uint256) {
    //     IKnowledgeFi Kip = IKnowledgeFi(owner());
    //     uint256 shareSlot = Kip._shareSlot();
    //     if(slotOf(token_id) != shareSlot) {
    //         revert("No match share slot"); 
    //     }
    //     return Kip.tokenIncome(address(this), token_id);
    // }

    function slotAmount(uint256 sft_slot) public view returns (uint256) {
        uint256 slot_amount = 0;
        for (uint256 j = 0; j < tokenSupplyInSlot(sft_slot); j++) {
            uint256 _sft_token_id = tokenInSlotByIndex(sft_slot,j);
            uint256 _slot_value = balanceOf(_sft_token_id);
            slot_amount += _slot_value;
        }
        return slot_amount;
    }

// override
    // function transferFrom(
    //     uint256 fromTokenId_,
    //     address to_,
    //     uint256 value_
    // ) public payable virtual override(ERC3525, IERC3525) returns (uint256 newTokenId) {
    //     return super.transferFrom(fromTokenId_, to_, value_);
    // }

    // function transferFrom(
    //     uint256 fromTokenId_,
    //     uint256 toTokenId_,
    //     uint256 value_
    // ) public payable virtual override(ERC3525, IERC3525) {
    //     super.transferFrom(fromTokenId_, toTokenId_, value_);
    // }
}
