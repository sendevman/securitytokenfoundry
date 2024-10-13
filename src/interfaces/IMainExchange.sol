// SPDX-License-Identifier: All rights reserved and belonging to REClosure Ltd. 2023
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/interfaces/IDSIP.sol";
import "src/interfaces/IOrderBook.sol";
import "src/interfaces/IWhiteListManager.sol";

interface IMainExchange {

  error DSIPNotWhitelisted(address account);
  error DSIPDirectTransfersNotAllowed();

  event SetDividendPayer(address indexed dividendPayer);
  event SetDSIPToken(IDSIP indexed dsipToken);
  event SetOrderBook(IOrderBook indexed orderBook);
  event SetPartnerManager(IWhiteListManager indexed partnerManager);
  event SetProptoToken(IERC20 indexed proptoToken);
  event SetWhiteListManager(IWhiteListManager indexed whiteListManager);

  event Swap(address indexed trader, uint256 amountIn, uint256 amountOut, IDSIP indexed dsipToken, IERC20 indexed proptoToken, bool direction);
  event LiquidityAdded(address indexed provider, uint256 amountDSIP, uint256 amountPROPTO);
  event LiquidityRemoved(address indexed provider, uint256 amountDSIP, uint256 amountPROPTO);
  event DividendsRedeemed(address indexed holder, uint256 amount);

  function setDSIPToken(IDSIP _dsipToken) external;
  function setProptoToken(IERC20 _proptoToken) external;
  function setWhiteListManager(IWhiteListManager _whiteListManager) external;
  function setPartnerManager(IWhiteListManager _partnerManager) external;
  function setOrderBook(IOrderBook _orderBook) external;
  function setDividendPayer(address _dividendPayer) external;
  function getWhiteListed(address account) external view returns (bool);
  function getPartner(address sender, address recipient) external view returns (bool);
  function getOrderBook() external view returns (IOrderBook);
  function addLiquidity(uint256 amountDSIP, uint256 amountPROPTO) external;
  function removeLiquidity(uint256 amountDSIP, uint256 amountPROPTO) external;
  function swap(uint256 amountIn, bool isDSIPToPROPTO) external;
  function setNextPayment(uint256 onBlock, uint256 numTokens, IERC20 token) external;
  function redeemDividends(address recipient, uint256 lastIndex) external;
  function getLastPaymentToAddressIndex(address _address) external view returns (uint256);
  function getLastPaymentTermIndex() external view returns (uint256);
  function setFeeToken(IERC20 token) external;
  function setFeeStructure(uint16 buyerPrimaryMarketFee, uint16 sellerPrimaryMarketFee, uint16 buyerSecondaryMarketFee, uint16 sellerSecondaryMarketFee, uint16 dividendFeeReceiver, uint16 dividendFeeSender) external;
  function setFeeReceiverShares(uint8 marketType, address receiver, uint256 shares) external;
  function redeemFee(uint8 marketType, IERC20 token, address recipient) external;
  function placeOrder(bool isBuyOrder, uint256 amountSecurityToken, uint256 amountSaleToken, uint256 expiryTimestamp) external returns (uint256);
  function matchOrders(uint256 order1Id, uint256 order2Id) external;
  function matchOrdersBatch(uint256[][2] memory orderPairs) external;
  function placeAndMatchOrder(bool isBuyOrder, uint256 amountSecurityToken, uint256 amountSaleToken, uint256 orderId) external;
  function setMaxPriceDiffForNewOrdersPct(uint8 _pct) external;
  function setLockingTimeSeconds(uint256 lockingTime) external;
  function writeSnapshot(address account, uint256 newBalance) external;
  function annotateLockedFunds(address account, uint256 amount) external;
}
