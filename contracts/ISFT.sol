// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@solvprotocol/erc-3525/extensions/IERC3525SlotApprovable.sol";
import "@solvprotocol/erc-3525/extensions/IERC3525SlotEnumerable.sol";

interface ISFT is IERC3525SlotApprovable, IERC3525SlotEnumerable {
    function mint(address mintTo_, uint256 slot_, uint256 value_) external;
    function owner() external view  returns (address);
    function slotAmount(uint256 sft_slot) external view  returns (uint256);
    function tokenIncome(uint256 token_id) external view  returns (uint256);
    function setBaseURI(string memory newuri) external;
}
