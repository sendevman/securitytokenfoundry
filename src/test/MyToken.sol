// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract MyToken is ERC20{

    constructor(
        string memory name,
        string memory symbol
    )
        ERC20(name, symbol)
    {
        _mint(msg.sender, 100000e18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

}

