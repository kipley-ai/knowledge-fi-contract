// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IKipProtocol {
    struct invoice{
        address _consumer;
        uint256 _amount;
        uint256 asset_id;
        uint256 invoice_id;
        uint256 order_id;
        uint256 order_timestamp;
    }

    function createSFT(
        string memory name_,
        string memory symbol_,
        uint256 slot_value,
        uint256 token_amount,
        uint256 asset_id,
        address token_owner
    ) external;

    function createInvoice(invoice[] memory _invoice) external;

    function _shareSlot() external view returns (uint256);
    
    function claimProfit(
        address _sft_address,
        uint256 token_id,
        uint256 profit
    ) external;

    function _profitAmount(
        address _sft_address,
        uint256 _token_id
    ) external view returns (uint256);

    function profitSnapshotOfAt(
        address _sft_address,
        uint256 _token_id,
        uint256 snapshot_id
    ) external view returns (bool, uint256, uint256, uint256);

    function recharge(
        uint256 amount_
    ) external;

}
