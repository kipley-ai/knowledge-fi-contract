// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./ISFT.sol";

contract KipProtocol is Ownable, ReentrancyGuard {
    using Strings for address;
    using Strings for uint256;
    using EnumerableMap for EnumerableMap.UintToUintMap;
    
    address public priceToken; // 0xa6fb168a1264075946a2f7cb08384f5a7ab2f05b
    uint256 public commissionRate; // 1000 / 10000
    uint256 public lastConsumeID;
    uint256 public sftSlot;

    mapping(uint256 => address) public sft_assets; 
    mapping(address => uint256) public consumer_balance;
    mapping(address => bool) public service_provider;
    mapping(address => EnumerableMap.UintToUintMap) private sft_token_profit;

    struct receipt{
        uint256 reference_id;
        uint256 profit_per_share;
    }

    event CommissionRateChanged(uint256 newfee_);
    event ServiceProviderChanged(address _providerAddress, bool _enabled);
    event ConsumerBalanceRecharged(address _walletAddress, uint256 amount_);
    event TokenCreated(address sft_address, uint256 slot_value, uint256 token_amount, uint256 reference_id);
    event PriceTokenChanged(address token_address);
    event ConsumeLog(uint256 consume_id, uint256 _amount, receipt[] _receipt);

    constructor(address initialOwner, address price_token, uint256 commission_rate) Ownable(initialOwner) {
        priceToken = price_token;
        commissionRate = commission_rate;
        lastConsumeID = 1;
        sftSlot = 1;
    }

    function createToken(address sft_address, uint256 slot_value, uint256 token_amount) public {
        ISFT sft_entry = ISFT(sft_address);
        require(sft_entry.owner() == address(this), "Not a owner");
        require(sft_assets[sft_entry._offchainReferenceID()] == address(0), "Already created");

        for (uint256 i = 1; i <= token_amount; i++) {
            sft_entry.mint(sft_entry._ownerAddress(), sftSlot, slot_value);
        }
        sft_assets[sft_entry._offchainReferenceID()] = sft_address;

        emit TokenCreated(sft_address, slot_value, token_amount, sft_entry._offchainReferenceID());
    }

    function consume(address _consumer, uint256 _amount, receipt[] memory _receipt) public {
        require(service_provider[_msgSender()], "Not a provider");
        require(_amount<=consumer_balance[_consumer], "Not a enough money");

        for (uint256 i = 0; i < _receipt.length; i++) {

            address _sft_address = sft_assets[_receipt[i].reference_id];
            uint256 _profit_per_share = _receipt[i].profit_per_share;

            require(_sft_address != address(0), "ReferenceID does not exist");

            ISFT sft_entry = ISFT(_sft_address);

            EnumerableMap.UintToUintMap storage token_profit = sft_token_profit[_sft_address];

            for (uint256 j = 0; j < sft_entry.tokenSupplyInSlot(sftSlot); j++) {
                uint256 _sft_token_id = sft_entry.tokenInSlotByIndex(sftSlot,j);
                uint256 _slot_value = sft_entry.balanceOf(_sft_token_id);
                (bool tokenIsExist, uint256 beforeValue) = token_profit.tryGet(_sft_token_id);
                uint256 newValue = _slot_value * _profit_per_share;
                if (tokenIsExist) {
                    token_profit.set(_sft_token_id, beforeValue + newValue);
                } else {
                    token_profit.set(_sft_token_id, newValue);
                }
            }
            
        }

        emit ConsumeLog(lastConsumeID, _amount,  _receipt);

        lastConsumeID++;
    }

    function _lastConsumeID() public view returns (uint256) {
        return lastConsumeID;
    }

    function recharge(uint256 amount_) public {
        IERC20 token = IERC20(priceToken);
        token.transferFrom(_msgSender(), address(this), amount_);
        consumer_balance[_msgSender()] += amount_;
        emit ConsumerBalanceRecharged(_msgSender(),amount_);
    }

    function setCommissionRate(uint256 _newrate) public onlyOwner {
        commissionRate = _newrate;
        emit CommissionRateChanged(_newrate);
    }

    function setPriceToken(address newtoken) public onlyOwner {
        priceToken = newtoken;
        emit PriceTokenChanged(newtoken);
    }

    function setServiceProvider(address _address, bool _enabled) public onlyOwner {
        service_provider[_address] = _enabled;
        emit ServiceProviderChanged(_address, _enabled);
    }
}
