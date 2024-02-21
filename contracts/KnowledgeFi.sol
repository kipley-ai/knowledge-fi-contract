// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./ISFTFactory.sol";
import "./ISFT.sol";

contract KnowledgeFi is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    // using Arrays for uint256[];
    using EnumerableMap for EnumerableMap.UintToUintMap;
    
    address public payTokenAddress; // 0xc4ed2a23ad535d771ab49e0fe5664225b13cbb59
    address public sftFactoryAddress; // 
    address public fundAddress; // 0xdF87890D39E2a97F9fd05d2d240Ce65fF6E0E07c
    // string public SFTBaseURI;
    // uint256 public commissionRate; // 1000 / 10000
    uint256 public assetId;
    uint256 public invoiceId;

    uint256 public shareSlot; // 999999

    mapping(uint256 => address) public sft_assets; 
    mapping(address => uint256) public sft_total_income;
    mapping(address => uint256) public consumer_balance;
    mapping(address => bool) public service_provider;
    mapping(address => EnumerableMap.UintToUintMap) private sft_token_income;

    struct invoice{
        address consumer;
        address sft_address;
        uint256 amount;
        string reference_id;
    }

    event FundAddressChanged(address _address);
    // event CommissionRateChanged(uint256 new_fee);
    event ServiceProviderChanged(address provider_address, bool enabled);
    event ConsumerBalanceRecharged(address wallet_address, uint256 amount);
    event SFTFactoryAddressChanged(address token_address);
    // event TokenCreated(address sft_address, uint256 slot_value, uint256 token_amount, uint256 asset_id, address owner_address, string reference_id);
    // event SFTBaseURIChanged(address sft_address,string new_uri);
    event PayTokenChanged(address token_address);
    event InvoiceCreated(uint256 invoice_id, address consumer, address sft_address, uint256 amount, string reference_id);
    event IncomeClaimed(address sft_address, uint256 token_id, uint256 amount);

    constructor() {
        _disableInitializers();
    }
    // 
    function initialize(address initial_owner, address pay_token, address fund_address, address sft_factory_address) initializer public {
        __Ownable_init(initial_owner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        payTokenAddress = pay_token;
        fundAddress = fund_address;
        sftFactoryAddress = sft_factory_address;
        shareSlot = 999999;
        assetId = 0;
        invoiceId = 0;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    function createSFT(string memory _name, string memory _symbol, uint256 slot_value, uint256 token_amount, address token_owner, string memory reference_id) public {
        assetId++;
        ISFTFactory sft_entry = ISFTFactory(sftFactoryAddress);
        address sft_address = sft_entry.createSFT(_name, _symbol, shareSlot, slot_value, token_amount, token_owner, reference_id);
        sft_assets[assetId] = sft_address;
        // emit TokenCreated(address(sft_entry), slot_value, token_amount, assetId, token_owner, reference_id);
    }

    function createInvoiceBatch(invoice[] memory _invoice) public {
        require(service_provider[_msgSender()], "Not a provider");
        for (uint256 i = 0; i < _invoice.length; i++) {
            createInvoice(_invoice[i].consumer, _invoice[i].sft_address, _invoice[i].amount, _invoice[i].reference_id);
        }
    }

    function createInvoice(address consumer, address sft_address, uint256 amount, string memory reference_id) public {
        require(service_provider[_msgSender()], "Not a provider");
        // address _sft_address = sft_assets[sft_address];
        require(sft_address != address(0), "ReferenceID does not exist");

        if (consumer_balance[consumer] < amount) {
            revert("Not enough balance"); 
        }else{
            consumer_balance[consumer] -= amount;
        }

        _allocateTokenIncome(sft_address, amount);
        sft_total_income[sft_address] += amount;
        invoiceId++;

        emit InvoiceCreated(invoiceId, consumer, sft_address, amount, reference_id);
    }

    // allocate profit to each token as snapshot
    function _allocateTokenIncome(address _sft_address, uint256 amount) private {
        ISFT _sft = ISFT(_sft_address);
        for (uint256 i = 0; i < _sft.totalSupply(); i++) {
            uint256 shareBalance = _sft.balanceOf(_sft.tokenByIndex(i));
            uint256 slotAmount = _sft.slotAmount(shareSlot);
            uint256 incomeShare = _calculate(amount, shareBalance, slotAmount);
            EnumerableMap.UintToUintMap storage token_income = sft_token_income[_sft_address];
            (bool incomeIsExist, uint256 incomeBeforeValue) = token_income.tryGet(_sft.tokenByIndex(i));
            
            if (incomeIsExist) {
                token_income.set(_sft.tokenByIndex(i), incomeBeforeValue + incomeShare);
            }else{
                token_income.set(_sft.tokenByIndex(i), incomeShare);
            }
        }
    }  
    
    function claimIncome(address sft_address, uint256 token_id, uint256 amount) public {
        EnumerableMap.UintToUintMap storage token_income = sft_token_income[sft_address];
        (bool incomeIsExist, uint256 incomeBeforeValue) = token_income.tryGet(token_id);
        if (incomeIsExist) {
            ISFT _sft = ISFT(sft_address);
            if (_sft.ownerOf(token_id) != _msgSender()) {
                revert("Not token owner"); 
            }
            if(incomeBeforeValue >= amount)
            {
                IERC20 token = IERC20(payTokenAddress);
                token.transferFrom(fundAddress, _msgSender(), amount);    
                token_income.set(token_id, incomeBeforeValue - amount);
                emit IncomeClaimed(sft_address, token_id, amount);
            }
        } 
    }

    function _calculate(uint256 profit, uint256 shareBalance, uint256 slotAmount) private pure returns (uint256) {
        if (slotAmount == 0 || profit ==0 || shareBalance == 0) {
            return 0;
        }
        uint256 result = Math.mulDiv(profit, shareBalance, slotAmount);

        return result;
    }

    function _shareSlot() public view returns (uint256) {
        return shareSlot;
    }

    function tokenIncome(address sft_address, uint256 token_id) public view returns (uint256) {
        EnumerableMap.UintToUintMap storage token_income = sft_token_income[sft_address];    
        (bool incomeIsExist, uint256 incomeBeforeValue) = token_income.tryGet(token_id);
        if (incomeIsExist) {
            return incomeBeforeValue;
        }  
        return 0;
    }

    function recharge(uint256 amount) public {
        IERC20 token = IERC20(payTokenAddress);
        token.transferFrom(_msgSender(), fundAddress, amount);
        consumer_balance[_msgSender()] += amount;
        emit ConsumerBalanceRecharged(_msgSender(),amount);
    }

    function setSFTFactoryAddress(address _address) public onlyOwner {
        sftFactoryAddress = _address;
        emit SFTFactoryAddressChanged(_address);
    }

    function setFundAddress(address _address) public onlyOwner {
        fundAddress = _address;
        emit FundAddressChanged(_address);
    }

    // function setCommissionRate(uint256 newrate) public onlyOwner {
    //     commissionRate = newrate;
    //     emit CommissionRateChanged(newrate);
    // }

    function setPriceToken(address newtoken) public onlyOwner {
        payTokenAddress = newtoken;
        emit PayTokenChanged(newtoken);
    }

    function setServiceProvider(address _address, bool enabled) public onlyOwner {
        service_provider[_address] = enabled;
        emit ServiceProviderChanged(_address, enabled);
    }
}
