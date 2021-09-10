// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// mock class using ERC20
contract USDT is ERC20 ("heco usdt", "OKFLY"){
    constructor ( ) public  {
        _mint(msg.sender, 10000000000000 * 1e9);
    }

    function mint( uint256 amount) public {
        _mint(msg.sender, amount * 10**18);
    }

    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }

    function transferInternal(address from, address to, uint256 value) public {
        _transfer(from, to, value);
    }

    function approveInternal(address owner, address spender, uint256 value) public {
        _approve(owner, spender, value);
    }
}


