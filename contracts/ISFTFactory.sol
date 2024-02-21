// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISFTFactory {
    
    function SFTBaseURI() external view returns (string memory);
    function shareSlot() external view returns (uint256);
    function sft_minter(address) external view returns (bool);

    event SFTMinterChanged(address provider_address, bool enabled);
    event TokenCreated(address sft_address, uint256 share_slot, uint256 slot_value, uint256 token_amount, uint256 asset_id, address owner_address, string reference_id);
    event SFTBaseURIChanged(address sft_address,string new_uri);

    function createSFT(string memory _name, string memory _symbol, uint256 share_slot, uint256 slot_value, uint256 token_amount, address token_owner, string memory reference_id) external returns (address);
    function setSFTBaseURI(address sft_address, string memory new_uri) external;
    function _shareSlot() external view returns (uint256);
    function setSFTMinter(address _address, bool enabled) external;
}
