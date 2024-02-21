// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// import "./ISFT.sol";
import {SFT} from "./SFT.sol";

interface ISFT {
    function setBaseURI(string memory newuri) external;
}

contract SFTFactory is Ownable, ReentrancyGuard {
    
    string public SFTBaseURI;
    // uint256 public assetId;
    // uint256 public shareSlot; // 999999

    SFT private sft_entry;

    mapping(address => bool) public sft_minter;
    event SFTMinterChanged(address provider_address, bool enabled);
    event TokenCreated(address sft_address, uint256 share_slot, uint256 slot_value, uint256 token_amount, uint256 asset_id, address owner_address, string reference_id);
    event SFTBaseURIChanged(address sft_address,string new_uri);

    constructor(address initialOwner, string memory sft_base_uri) Ownable(initialOwner) {
        // shareSlot = 999999;
        // assetId = 0;
        SFTBaseURI = sft_base_uri; // https://kip-webhook.madeinchina.eu.org/metadata/knowledge_fi/
    }

    function createSFT(string memory _name, string memory _symbol, uint256 share_slot, uint256 slot_value, uint256 token_amount, address token_owner, string memory reference_id) public returns (address) {
        require(sft_minter[_msgSender()], "Not a minter");
        // assetId++;
        sft_entry = new SFT(address(this), _name ,_symbol );

        for (uint256 i = 1; i <= token_amount; i++) {
            sft_entry.mint(token_owner, share_slot, slot_value);
        }
        sft_entry.setBaseURI(string.concat(SFTBaseURI,Strings.toHexString(address(sft_entry)),'/'));
        // sft_assets[assetId] = address(sft_entry);
        emit TokenCreated(address(sft_entry), share_slot, slot_value, token_amount, 0, token_owner, reference_id);
        return address(sft_entry);
    }

    function setSFTBaseURI(address sft_address, string memory new_uri) public onlyOwner {
        ISFT _sft = ISFT(sft_address);
        _sft.setBaseURI(new_uri);
        emit SFTBaseURIChanged(sft_address, new_uri);
    }

    // function setSFTBaseURI(address sft_address, string memory new_uri) public onlyOwner {
    //     _setSFTBaseURI(sft_address, new_uri);
    // }

    // function _shareSlot() public view returns (uint256) {
    //     return shareSlot;
    // }

    function setSFTMinter(address _address, bool enabled) public onlyOwner {
        sft_minter[_address] = enabled;
        emit SFTMinterChanged(_address, enabled);
    }
}
