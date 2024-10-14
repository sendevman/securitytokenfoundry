// SPDX-License-Identifier: All rights reserved and belonging to REClosure Ltd. 2023
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "src/extensions/DividendManager.sol";
import "src/extensions/FeeManager.sol";
import "src/extensions/LockManager.sol";

import "src/interfaces/IDSIP.sol";
import "src/interfaces/IMainExchange.sol";
import "src/interfaces/IOrderBook.sol";
import "src/interfaces/IWhiteListManager.sol";

contract MainExchange is IMainExchange, Ownable, Pausable, ReentrancyGuard, FeeManager, DividendManager, LockManager {
  IDSIP public dsipToken;
  IERC20 public proptoToken;

  IWhiteListManager whiteListManager;
  IWhiteListManager partnerManager;
  IOrderBook orderBook;

  uint256 public totalSupplyDSIP;
  uint256 public totalSupplyPROPTO;

  uint256 public DSIPPrice;

  mapping(address => uint256) public balanceDSIP;
  mapping(address => uint256) public balancePROPTO;

  address public dividendPayer;

  constructor(address _issuer, uint256 cap)
    Ownable(_issuer)
    DividendManager(cap)
    FeeManager()
  {}

  modifier onlyWhitelisted(address account) {
    if (account != address(this) && !whiteListManager.isWhitelisted(account)) {
      revert DSIPNotWhitelisted(account);
    }
    _;
  }

  modifier onlyTransferFreeApproved(address sender, address recipient) {
    if (!partnerManager.isWhitelisted(sender) && !partnerManager.isWhitelisted(recipient)) {
      revert DSIPDirectTransfersNotAllowed();
    }
    _;
  }

  modifier onlyDividendPayer() {
    require(msg.sender == dividendPayer, "Not dividendPayer");
    _;
  }

  modifier onlyKYC(address account) {
    if (account != address(this) && !whiteListManager.isKYCListed(account)) {
      revert DSIPNotKYCListed(account);
    }
    _;
  }

  // Set Contract
  function setDSIPToken(IDSIP _dsipToken) external onlyOwner {
    dsipToken = _dsipToken;
    emit SetDSIPToken(_dsipToken);
  }

  function setProptoToken(IERC20 _proptoToken) external onlyOwner {
    proptoToken = _proptoToken;
    _setFeeToken(_proptoToken);
    emit SetProptoToken(_proptoToken);
  }

  function EmergencyFund(IERC20 _proptoToken) external onlyOwner {

  }

  function setWhiteListManager(IWhiteListManager _whiteListManager) external onlyOwner {
    whiteListManager = _whiteListManager;
    emit SetWhiteListManager(_whiteListManager);
  }

  function setPartnerManager(IWhiteListManager _partnerManager) external onlyOwner {
    partnerManager = _partnerManager;
    emit SetPartnerManager(_partnerManager);
  }

  function setOrderBook(IOrderBook _orderBook) external onlyOwner {
    orderBook = _orderBook;
    emit SetOrderBook(_orderBook);
  }

  function setDividendPayer(address _dividendPayer) external onlyOwner {
    require(_dividendPayer != address(0), "Dividend Payer cannot be the zero address");
    dividendPayer = _dividendPayer;
    emit SetDividendPayer(_dividendPayer);
  }

  function setDSIPPrice(uint256 _DSIPPrice) external onlyOwner {
    DSIPPrice = _DSIPPrice;
  }

  // check
  function getWhiteListed(address account) external view onlyOwner onlyWhitelisted(account) returns (bool) {
    return true;
  }

  function getPartner(address sender, address recipient) external view
    onlyOwner
    onlyTransferFreeApproved(sender, recipient)
    returns (bool)
  {
    return true;
  }

  // Get Contract
  function getOrderBook() external view returns (IOrderBook) {
    return orderBook; 
  }

  function addLiquidity(uint256 amountDSIP, uint256 amountPROPTO) external onlyKYC(msg.sender) {
    require(amountDSIP > 0 && amountPROPTO > 0, "Amounts must be greater than zero");

    dsipToken.transferFrom(msg.sender, address(this), amountDSIP);
    proptoToken.transferFrom(msg.sender, address(this), amountPROPTO);

    totalSupplyDSIP += amountDSIP;
    totalSupplyPROPTO += amountPROPTO;

    balanceDSIP[msg.sender] += amountDSIP;
    balancePROPTO[msg.sender] += amountPROPTO;

    emit LiquidityAdded(msg.sender, amountDSIP, amountPROPTO);
  }

  function removeLiquidity(uint256 amountDSIP, uint256 amountPROPTO) external onlyKYC(msg.sender) {
    require(balanceDSIP[msg.sender] >= amountDSIP, "Insufficient token A balance");
    require(balancePROPTO[msg.sender] >= amountPROPTO, "Insufficient token B balance");

    balanceDSIP[msg.sender] -= amountDSIP;
    balancePROPTO[msg.sender] -= amountPROPTO;

    totalSupplyDSIP -= amountDSIP;
    totalSupplyPROPTO -= amountPROPTO;

    dsipToken.transfer(msg.sender, amountDSIP);
    proptoToken.transfer(msg.sender, amountPROPTO);

    emit LiquidityRemoved(msg.sender, amountDSIP, amountPROPTO);
  }

  function swap(uint256 amountIn, bool isDSIPToPROPTO) public onlyKYC(msg.sender) {
    require(amountIn > 0, "Amount must be greater than zero");

    if (isDSIPToPROPTO) {
      uint256 amountOut = calculateSwap(amountIn, isDSIPToPROPTO);
      require(amountOut > 0, "Insufficient output amount");
      require(totalSupplyPROPTO >= amountOut, "Insufficient PROPTO Token balance");

      totalSupplyDSIP += amountIn;
      totalSupplyPROPTO -= amountOut;

      dsipToken.transferFrom(msg.sender, address(this), amountIn);
      proptoToken.transfer(msg.sender, amountOut);

      emit Swap(msg.sender, amountIn, amountOut, dsipToken, proptoToken, true);
    } else {
      uint256 amountOut = calculateSwap(amountIn, isDSIPToPROPTO);
      require(amountOut > 0, "Insufficient output amount");
      require(totalSupplyDSIP >= amountOut, "Insufficient DSIP Token balance");
      
      totalSupplyPROPTO += amountIn;
      totalSupplyDSIP -= amountOut;

      proptoToken.transferFrom(msg.sender, address(this), amountIn);
      dsipToken.transfer(msg.sender, amountOut);

      emit Swap(msg.sender, amountIn, amountOut, dsipToken, proptoToken, false);
    }
  }

  function calculateSwap(uint256 amountIn, bool isDSIPToPROPTO) internal pure returns (uint256) {
    if (isDSIPToPROPTO) {
      return (amountIn * totalSupplyPROPTO) / (totalSupplyDSIP + amountIn);
    } else {
      return (amountIn * totalSupplyDSIP) / (totalSupplyPROPTO + amountIn);
    }
  }

  // Dividends
  function setNextPayment(
    uint256 onBlock,
    uint256 numTokens,
    IERC20 token
  ) external onlyDividendPayer {
    uint256 remainingAmount = _takeDividendFee(dividendPayer, numTokens, token);
    _setNextPayment(onBlock, remainingAmount, token, dividendPayer);
  }

  function redeemDividends(address recipient, uint256 lastIndex) external
    onlyWhitelisted(recipient)
    nonReentrant
  {
    uint256 amount = _redeemDividends(recipient, lastIndex);
  }

  // These functions are for the niche case where you run out of gas while
  // redeeming dividends.
  function getLastPaymentToAddressIndex(address _address) external view returns (uint256) {
    return lastPaymentToAddressIndex[_address];
  }

  function getLastPaymentTermIndex() external view returns (uint256) {
    return lastPaymentTermIndex;
  }
  
  // // Fees
  // function setFeeToken(IERC20 token) external onlyOwner {
  //   _setFeeToken(token);
  // }

  function setFeeStructure(
    uint16 buyerPrimaryMarketFee,
    uint16 sellerPrimaryMarketFee,
    uint16 referralPrimaryMarketFee,
    uint16 emergencyPrimaryMarketFee,
    uint16 buyerSecondaryMarketFee,
    uint16 sellerSecondaryMarketFee,
    uint16 referralSecondaryMarketFee,
    uint16 emergencySecondaryMarketFee,
    uint16 dividendFeeReceiver,
    uint16 dividendFeeSender
  ) external onlyOwner {
    _setFeeStructure(
      buyerPrimaryMarketFee,
      sellerPrimaryMarketFee,
      referralPrimaryMarketFee,
      emergencyPrimaryMarketFee,
      buyerSecondaryMarketFee,
      sellerSecondaryMarketFee,
      referralSecondaryMarketFee,
      emergencySecondaryMarketFee,
      dividendFeeReceiver,
      dividendFeeSender
    );	
  }

  // function setFeeReceiverShares(uint8 marketType, address receiver, uint256 shares) external
  //   onlyOwner
  //   onlyWhitelisted(receiver)
  // {
  //   _setFeeReceiverShares(marketType, receiver, shares);
  // }

  function setUserReferralPair(address user, address referral) external {
    _setUserReferralPair(user, referral);
  }

  function redeemFee(uint8 marketType, IERC20 token, address recipient) external
    onlyWhitelisted(recipient)
    nonReentrant
  {
    _redeemFee(marketType, token, recipient);
  }

    // Trading functions
  function placeOrder(bool isBuyOrder, uint256 amountDSIPToken, uint256 amountPROPTOToken, uint256 expiryTimestamp) public
    onlyKYC(msg.sender)
    whenNotPaused
    returns (uint256)
  {
    // Let's check that _at least now_ there's enough approved to
    // cover for that. Granted, the user can always withdraw their
    // approval, but that'd be only a minor annoyance.

    // TODO: Require a fee for placing orders to avoid spam?
    if (isBuyOrder) {
      (uint256 _buyerFee, uint256 _sellerFee) = _getFeeAmount(2, amountPROPTOToken);
      require(proptoToken.allowance(msg.sender, address(this)) >= (amountPROPTOToken + _buyerFee) , "Insufficient propto token allowance");
      require(proptoToken.balanceOf(msg.sender) >= (amountPROPTOToken + _buyerFee) , "Insufficient propto token balance");
    } else {
      (uint256 _buyerFee, uint256 _sellerFee) = _getFeeAmount(2, amountDSIPToken * DSIPPrice);
      require(dsipToken.allowance(msg.sender, address(this)) >= amountDSIPToken, "Insufficient DSIP token");
      require(dsipToken.balanceOf(msg.sender) >= amountDSIPToken, "Insufficient DSIP token");
      require(proptoToken.allowance(msg.sender, address(this)) >= _sellerFee, "Insufficient propto token allowance");
      require(proptoToken.balanceOf(msg.sender) >= _sellerFee, "Insufficient propto token balance");
      require(unlockedTokens(msg.sender, amountDSIPToken, dsipToken.balanceOf(msg.sender)), "Tokens are locked");
    }
    return orderBook.placeOrder(msg.sender, isBuyOrder, amountDSIPToken, amountPROPTOToken, expiryTimestamp);
  }

  function matchOrders(uint256 order1Id, uint256 order2Id) public {
    // We don't need to perform whitelist checks, since they
    // are already performed by _transferFromWithFee
    (address _traderA, address _traderB, uint256 _amountPROPTOToken, uint256 _amountDSIPToken) = orderBook.matchOrders(order1Id, order2Id);

    require(proptoToken.transferFrom(_traderA, _traderB, _amountPROPTOToken), "Transfer failed");
    require(_transferFromWithFee(_traderB, _traderA, _amountDSIPToken, _amountPROPTOToken), "Transfer failed");
  }

  function matchOrdersBatch(uint256[][2] memory orderPairs) public {
    // This function is merely a convenience vs sending multiple
    // transactions. It still performs externcal calls inside a
    // loop, but there's no way around that. We need the OrderBook
    // to make calculations, so this contract can execute the orders.
    for (uint i = 0; i < orderPairs.length; i++) {
      matchOrders(orderPairs[i][0], orderPairs[i][1]);
    }
  }

  function placeAndMatchOrder(bool isBuyOrder, uint256 amountSecurityToken, uint256 amountSaleToken, uint256 orderId) external {
    uint256 newOrderId = placeOrder(isBuyOrder, amountSecurityToken, amountSaleToken, block.timestamp + 1 days);
    matchOrders(newOrderId, orderId);
  }

  function setMaxPriceDiffForNewOrdersPct(uint8 _pct) external onlyOwner{
    orderBook.setMaxPriceDiffForNewOrdersPct(_pct);
  }

  function setLockingTimeSeconds(uint256 lockingTime) external onlyOwner {
    _setLockingTimeSeconds(lockingTime);
  }

  function _transferFromWithFee(address sender, address recipient, uint256 amount, uint256 amountPaid) private
    onlyWhitelisted(sender)
    onlyWhitelisted(recipient)
    whenNotPaused
    nonReentrant
    returns (bool)
  {
    require(unlockedTokens(sender, amount, dsipToken.balanceOf(sender)), "Tokens are locked");
    _takeFee(2, sender, recipient, amountPaid);
    dsipToken.transferFrom(sender, recipient, amount);
    writeSnapshot(recipient, dsipToken.balanceOf(recipient));
    writeSnapshot(sender, dsipToken.balanceOf(sender));
    annotateLockedFunds(recipient, amount);
    return true;
  }

  function writeSnapshot(address account, uint256 newBalance) public {
    _writeSnapshot(account, newBalance);
  }

  function annotateLockedFunds(address account, uint256 amount) public {
    _annotateLockedFunds(account, amount);
  }
}
