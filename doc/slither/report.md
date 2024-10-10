**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [solc-version](#solc-version) (3 results) (Informational)
 - [timestamp](#timestamp) (6 results) (Low)
 - [arbitrary-send-erc20](#arbitrary-send-erc20) (2 results) (High)
 - [incorrect-equality](#incorrect-equality) (1 results) (Medium)
 - [reentrancy-no-eth](#reentrancy-no-eth) (1 results) (Medium)
 - [uninitialized-local](#uninitialized-local) (3 results) (Medium)
 - [shadowing-local](#shadowing-local) (1 results) (Low)
 - [calls-loop](#calls-loop) (5 results) (Low)
 - [reentrancy-events](#reentrancy-events) (2 results) (Low)
 - [naming-convention](#naming-convention) (6 results) (Informational)
 - [similar-names](#similar-names) (2 results) (Informational)
## solc-version
Impact: Informational
Confidence: High
 - [ ] ID-0
solc-0.8.22 is not recommended for deployment

 - [ ] ID-1
solc-0.8.22 is not recommended for deployment

 - [ ] ID-2
solc-0.8.22 is not recommended for deployment

## timestamp
Impact: Low
Confidence: Medium
 - [ ] ID-3
[OrderBook.matchOrders(uint256,uint256)](src/OrderBook.sol#L45-L147) uses timestamp for comparisons
	Dangerous comparisons:
	- [block.timestamp > order1.expiryTimestamp](src/OrderBook.sol#L68)
	- [block.timestamp > order2.expiryTimestamp](src/OrderBook.sol#L81)

src/OrderBook.sol#L45-L147


 - [ ] ID-4
[OrderBook.matchOrders(uint256,uint256)](src/OrderBook.sol#L45-L147) uses timestamp for comparisons
	Dangerous comparisons:
	- [block.timestamp > order1.expiryTimestamp](src/OrderBook.sol#L68)
	- [block.timestamp > order2.expiryTimestamp](src/OrderBook.sol#L81)

src/OrderBook.sol#L45-L147


 - [ ] ID-5
[DSIP.matchOrders(uint256,uint256)](src/DSIP.sol#L311-L318) uses timestamp for comparisons
	Dangerous comparisons:
	- [require(bool,string)(_saleToken.transferFrom(_traderA,_traderB,_amountSaleToken),Transfer failed)](src/DSIP.sol#L316)
	- [require(bool,string)(_transferFromWithFee(_traderB,_traderA,_amountSecurityToken,_amountSaleToken),Transfer failed)](src/DSIP.sol#L317)

src/DSIP.sol#L311-L318


 - [ ] ID-6
[LockManager.unlockedTokens(address,uint256,uint256)](src/extensions/LockManager.sol#L20-L38) uses timestamp for comparisons
	Dangerous comparisons:
	- [block.timestamp < (lockedAmounts[account][i].receivedTimestamp + _lockingSeconds)](src/extensions/LockManager.sol#L33)

src/extensions/LockManager.sol#L20-L38


 - [ ] ID-7
[DSIP.placeOrder(bool,uint256,uint256,uint256)](src/DSIP.sol#L277-L309) uses timestamp for comparisons
	Dangerous comparisons:
	- [require(bool,string)(balanceOf(msg.sender) >= amountSecurityToken,Insufficient security token)](src/DSIP.sol#L299)

src/DSIP.sol#L277-L309


 - [ ] ID-8
[DSIP._transferFromWithFee(address,address,uint256,uint256)](src/DSIP.sol#L246-L260) uses timestamp for comparisons
	Dangerous comparisons:
	- [require(bool,string)(unlockedTokens(sender,amount,balanceOf(sender)),Tokens are locked)](src/DSIP.sol#L252)

src/DSIP.sol#L246-L260


## arbitrary-send-erc20
Impact: High
Confidence: High
 - [ ] ID-9
[SaleManager._payPricePrimaryMarket(address,address,uint256)](src/extensions/SaleManager.sol#L23-L39) uses arbitrary from in transferFrom: [require(bool,string)(saleToken.transferFrom(buyer,seller,amount),Error paying for tokens)](src/extensions/SaleManager.sol#L32-L35)

src/extensions/SaleManager.sol#L23-L39


 - [ ] ID-10
[DividendManager._setNextPayment(uint256,uint256,IERC20,address)](src/extensions/DividendManager.sol#L43-L63) uses arbitrary from in transferFrom: [require(bool,string)(token.transferFrom(seller,address(this),numTokens),Error funding dividend contract)](src/extensions/DividendManager.sol#L57-L60)

src/extensions/DividendManager.sol#L43-L63


## incorrect-equality
Impact: Medium
Confidence: High
 - [ ] ID-11
[DividendManager._writeSnapshot(address,uint256)](src/extensions/DividendManager.sol#L65-L76) uses a dangerous strict equality:
	- [nSnapshot > 0 && _snapshots[account][nSnapshot].fromBlock == blockNumber](src/extensions/DividendManager.sol#L70)

src/extensions/DividendManager.sol#L65-L76


## reentrancy-no-eth
Impact: Medium
Confidence: Medium
 - [ ] ID-12
Reentrancy in [DividendManager._redeemDividends(address,uint256)](src/extensions/DividendManager.sol#L79-L116):
	External calls:
	- [require(bool,string)(_dividendToken.transfer(recipient,amount),Error transferring token)](src/extensions/DividendManager.sol#L105-L108)
	State variables written after the call(s):
	- [lastPaymentToAddressIndex[recipient] = _lastIndexToIterate](src/extensions/DividendManager.sol#L113)

src/extensions/DividendManager.sol#L79-L116


## uninitialized-local
Impact: Medium
Confidence: Medium
 - [ ] ID-13
[FeeManager._getFeeAmount(uint8,uint256)._fees](src/extensions/FeeManager.sol#L51) is a local variable never initialized

src/extensions/FeeManager.sol#L51


 - [ ] ID-14
[FeeManager._takeFee(uint8,address,address,uint256)._fees](src/extensions/FeeManager.sol#L75) is a local variable never initialized

src/extensions/FeeManager.sol#L75


 - [ ] ID-15
[DividendManager.constructor(uint256).placeholder](src/extensions/DividendManager.sol#L37) is a local variable never initialized

src/extensions/DividendManager.sol#L37


## shadowing-local
Impact: Low
Confidence: High
 - [ ] ID-16
[DSIP.setFeeStructure(uint16,uint16,uint16,uint16,uint16).dividendFee](src/DSIP.sol#L152) shadows:
	- [FeeManager.dividendFee](src/extensions/FeeManager.sol#L23) (state variable)

src/DSIP.sol#L152


## calls-loop
Impact: Low
Confidence: Medium
 - [ ] ID-17
[DSIP.matchOrders(uint256,uint256)](src/DSIP.sol#L311-L318) has external calls inside a loop: [(_traderA,_traderB,_amountSaleToken,_amountSecurityToken) = orderBook.matchOrders(order1Id,order2Id)](src/DSIP.sol#L313)

src/DSIP.sol#L311-L318


 - [ ] ID-18
[FeeManager._takeFee(uint8,address,address,uint256)](src/extensions/FeeManager.sol#L71-L110) has external calls inside a loop: [require(bool,string)(_feeToken.transferFrom(buyer,address(this),amount * _fees.buyer / MAX_FEE),Error getting buyer fee)](src/extensions/FeeManager.sol#L95-L98)

src/extensions/FeeManager.sol#L71-L110


 - [ ] ID-19
[DSIP.matchOrders(uint256,uint256)](src/DSIP.sol#L311-L318) has external calls inside a loop: [require(bool,string)(_saleToken.transferFrom(_traderA,_traderB,_amountSaleToken),Transfer failed)](src/DSIP.sol#L316)

src/DSIP.sol#L311-L318


 - [ ] ID-20
[DSIP.onlyWhitelisted(address)](src/DSIP.sol#L45-L51) has external calls inside a loop: [account != address(this) && ! identityManager.isWhitelisted(account)](src/DSIP.sol#L47)

src/DSIP.sol#L45-L51


 - [ ] ID-21
[FeeManager._takeFee(uint8,address,address,uint256)](src/extensions/FeeManager.sol#L71-L110) has external calls inside a loop: [require(bool,string)(_feeToken.transferFrom(seller,address(this),amount * _fees.seller / MAX_FEE),Error getting seller fee)](src/extensions/FeeManager.sol#L103-L106)

src/extensions/FeeManager.sol#L71-L110


## reentrancy-events
Impact: Low
Confidence: Medium
 - [ ] ID-22
Reentrancy in [DividendManager._redeemDividends(address,uint256)](src/extensions/DividendManager.sol#L79-L116):
	External calls:
	- [require(bool,string)(_dividendToken.transfer(recipient,amount),Error transferring token)](src/extensions/DividendManager.sol#L105-L108)
	Event emitted after the call(s):
	- [DividendRedeemedEvent(recipient,amount)](src/extensions/DividendManager.sol#L110)

src/extensions/DividendManager.sol#L79-L116


 - [ ] ID-23
Reentrancy in [DividendManager._setNextPayment(uint256,uint256,IERC20,address)](src/extensions/DividendManager.sol#L43-L63):
	External calls:
	- [require(bool,string)(token.transferFrom(seller,address(this),numTokens),Error funding dividend contract)](src/extensions/DividendManager.sol#L57-L60)
	Event emitted after the call(s):
	- [SetDividendScheduleEvent(_paymentTerm)](src/extensions/DividendManager.sol#L62)

src/extensions/DividendManager.sol#L43-L63


## naming-convention
Impact: Informational
Confidence: High
 - [ ] ID-24
Parameter [DSIP.setOrderBook(IOrderBook)._orderBook](src/DSIP.sol#L137) is not in mixedCase

src/DSIP.sol#L137


 - [ ] ID-25
Parameter [DSIP.setIdentityManager(IIdentityManager)._identityManager](src/DSIP.sol#L108) is not in mixedCase

src/DSIP.sol#L108


 - [ ] ID-26
Parameter [DSIP.getLastPaymentToAddressIndex(address)._address](src/DSIP.sol#L213) is not in mixedCase

src/DSIP.sol#L213


 - [ ] ID-27
Variable [DividendManager.MAX_TOKENS](src/extensions/DividendManager.sol#L13) is not in mixedCase

src/extensions/DividendManager.sol#L13


 - [ ] ID-28
Parameter [DSIP.setInitialSeller(address)._seller](src/DSIP.sol#L115) is not in mixedCase

src/DSIP.sol#L115


 - [ ] ID-29
Parameter [DSIP.setDividendPayer(address)._dividendPayer](src/DSIP.sol#L123) is not in mixedCase

src/DSIP.sol#L123


## similar-names
Impact: Informational
Confidence: Medium
 - [ ] ID-30
Variable [DividendManager._setNextPayment(uint256,uint256,IERC20,address)._paymentTerm](src/extensions/DividendManager.sol#L50) is too similar to [DividendManager.paymentTerms](src/extensions/DividendManager.sol#L29)

src/extensions/DividendManager.sol#L50


 - [ ] ID-31
Variable [LockManager.unlockedTokens(address,uint256,uint256)._lockedAmount](src/extensions/LockManager.sol#L29) is too similar to [LockManager.lockedAmounts](src/extensions/LockManager.sol#L14)

src/extensions/LockManager.sol#L29


