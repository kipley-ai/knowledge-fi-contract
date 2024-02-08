// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IKnowledgeFi {
    function createSFT(string calldata name_, string calldata symbol_, uint256 slot_value, uint256 token_amount, address token_owner, string calldata reference_id) external;

    function createInvoiceBatch(invoice[] calldata _invoice) external;

    function createInvoice(address consumer, address sft_address, uint256 amount, string calldata reference_id) external;

    function claimIncome(address sft_address, uint256 token_id, uint256 amount) external;

    function tokenIncome(address sft_address, uint256 token_id) external view returns (uint256);

    function recharge(uint256 amount) external;

    function setCommissionRate(uint256 newrate) external;

    function setPriceToken(address newtoken) external;

    function setServiceProvider(address _address, bool enabled) external;

    function _shareSlot() external view returns (uint256);

    event CommissionRateChanged(uint256 new_fee);
    event ServiceProviderChanged(address provider_address, bool enabled);
    event ConsumerBalanceRecharged(address wallet_address, uint256 amount);
    event TokenCreated(address sft_address, uint256 slot_value, uint256 token_amount, uint256 asset_id, address owner_address, string reference_id);
    event PayTokenChanged(address token_address);
    event InvoiceCreated(uint256 invoice_id, address consumer, address sft_address, uint256 amount, string reference_id);
    event IncomeClaimed(address sft_address, uint256 token_id, uint256 amount);

    struct invoice {
        address consumer;
        address sft_address;
        uint256 amount;
        string reference_id;
    }
}
