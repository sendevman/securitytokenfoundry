// SPDX-License-Identifier: All rights reserved and belonging to REClosure Ltd. 2023
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract FeeManager {

	error InvalidMarketType();

	event SetFeeTokenEvent(IERC20 token);
	event FeeRedeemedEvent(uint8 marketType, address recipient, uint256 payment);
	event SetFeeReceiverSharesEvent(uint8 marketType, address payee, uint256 shares);
	event SetFeeStructureEvent(FeeStructure primaryMarketFee, FeeStructure secondaryMarketFee, FeeStructure dividendFee);


	struct FeeStructure
	{
		uint16 buyer;
		uint16 seller;
	}


	FeeStructure private primaryMarketFee;
	FeeStructure private secondaryMarketFee;
	FeeStructure private dividendFee;

	uint16 private constant FEE_DIVIDER = 10000; 
	IERC20 feeToken;

	// marketType => feeToken => userAddress => alreadyPaid 
    mapping(uint8 => mapping(IERC20 => mapping(address => uint256 ))) private alreadyPaid;

	// marketType => userAddress => shares
    mapping(uint8 => mapping(address => uint256)) private userShares;

	// marketType => feeToken => totalReleased
	mapping(uint8 => mapping(IERC20 => uint256)) private totalReleased;

	// marketType => feeToken => totalOwed (we don't use balanceOf deliberately)
	mapping(uint8 => mapping(IERC20 => uint256)) private totalOwed;

	// marketType => totalShares
    mapping(uint8 => uint256) private totalShares;
    

    constructor() {
    }

	function _getFeesByMarket(uint8 marketType) private view 
	returns (FeeStructure memory)
	{
		if (marketType==1)
		{
			return primaryMarketFee;
		}else if (marketType==2)
		{
			return secondaryMarketFee;
		}else if (marketType==3)
		{
			return dividendFee;
		} else
		{
			revert InvalidMarketType();
		}
		
	}

	function _getFeeAmount(uint8 marketType, uint256 amount) internal view 
	returns (uint256 buyerFee, uint256 sellerFee)
	{

		FeeStructure memory _fees;

		_fees = _getFeesByMarket(marketType);

		buyerFee = amount * _fees.buyer / FEE_DIVIDER;
		sellerFee = amount * _fees.buyer / FEE_DIVIDER;
	}

	function _takeFee(uint8 marketType, address seller, address buyer, uint256 amount) internal 
	{

		require(marketType<3, "Use _takeDividendFee");
		IERC20 _feeToken = feeToken;

		FeeStructure memory _fees;

		_fees = _getFeesByMarket(marketType);

		totalOwed[marketType][_feeToken]+=amount * (_fees.buyer + _fees.seller) / FEE_DIVIDER;

		// The IFs are there to skip computations when there's no fee (gas savings)
		if (_fees.buyer>0)
		{
			require(
				_feeToken.transferFrom(buyer, address(this), amount * _fees.buyer / FEE_DIVIDER),
				"Error getting buyer fee"
			);
		}

		if (_fees.seller>0)
		{
			require(
				_feeToken.transferFrom(seller, address(this), amount * _fees.seller / FEE_DIVIDER ),
				"Error getting seller fee"
			);
		}
	}

    function _takeDividendFee(address seller, uint256 amount, IERC20 _token) internal 
    returns (uint256)
    {

		// _takeDividendFee is slightly but significantly different than _takeFee
		// It takes the "seller" fee from the "giver", and then discounts the "receiver"
		// part.
		IERC20 _feeToken = feeToken;

		require(address(_token) == address(_feeToken), "Dividend and fee token must be the same");

		FeeStructure memory _fees;
		uint8 _marketType = 3;

		_fees = _getFeesByMarket(_marketType);

		totalOwed[_marketType][_feeToken]+=amount * (_fees.buyer + _fees.seller) / FEE_DIVIDER;

		require(
			_feeToken.transferFrom(seller, address(this), amount * (_fees.buyer + _fees.seller) / FEE_DIVIDER ),
			"Error getting seller fee"
		);

		uint256 remainingAmount = amount - amount * _fees.buyer / FEE_DIVIDER;

        return remainingAmount;
    }

    function getFeeToken() internal view
    returns (IERC20)
    {
        return feeToken;
    }


	function _setFeeToken(IERC20 _token) internal 
	{
        feeToken = _token;
		emit SetFeeTokenEvent(_token);
    }


	function _setFeeStructure(uint16 _buyerPrimaryMarketFee, uint16 _sellerPrimaryMarketFee, uint16 _buyerSecondaryMarketFee, uint16 _sellerSecondaryMarketFee, uint16 _dividendFeeReceiver, uint16 _dividendFeeSender) internal
	{
		primaryMarketFee  = FeeStructure(_buyerPrimaryMarketFee, _sellerPrimaryMarketFee);
		secondaryMarketFee  = FeeStructure(_buyerSecondaryMarketFee, _sellerSecondaryMarketFee);
		dividendFee = FeeStructure(_dividendFeeReceiver, _dividendFeeSender);
		
		emit SetFeeStructureEvent(primaryMarketFee, secondaryMarketFee, dividendFee);
	}

    function _setFeeReceiverShares(uint8 _marketType, address _payee, uint256 _shares) internal {
        require(_payee != address(0), "Invalid payee address");
        require(_shares > 0, "Shares must be greater than zero");
		require(_shares < type(uint128).max, "Num shares cannot exceed uint128");

		uint256 _shares0 = userShares[_marketType][_payee];
		if (_shares > _shares0)
		{
			uint256 delta = _shares - _shares0; 
	        userShares[_marketType][_payee] += delta;
	        totalShares[_marketType] += delta;
		}else
		{
			uint256 delta = _shares0 - _shares;
	        userShares[_marketType][_payee] -= delta;
	        totalShares[_marketType] -= delta;

		}
		emit SetFeeReceiverSharesEvent(_marketType, _payee, _shares);
    }

    function _redeemFee(uint8 _marketType, IERC20 _token, address _recipient) internal {
		require(address(_token)!=address(this), "Cannot redeem DSIP token");

		uint256 _shares = userShares[_marketType][_recipient];

        require(_shares > 0, "Recipient not entitled to payment");

        uint256 payment = _calculatePendingFeePayment(totalOwed[_marketType][_token], _shares, totalReleased[_marketType][_token], alreadyPaid[_marketType][_token][_recipient], totalShares[_marketType]);
        require(payment > 0, "You are not owed any payment");


        alreadyPaid[_marketType][_token][_recipient] += payment;
        totalReleased[_marketType][_token]  += payment;
		totalOwed[_marketType][_token] -= payment;

		emit FeeRedeemedEvent(_marketType, _recipient, payment);

        require(
			_token.transfer(_recipient, payment),
			"Error transferring token"
		);
		

    }

	function _calculatePendingFeePayment(
		uint256 _totalOwed,
		uint256 _shares,
		uint256 _totalReleased,
		uint256 _alreadyPaid,
		uint256 _totalShares
	) private view returns (uint256) {
		uint256 totalReceived = _totalOwed + _totalReleased;
		uint256 payment;

		payment = (totalReceived * _shares) / _totalShares - _alreadyPaid;
		return payment;
	}



}

