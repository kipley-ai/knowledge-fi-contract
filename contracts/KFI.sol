// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KnowledgeFiToken is ERC20, Ownable {

    bool stopMint = false;

    constructor(address initialOwner)
        ERC20("KnowledgeFi Token", "KFI")
        Ownable(initialOwner)
    {
        _mint(msg.sender, 100000000000000000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public{
        require(amount<=1000 * 10 ** decimals(), "Amount too big");
        require(balanceOf(to)<=100000 * 10 ** decimals(), "Your balance too big");
        require(!stopMint, "Can't Mint");
        _mint(to, amount);
    }

    function setMintStatus(bool status) public onlyOwner {
        stopMint = status;
    }

}