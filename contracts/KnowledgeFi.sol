// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/utils/Arrays.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./ISFT.sol";
// import "./ABDKMathQuad.sol";
import {SFT} from "./SFT.sol";

contract KnowledgeFi is Ownable, ReentrancyGuard {
    // using Arrays for uint256[];
    using EnumerableMap for EnumerableMap.UintToUintMap;
    
    address public payTokenAddress; // 0xc4ed2a23ad535d771ab49e0fe5664225b13cbb59
    address public fundAddress; // 0xdF87890D39E2a97F9fd05d2d240Ce65fF6E0E07c
    string public SFTBaseURI;
    // uint256 public commissionRate; // 1000 / 10000
    // uint256 public profitSnapshotId;
    uint256 public assetId;
    uint256 public invoiceId;
    // uint256 public claimInterval; // 1,296,000 = 15 days

    uint256 public shareSlot; // 999999

    SFT private sft_entry;

    mapping(uint256 => address) public sft_assets; 
    mapping(address => uint256) public sft_total_income;
    mapping(address => uint256) public consumer_balance;
    mapping(address => bool) public service_provider;
    // mapping(address => EnumerableMap.UintToUintMap) private sft_token_claimed;
    mapping(address => EnumerableMap.UintToUintMap) private sft_token_income;

    struct invoice{
        address consumer;
        address sft_address;
        uint256 amount;
        string reference_id;
    }

    // mapping(uint256 => invoice) public sft_invoices;

    // struct snapshots {
    //     uint256[] ids;
    //     uint256[] values;
    //     uint256[] timestamp;
    // }
    
    // mapping(address => mapping(uint256 => snapshots)) private sft_token_profit;
    event FundAddressChanged(address _address);
    // event CommissionRateChanged(uint256 new_fee);
    event ServiceProviderChanged(address provider_address, bool enabled);
    event ConsumerBalanceRecharged(address wallet_address, uint256 amount);
    event TokenCreated(address sft_address, uint256 slot_value, uint256 token_amount, uint256 asset_id, address owner_address, string reference_id);
    event SFTBaseURIChanged(address sft_address,string new_uri);
    event PayTokenChanged(address token_address);
    event InvoiceCreated(uint256 invoice_id, address consumer, address sft_address, uint256 amount, string reference_id);
    // event ProfitSnapshotUpdated(address _sft_address, uint256 _token_id, uint256 _profit);
    event IncomeClaimed(address sft_address, uint256 token_id, uint256 amount);

    constructor(address initialOwner, address pay_token, address fund_address, string memory sft_base_uri) Ownable(initialOwner) {
        payTokenAddress = pay_token;
        fundAddress = fund_address;
        // claimInterval = 100; // 100 for test
        shareSlot = 999999;
        // profitSnapshotId = 0;
        assetId = 0;
        invoiceId = 0;
        SFTBaseURI = sft_base_uri; // https://kip-webhook.madeinchina.eu.org/metadata/knowledge_fi/
    }

    function createSFT(string memory _name, string memory _symbol, uint256 slot_value, uint256 token_amount, address token_owner, string memory reference_id) public {
        //require(sft_entry.owner() == address(this), "Not a owner");
        //require(sft_assets[asset_id] == address(0), "Already created");
        assetId++;
        sft_entry = new SFT(address(this), _name ,_symbol );

        for (uint256 i = 1; i <= token_amount; i++) {
            sft_entry.mint(token_owner, shareSlot, slot_value);
        }
        setSFTBaseURI(address(sft_entry),string.concat(SFTBaseURI,Strings.toHexString(address(sft_entry)),'/'));
        sft_assets[assetId] = address(sft_entry);
        emit TokenCreated(address(sft_entry), slot_value, token_amount, assetId, token_owner, reference_id);
    }

    function _setSFTBaseURI(address sft_address, string memory new_uri) internal {
        ISFT _sft = ISFT(sft_address);
        _sft.setBaseURI(new_uri);
        emit SFTBaseURIChanged(sft_address, new_uri);
    }

    function setSFTBaseURI(address sft_address, string memory new_uri) public onlyOwner {
        _setSFTBaseURI(sft_address, new_uri);
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
        // sft_invoices[invoiceId] = invoice(consumer, asset_id, amount, reference_id);
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

            // (bool snapshotted, , uint256 value,) = profitSnapshotOfAt(_sft_address, _sft.tokenByIndex(i), _lastSnapshotId(sft_token_profit[_sft_address][_sft.tokenByIndex(i)].ids));
            if (incomeIsExist) {
                token_income.set(_sft.tokenByIndex(i), incomeBeforeValue + incomeShare);
                // profitShare += value;
            }else{
                token_income.set(_sft.tokenByIndex(i), incomeShare);
            }
            // _updateProfitSnapshot(_sft_address, _sft.tokenByIndex(i), profitShare);
        }
    }  
    
    function claimIncome(address sft_address, uint256 token_id, uint256 amount) public {
        // (current time - claimInterval) has the latest withdrawable snapshot
        // (bool has_lower, uint256 index) = _findLastOccurrence(sft_token_profit[_sft_address][token_id].timestamp, block.timestamp - claimInterval);
        EnumerableMap.UintToUintMap storage token_income = sft_token_income[sft_address];
        // if (has_lower) {
            (bool incomeIsExist, uint256 incomeBeforeValue) = token_income.tryGet(token_id);
            if (incomeIsExist) {
                ISFT _sft = ISFT(sft_address);
                // EnumerableMap.UintToUintMap storage token_withdraw = sft_token_withdraw[_sft_address];
                // (bool withdrawIsExist, uint256 withdrawBeforeValue) = token_withdraw.tryGet(token_id);
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
        // }   
    }

    // function _findLastOccurrence(uint256[] storage array, uint256 element) private view returns (bool, uint256) {
    //     if (array.length == 0) {
    //         return (false, 0);
    //     }

    //     uint256 low = 0;
    //     uint256 high = array.length - 1; // Adjust high to be the last index
    //     uint256 result = array.length; // Initialize result to an invalid index

    //     while (low <= high) {
    //         uint256 mid = Math.average(low, high);

    //         if (array[mid] <= element) {
    //             low = mid + 1; // Move right if the element is greater than or equal to the target
    //             if (array[mid] == element) {
    //                 result = mid; // Update result if current element is equal to the target
    //             }
    //         } else {
    //             high = mid - 1; // Move left if the element is less than the target
    //         }
    //     }

    //     // If result is not updated, it means the element is not found, return the largest index with value less than 'element'.
    //     // Otherwise, return the last occurrence of the element.
    //     if (result == array.length) {
    //         return (false, high >= 0 ? high : 0); // Adjust for the case when all elements are greater than 'element'
    //     }
    //     return (true, result);
    // }

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

    // function _lastSnapshotId(uint256[] storage ids) private view returns (uint256) {
    //     if (ids.length == 0) {
    //         return 0;
    //     } else {
    //         return ids[ids.length - 1];
    //     }
    // }

    // function _updateProfitSnapshot(address _sft_address, uint256 _token_id, uint256 _profit) private {
    //     profitSnapshotId++;
    //     if (_lastSnapshotId(sft_token_profit[_sft_address][_token_id].ids) < profitSnapshotId) {
    //         sft_token_profit[_sft_address][_token_id].ids.push(profitSnapshotId);
    //         sft_token_profit[_sft_address][_token_id].values.push(_profit);
    //         sft_token_profit[_sft_address][_token_id].timestamp.push(block.timestamp);
    //         emit ProfitSnapshotUpdated(_sft_address, _token_id, _profit);
    //     }
    // }

    // function profitSnapshotOfAt(address _sft_address, uint256 _token_id, uint256 snapshot_id) public view returns (bool, uint256, uint256, uint256) {
    //     require(_sft_address != address(0), "ReferenceID does not exist");
        
    //     snapshots storage _snapshots = sft_token_profit[_sft_address][_token_id];

    //     (bool has_lower, uint256 index) = _findLastOccurrence(_snapshots.ids, snapshot_id);

    //     if (has_lower) {
    //         return (true, index, _snapshots.values[index], _snapshots.timestamp[index]);
    //     } else {
    //         return (false, 0, 0, 0);
    //     }
    // }

    // helper function for finding the lower bound index of a value in an array
    // function _findLowerBound(uint256[] storage _array, uint256 _value) private view returns (bool, uint256) {
    //     if (_array.length == 0 || _value < _array[0]) {
    //         return (false, 0);
    //     } else if (_value >= _array[_array.length - 1]) {
    //         return (true, _array.length - 1);
    //     }

    //     uint256 index = _array.findUpperBound(_value);

    //     if (_array[index] != _value && index != 0) {
    //         index = index - 1;
    //     }

    //     return (true, index);
        
    // }

    function recharge(uint256 amount) public {
        IERC20 token = IERC20(payTokenAddress);
        token.transferFrom(_msgSender(), fundAddress, amount);
        consumer_balance[_msgSender()] += amount;
        emit ConsumerBalanceRecharged(_msgSender(),amount);
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
