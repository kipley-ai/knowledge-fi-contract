// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IKipProtocol {
    function _profitAmount(address _sft_address) external view returns (uint256);
    function _shareSlot() external view returns (uint256);
}
