// SPDX-License-Identifier: All rights reserved and belonging to REClosure Ltd. 2023
pragma solidity ^0.8.18;

import "src/interfaces/IOrderBook.sol";
import "src/interfaces/IIdentityManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDSIP is IERC20{

	// Errors
	error DSIPNotWhitelisted(address account);
	error DSIPDirectTransfersNotAllowed();

    // Events
    event ForceTransfer(address indexed from, address indexed to, uint256 amount);
    event SetIdentityManager(IIdentityManager indexed identityManager); 
    event SetPartnerManager(IIdentityManager indexed partnerManager); 
    event SetInitialSeller(address indexed seller); 
    event SetDividendPayer(address indexed dividendPayer);
    event SetOrderBook(IOrderBook indexed orderBook);
    //event Transfer(address from, address to, uint256 amount, IERC20 feeToken, uint256 totalBuyerFee, uint256 totalSellerFee);


	function pause() external;
	function unpause() external;
	function getCap() external view returns (uint256);

	function mintWithoutPayment(address to, uint256 tokenAmount) external;
	function mintWithPayment(address to, uint256 tokenAmount) external;
    function forceTransfer(address from, address to, uint256 amount) external returns (bool);

    function setIdentityManager(IIdentityManager _identityManager) external;
    function setPartnerManager(IIdentityManager _partnerManager) external;

    function setMigrationAddress(address _migrationAddress) external;

    function setInitialSeller(address _seller) external;
    function setSaleToken(IERC20 token) external;
    function setPricePrimaryMarket(uint256 price) external;
    function setLockingTimeSeconds(uint256 lockingTime) external;

    function getOrderBook() external view returns (IOrderBook);
    function setOrderBook(IOrderBook _orderBook) external;
    function setDividendPayer(address _dividendPayer) external;
    function redeemDividends(address recipient, uint256 lastIndex) external;
    function setNextPayment(uint256 onBlock, uint256 numTokens, IERC20 token) external;
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

}

