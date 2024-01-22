// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Arrays.sol";
import "./ISFT.sol";
// import "./ABDKMathQuad.sol";
import {SFT} from "./SFT.sol";

contract KipProtocol is Ownable, ReentrancyGuard {
    using Arrays for uint256[];
    using EnumerableMap for EnumerableMap.UintToUintMap;
    
    address public payTokenAddress; // 0xa6fb168a1264075946a2f7cb08384f5a7ab2f05b
    uint256 public commissionRate; // 1000 / 10000
    uint256 public profitSnapshotId;
    uint256 public claimInterval; // 1,296,000 = 15 days

    uint256 public shareSlot; // 999999

    SFT private sft_entry;

    mapping(uint256 => address) public sft_assets; 
    mapping(address => uint256) public consumer_balance;
    mapping(address => bool) public service_provider;
    mapping(address => EnumerableMap.UintToUintMap) private sft_token_withdraw;

    struct invoice{
        address _consumer;
        uint256 _amount;
        uint256 asset_id;
        uint256 invoice_id;
        uint256 order_id;
        uint256 order_timestamp;
    }

    struct snapshots {
        uint256[] ids;
        uint256[] values;
        uint256[] timestamp;
    }
    
    // mapping(address => snapshots) private sft_total_profit;
    mapping(address => mapping(uint256 => snapshots)) private sft_token_profit;

    event CommissionRateChanged(uint256 newfee_);
    event ServiceProviderChanged(address _providerAddress, bool _enabled);
    event ConsumerBalanceRecharged(address _walletAddress, uint256 amount_);
    event TokenCreated(address sft_address, uint256 slot_value, uint256 token_amount, uint256 asset_id, address owner_address);
    event PayTokenChanged(address token_address);
    event InvoiceCreated(invoice[] _invoice);

    constructor(address initialOwner, address pay_token, uint256 commission_rate) Ownable(initialOwner) {
        payTokenAddress = pay_token;
        commissionRate = commission_rate;
        claimInterval = 100; // 100 for test
        shareSlot = 999999;
        profitSnapshotId = 1;
    }

    function createSFT(string memory name_, string memory symbol_, uint256 slot_value, uint256 token_amount, uint256 asset_id, address token_owner) public {
        //require(sft_entry.owner() == address(this), "Not a owner");
        require(sft_assets[asset_id] == address(0), "Already created");
        sft_entry = new SFT(address(this), name_ ,symbol_ );

        for (uint256 i = 1; i <= token_amount; i++) {
            sft_entry.mint(token_owner, shareSlot, slot_value);
        }
        sft_assets[asset_id] = address(sft_entry);

        emit TokenCreated(address(sft_entry), slot_value, token_amount, asset_id, token_owner);
    }

    function createInvoice(invoice[] memory _invoice) public {
        require(service_provider[_msgSender()], "Not a provider");
        for (uint256 i = 0; i < _invoice.length; i++) {
            address _sft_address = sft_assets[_invoice[i].asset_id];
            require(_sft_address != address(0), "ReferenceID does not exist");

            _allocateTokenProfit(_sft_address, _invoice[i]._amount);

            if (consumer_balance[_invoice[i]._consumer] < _invoice[i]._amount) {
                revert("Not enough balance"); 
            }else{
                consumer_balance[_invoice[i]._consumer] -= _invoice[i]._amount;
            }
        }
        emit InvoiceCreated(_invoice);
    }

    // allocate profit to each token as snapshot
    function _allocateTokenProfit(address _sft_address, uint256 profit) private {
        ISFT _sft = ISFT(_sft_address);
        for (uint256 i = 1; i <= _sft.totalSupply(); i++) {
            uint256 shareBalance = _sft.balanceOf(_sft.tokenByIndex(i));
            uint256 slotAmount = _sft._slotAmount(shareSlot);
            uint256 profitShare = calculateProfit(profit, shareBalance, slotAmount);
            (bool snapshotted, , uint256 value,) = profitSnapshotOfAt(_sft_address, _sft.tokenByIndex(i), _lastSnapshotId(sft_token_profit[_sft_address][_sft.tokenByIndex(i)].ids));
            if (snapshotted) {
                profitShare += value;
            }
            _updateProfitSnapshot(_sft_address, _sft.tokenByIndex(i), profitShare);
        }
    }  
    
    function claimProfit(address _sft_address, uint256 token_id, uint256 profit) public {

        // (current time - claimInterval) has the latest withdrawable snapshot
        (bool has_lower, uint256 index) = _findLastOccurrence(sft_token_profit[_sft_address][token_id].timestamp, block.timestamp - claimInterval);

        if (has_lower) {
            uint256 value = sft_token_profit[_sft_address][token_id].values[index];
            if (value>0) {
            
                ISFT _sft = ISFT(_sft_address);
                EnumerableMap.UintToUintMap storage token_withdraw = sft_token_withdraw[_sft_address];
                (bool withdrawIsExist, uint256 withdrawBeforeValue) = token_withdraw.tryGet(token_id);
                if (_sft.ownerOf(token_id) != _msgSender()) {
                    revert("Not token owner"); 
                }

                if(!withdrawIsExist || (withdrawIsExist && (value-withdrawBeforeValue) >= profit))
                {
                    IERC20 token = IERC20(payTokenAddress);
                    token.transferFrom(address(this), _msgSender(), profit);    
                    token_withdraw.set(token_id, withdrawBeforeValue + profit);
                }
            }
        }   
    }

    function _findLastOccurrence(uint256[] storage array, uint256 element) private view returns (bool, uint256) {
        if (array.length == 0) {
            return (false, 0);
        }

        uint256 low = 0;
        uint256 high = array.length - 1; // Adjust high to be the last index
        uint256 result = array.length; // Initialize result to an invalid index

        while (low <= high) {
            uint256 mid = Math.average(low, high);

            if (array[mid] <= element) {
                low = mid + 1; // Move right if the element is greater than or equal to the target
                if (array[mid] == element) {
                    result = mid; // Update result if current element is equal to the target
                }
            } else {
                high = mid - 1; // Move left if the element is less than the target
            }
        }

        // If result is not updated, it means the element is not found, return the largest index with value less than 'element'.
        // Otherwise, return the last occurrence of the element.
        if (result == array.length) {
            return (false, high >= 0 ? high : 0); // Adjust for the case when all elements are greater than 'element'
        }
        return (false, result);
    }

    function calculateProfit(uint256 profit, uint256 shareBalance, uint256 slotAmount) private pure returns (uint256) {
        if (slotAmount == 0 || profit ==0 || shareBalance == 0) {
            return 0;
        }
        uint256 result = Math.mulDiv(profit, shareBalance, slotAmount);

        return result;
    }

    function _shareSlot() public view returns (uint256) {
        return shareSlot;
    }

    function _profitAmount(address _sft_address, uint256 _token_id) public view returns (uint256) {

        (bool has_lower, uint256 index) = _findLastOccurrence(sft_token_profit[_sft_address][_token_id].timestamp, block.timestamp - claimInterval);

        if (has_lower) {
            uint256 value = sft_token_profit[_sft_address][_token_id].values[index];
            if (value>0) {
                return value;
            }
        }   
        return 0;
    }

    function _lastSnapshotId(uint256[] storage ids) private view returns (uint256) {
        if (ids.length == 0) {
            return 0;
        } else {
            return ids[ids.length - 1];
        }
    }

    function _updateProfitSnapshot(address _sft_address, uint256 _token_id, uint256 _profit) private {
        if (_lastSnapshotId(sft_token_profit[_sft_address][_token_id].ids) < profitSnapshotId) {
            sft_token_profit[_sft_address][_token_id].ids.push(profitSnapshotId);
            sft_token_profit[_sft_address][_token_id].values.push(_profit);
            sft_token_profit[_sft_address][_token_id].timestamp.push(block.timestamp);
        }
        profitSnapshotId++;
    }

    function profitSnapshotOfAt(address _sft_address, uint256 _token_id, uint256 snapshot_id) public view returns (bool, uint256, uint256, uint256) {
        require(_sft_address != address(0), "ReferenceID does not exist");
        
        snapshots storage _snapshots = sft_token_profit[_sft_address][_token_id];

        (bool has_lower, uint256 index) = _findLastOccurrence(_snapshots.ids, snapshot_id);

        if (has_lower) {
            return (true, index, _snapshots.values[index], _snapshots.timestamp[index]);
        } else {
            return (false, 0, 0, 0);
        }
    }

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

    function recharge(uint256 amount_) public {
        IERC20 token = IERC20(payTokenAddress);
        token.transferFrom(_msgSender(), address(this), amount_);
        consumer_balance[_msgSender()] += amount_;
        emit ConsumerBalanceRecharged(_msgSender(),amount_);
    }

    function setCommissionRate(uint256 _newrate) public onlyOwner {
        commissionRate = _newrate;
        emit CommissionRateChanged(_newrate);
    }

    function setPriceToken(address newtoken) public onlyOwner {
        payTokenAddress = newtoken;
        emit PayTokenChanged(newtoken);
    }

    function setServiceProvider(address _address, bool _enabled) public onlyOwner {
        service_provider[_address] = _enabled;
        emit ServiceProviderChanged(_address, _enabled);
    }
}
