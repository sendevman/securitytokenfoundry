// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SaleToken is ERC20 {
    constructor(uint256 _amount) ERC20("SaleToken", "ST") {
        _mint(msg.sender, _amount);
    }

	// Anybody can print these play tokens
	 function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

}

