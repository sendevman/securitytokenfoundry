// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FeeToken is ERC20 {
    constructor(uint256 _amount) ERC20("FeeToken", "FT") {
        _mint(msg.sender, _amount);
    }
}


