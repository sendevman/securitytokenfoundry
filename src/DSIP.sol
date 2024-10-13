// SPDX-License-Identifier: All rights reserved and belonging to REClosure Ltd. 2023 
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "src/interfaces/IDSIP.sol";
import "src/interfaces/IMainExchange.sol";

contract DSIP is IDSIP, Ownable, Pausable, ReentrancyGuard, ERC20Capped {

  IMainExchange mainExchange;

  address public seller;

  constructor(
    string memory name,
    string memory symbol,
    uint256 cap,
    address _issuer
  ) 	
    Ownable(_issuer)
    ERC20(name, symbol)
    ERC20Capped(cap)
  {}

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }
  
  function getCap() external view returns (uint256) {
    return cap();
  }

  // Special function: MINT
  // function mintWithoutPayment(address to, uint256 tokenAmount) external
  //   onlyOwner
  //   nonReentrant
  // {
  //   require(mainExchange.getWhiteListed(to), "Not WhiteListed");
  //   _mint(to, tokenAmount);
  //   _writeSnapshot(to, balanceOf(to));
  //   _annotateLockedFunds(to, tokenAmount);
  // }

  // function mintWithPayment(address to, uint256 tokenAmount) external
  //   onlyOwner 
  //   nonReentrant
  // {
  //   require(mainExchange.getWhiteListed(to), "Not WhiteListed");
  //   uint256 amount = _payPricePrimaryMarket(seller, to, tokenAmount);
  //   _takeFee(1, seller, to, amount);
  //   _mint(to, tokenAmount);
  //   _writeSnapshot(to, balanceOf(to));
  //   _annotateLockedFunds(to, tokenAmount);
  // }

  // Roles
  function setInitialSeller(address _seller) external onlyOwner {
    require(_seller!=address(0), "Seller cannot be the zero address");
    seller = _seller;
    emit SetInitialSeller(_seller);
  }

  function setMainExchange(IMainExchange _mainExchange) external onlyOwner {
    mainExchange = _mainExchange;
    emit SetMainExchange(_mainExchange);
  }

  // ERC20 Overrides
  function approve(address spender, uint256 value) public override(ERC20, IERC20) returns (bool) {
    require(mainExchange.getWhiteListed(spender), "Not WhiteListed");
    return super.approve(spender, value);
  }

  function transfer(address recipient, uint256 amount) public override(ERC20, IERC20) returns(bool) {
    require(mainExchange.getWhiteListed(msg.sender), "Not WhiteListed");
    require(mainExchange.getWhiteListed(recipient), "Not WhiteListed");
    require(mainExchange.getPartner(msg.sender, recipient), "Not Partner");
    return super.transfer(recipient, amount);
  }

  function transferFrom(address sender, address recipient, uint256 amount) public override(ERC20, IERC20) returns(bool) {
    require(mainExchange.getWhiteListed(sender), "Not WhiteListed");
    require(mainExchange.getWhiteListed(recipient), "Not WhiteListed");
    require(mainExchange.getPartner(sender, recipient), "Not Partner");
    return super.transferFrom(sender, recipient, amount);
  }

  function transferFromWithFee(address sender, address recipient, uint256 amount) public
    whenNotPaused
    nonReentrant
    returns (bool)
  {
    require(mainExchange.getWhiteListed(sender), "Not WhiteListed");
    require(mainExchange.getWhiteListed(recipient), "Not WhiteListed");
    mainExchange.writeSnapshot(recipient, balanceOf(recipient));
    mainExchange.writeSnapshot(sender, balanceOf(sender));
    mainExchange.annotateLockedFunds(recipient, amount);
    return true;
  }

  function forceTransfer(address from, address to, uint256 amount) public
    onlyOwner
    returns (bool)
  {
    require(mainExchange.getWhiteListed(to), "Not WhiteListed");
    _transfer(from, to, amount);
    mainExchange.writeSnapshot(from, balanceOf(from));
    mainExchange.writeSnapshot(to, balanceOf(to));
    mainExchange.annotateLockedFunds(to, amount);
    emit ForceTransfer(from, to, amount);
    return true;
  }
}
