// SPDX-License-Identifier: All rights reserved and belonging to REClosure Ltd. 2023
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract SaleManager {

  event SetSaleToken(IERC20 token);
  event SetPricePrimaryMarket(uint256 price);

  IERC20 saleToken;
  uint256 pricePrimaryMarket;

  constructor() {}

  function getSaleToken() internal returns (IERC20) {
    return saleToken; 
  }

  function _payPricePrimaryMarket(address seller, address buyer, uint256 tokenAmount) internal returns (uint256) {
    // Slither complains about the use of arbitrary from in
    // transferFrom. But bear in mind that this _internal_
    // function can only be called by DSIP's mintWithPayment,
    // which has onlyOwner as a modifier.

    uint256 amount = tokenAmount * pricePrimaryMarket / 1e18;
    require(
      saleToken.transferFrom(buyer, seller, amount ),
      "Error paying for tokens"
    );

    return amount;
  }

  function _setSaleToken(IERC20 _saleToken) internal {
    saleToken= _saleToken;
    emit SetSaleToken(_saleToken);
  }

  function _setPricePrimaryMarket(uint256 _pricePrimaryMarket) internal {
    // Our best to prevent overflows when later
    // multiplying price * shares and storing it
    // in a uint256
    require(_pricePrimaryMarket<type(uint128).max, "Price cannot exceed uint128");
    pricePrimaryMarket = _pricePrimaryMarket;
    emit SetPricePrimaryMarket(_pricePrimaryMarket);
  }
}
