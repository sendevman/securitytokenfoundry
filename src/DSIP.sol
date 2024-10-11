// SPDX-License-Identifier: All rights reserved and belonging to REClosure Ltd. 2023 
pragma solidity ^0.8.18;

import "src/interfaces/IDSIP.sol";
import "src/interfaces/IIdentityManager.sol";
import "src/interfaces/IOrderBook.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "src/OrderBook.sol";
import "src/extensions/FeeManager.sol";
import "src/extensions/DividendManager.sol";
import "src/extensions/SaleManager.sol";
import "src/extensions/LockManager.sol";

contract DSIP is IDSIP, Ownable, Pausable, ReentrancyGuard, ERC20Capped, DividendManager, FeeManager, SaleManager, LockManager {

  IIdentityManager identityManager;
  IIdentityManager partnerManager;
  IOrderBook orderBook;

  address public migrationAddress;
  address public seller;
  address public dividendPayer;

  constructor(
    string memory name,
    string memory symbol,
    uint256 cap,
    address _issuer
  ) 	
    Ownable(_issuer)
    ERC20(name, symbol)
    ERC20Capped(cap)
    FeeManager()
    DividendManager(cap)
    SaleManager()
  {}

  // AUX
  modifier onlyWhitelisted(address account) {
    if (account != address(this) && !identityManager.isWhitelisted(account)) {
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
    require(msg.sender==dividendPayer, "Not dividendPayer");
    _;
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }

  function getCap() external view returns (uint256){
    return cap();
  }

  // Special function: MINT
  function mintWithoutPayment(address to, uint256 tokenAmount) external
    onlyOwner
    onlyWhitelisted(to)
    nonReentrant
  {
    _mint(to, tokenAmount);
    _writeSnapshot(to, balanceOf(to));
    _annotateLockedFunds(to, tokenAmount);

    // IERC20 _feeToken = getFeeToken();
    // emit Transfer(address(0), to, tokenAmount, _feeToken, 0, 0);
  }

  function mintWithPayment(address to, uint256 tokenAmount) external
    onlyOwner 
    onlyWhitelisted(to)
    nonReentrant
  {
    uint256 amount = _payPricePrimaryMarket(seller, to, tokenAmount);
    _takeFee(1, seller, to, amount);
    _mint(to, tokenAmount);
    _writeSnapshot(to, balanceOf(to));
    _annotateLockedFunds(to, tokenAmount);
  }

  // **********************
  // *					*
  // *	INITIALIZERS	*
  // *					*
  // **********************

  // Roles
  function setIdentityManager(IIdentityManager _identityManager) external onlyOwner {
    identityManager = _identityManager;
    emit SetIdentityManager(_identityManager);
  }

  function setPartnerManager(IIdentityManager _partnerManager) external onlyOwner {
    partnerManager = _partnerManager;
    emit SetPartnerManager(_partnerManager);
  }

  function setInitialSeller(address _seller) external onlyOwner {
    require(_seller!=address(0), "Seller cannot be the zero address");
    seller = _seller;
    emit SetInitialSeller(_seller);
  }

  function setDividendPayer(address _dividendPayer) external onlyOwner {
    require(_dividendPayer!=address(0), "Dividend Payer cannot be the zero address");
    dividendPayer = _dividendPayer;
    emit SetDividendPayer(_dividendPayer);
  }

  function getOrderBook() external view returns (IOrderBook) {
    return orderBook; 
  }

  function setOrderBook(IOrderBook _orderBook) external onlyOwner {
    orderBook = _orderBook;
    emit SetOrderBook(_orderBook);
  }

  // Fees
  function setFeeToken(IERC20 token) external onlyOwner {
    _setFeeToken(token);
  }

  function setFeeStructure(
    uint16 buyerPrimaryMarketFee,
    uint16 sellerPrimaryMarketFee,
    uint16 buyerSecondaryMarketFee,
    uint16 sellerSecondaryMarketFee,
    uint16 dividendFeeReceiver,
    uint16 dividendFeeSender
  ) external onlyOwner {
    _setFeeStructure(buyerPrimaryMarketFee, sellerPrimaryMarketFee, buyerSecondaryMarketFee, sellerSecondaryMarketFee, dividendFeeReceiver, dividendFeeSender);	
  }

  function setFeeReceiverShares(uint8 marketType, address receiver, uint256 shares) external
    onlyOwner
    onlyWhitelisted(receiver)
  {
    _setFeeReceiverShares(marketType, receiver, shares);
  }

  function redeemFee(uint8 marketType, IERC20 token, address recipient) external
    onlyWhitelisted(recipient)
    nonReentrant
  {
    _redeemFee(marketType, token, recipient);
  }

  // Primary sale
  function setSaleToken(IERC20 token) external onlyOwner {
    _setSaleToken(token);
    orderBook = new OrderBook(address(this));
    emit SetOrderBook(orderBook);
  }

  function setPricePrimaryMarket(uint256 price) external onlyOwner {
    _setPricePrimaryMarket(price);
  }

  function setLockingTimeSeconds(uint256 lockingTime) external onlyOwner {
    _setLockingTimeSeconds(lockingTime);
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

  // ERC20 Overrides
  function approve(address spender, uint256 value) public override(ERC20, IERC20) onlyWhitelisted(spender) returns (bool) {
    return super.approve(spender, value);
  }

  function transfer(address recipient, uint256 amount) public override(ERC20, IERC20)
    onlyWhitelisted(msg.sender)
    onlyWhitelisted(recipient)
    onlyTransferFreeApproved(msg.sender, recipient) 
    returns(bool)
  {
    return super.transfer(recipient, amount);
  }

  function transferFrom(address sender, address recipient, uint256 amount) public override(ERC20, IERC20)
    onlyWhitelisted(sender)
    onlyWhitelisted(recipient)
    onlyTransferFreeApproved(sender, recipient)
    returns(bool)
  {
    return super.transferFrom(sender, recipient, amount);
  }

  function _transferFromWithFee(address sender, address recipient, uint256 amount, uint256 amountPaid) private 
    onlyWhitelisted(sender)
    onlyWhitelisted(recipient)
    whenNotPaused
    nonReentrant
    returns (bool)
  {
    require(unlockedTokens(sender, amount, balanceOf(sender)), "Tokens are locked");
    _takeFee(2, sender, recipient, amountPaid);
    _transfer(sender, recipient, amount);
    _writeSnapshot(recipient, balanceOf(recipient));
    _writeSnapshot(sender, balanceOf(sender));
    _annotateLockedFunds(recipient, amount);
    return true;
  }

  function forceTransfer(address from, address to, uint256 amount) public
    onlyOwner 
    onlyWhitelisted(to)
    returns (bool) 
  {
    _transfer(from, to, amount);
    _writeSnapshot(from, balanceOf(from));
    _writeSnapshot(to, balanceOf(to));
    _annotateLockedFunds(to, amount);
    emit ForceTransfer(from, to, amount);
    return true;
  }

  // Trading functions
  function placeOrder(bool isBuyOrder, uint256 amountSecurityToken, uint256 amountSaleToken, uint256 expiryTimestamp) public
    onlyWhitelisted(msg.sender)
    whenNotPaused
    returns (uint256)
  {
    IERC20 _saleToken = getSaleToken();
    IERC20 _feeToken = getFeeToken();

    // Let's check that _at least now_ there's enough approved to
    // cover for that. Granted, the user can always withdraw their
    // approval, but that'd be only a minor annoyance.

    // TODO: Require a fee for placing orders to avoid spam?
    (uint256 _buyerFee, uint256 _sellerFee) = _getFeeAmount(2, amountSaleToken);
    if (isBuyOrder) {
      require(_saleToken.allowance(msg.sender, address(this)) >= amountSaleToken , "Insufficient sale token allowance");
      require(_saleToken.balanceOf(msg.sender) >= amountSaleToken , "Insufficient sale token balance");
      require(_feeToken.allowance(msg.sender, address(this)) >= _buyerFee, "Insufficient fee token allowance");
      require(_feeToken.balanceOf(msg.sender) >= _buyerFee, "Insufficient fee token balance");
    } else {
      require(balanceOf(msg.sender) >= amountSecurityToken, "Insufficient security token");
      require(_feeToken.allowance(msg.sender, address(this)) >= _sellerFee, "Insufficient fee token allowance");
      require(_feeToken.balanceOf(msg.sender) >= _sellerFee, "Insufficient fee token balance");
      require(unlockedTokens(msg.sender, amountSecurityToken, balanceOf(msg.sender)), "Tokens are locked");
    }
    return orderBook.placeOrder(msg.sender, isBuyOrder, amountSecurityToken, amountSaleToken, expiryTimestamp);
  }

  function matchOrders(uint256 order1Id, uint256 order2Id) public {
    // We don't need to perform whitelist checks, since they
    // are already performed by _transferFromWithFee
    (address _traderA, address _traderB, uint256 _amountSaleToken, uint256 _amountSecurityToken) = orderBook.matchOrders(order1Id, order2Id);
    IERC20 _saleToken = getSaleToken();

    require(_saleToken.transferFrom(_traderA, _traderB, _amountSaleToken), "Transfer failed");
    require(_transferFromWithFee(_traderB, _traderA, _amountSecurityToken, _amountSaleToken), "Transfer failed");
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

  function setMigrationAddress (address _migrationAddress) external onlyOwner {
    migrationAddress = _migrationAddress;
  }

  function setMaxPriceDiffForNewOrdersPct(uint8 _pct) external onlyOwner{
    orderBook.setMaxPriceDiffForNewOrdersPct(_pct);
  }	
}
