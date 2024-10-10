// SPDX-License-Identifier: All rights reserved and belonging to REClosure Ltd. 2023
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

abstract contract DividendManager { 

	event SetDividendScheduleEvent(PaymentTerm); 
	event DividendRedeemedEvent(address recipient, uint256 amount);

	using Math for uint;
	uint256 private immutable MAX_TOKENS;

    struct Snapshot {
        uint256 fromBlock;
        uint256 balance;
    }

	// userAddress, index => snapshot
    mapping(address => mapping(uint256 => Snapshot)) private _snapshots;
    mapping(address => uint256) private _numSnapshots;

    struct PaymentTerm {
        uint256 onBlock;
        uint256 amount;
		IERC20 token;
    }
	mapping(uint256 => PaymentTerm) private paymentTerms;
	uint256 internal lastPaymentTermIndex; 

	mapping(address => uint256) internal lastPaymentToAddressIndex;


	constructor(uint256 max_tokens) {
		MAX_TOKENS = max_tokens;
		IERC20 placeholder;
		paymentTerms[0] = PaymentTerm(0, 0, placeholder);
		
	}


	function _setNextPayment(uint256 onBlock, uint256 numTokens, IERC20 token, address seller) internal
	{


		require(onBlock > paymentTerms[lastPaymentTermIndex].onBlock, "Block number must be larger than last one");
		lastPaymentTermIndex++;

		PaymentTerm memory _paymentTerm = PaymentTerm(onBlock, numTokens, token);
		paymentTerms[lastPaymentTermIndex] = _paymentTerm;

        // Slither complains about the use of arbitrary from in
        // transferFrom. But bear in mind that this _internal_
        // function can only be called by DSIP's setNextPayment,
        // which hardcodes it to dividendPayer. 
        require(
            token.transferFrom(seller, address(this), numTokens),
            "Error funding dividend contract"
        );

		emit SetDividendScheduleEvent(_paymentTerm);
	}

    function _writeSnapshot(address account, uint256 newBalance) internal {

        uint256 blockNumber = block.number;
		uint256 nSnapshot = _numSnapshots[account];

        if (nSnapshot > 0 && _snapshots[account][nSnapshot].fromBlock == blockNumber) {
            _snapshots[account][nSnapshot].balance = newBalance;
        } else {
            _snapshots[account][nSnapshot] = Snapshot(blockNumber, newBalance);
        }
		_numSnapshots[account] = nSnapshot + 1;
    }


	function _redeemDividends(address recipient, uint256 _lastIndex) internal returns (uint256){

		// _lastIndex is specified to avoid niche OutOfGas errors.
		// Usually you should make it type(uint256).max and let it run.
		// Decrease it only if you run out of gas.

		uint256 totalAmount = 0;
		uint256 _lastIndexToIterate = lastPaymentTermIndex.min(_lastIndex);

		for (uint256 i = lastPaymentToAddressIndex[recipient]+1; i <= _lastIndexToIterate; i++) {
			uint256 payingTermsNumTokens = paymentTerms[i].amount;
			uint256 startBlock = paymentTerms[i-1].onBlock;
			uint256 endBlock = paymentTerms[i].onBlock;
			uint256 payingTermsNumBlocks = endBlock - startBlock; 
			IERC20 _dividendToken = paymentTerms[i].token; 
	
			uint256 amount = _getTokensTime(recipient, startBlock, endBlock) *  payingTermsNumTokens / payingTermsNumBlocks / MAX_TOKENS;
			totalAmount += amount;


			// Here we might have a reentrancy risk. On the other
			// hand, _dividenToken is set by the Owner, and thus
			// assumed to be trusted. In addition, this internal
			// function is called by DSIP's redeemDividends, which
			// is nonReentrant.

			require(
				_dividendToken.transfer(recipient, amount),
				"Error transferring token"
			);

			emit DividendRedeemedEvent(recipient, amount);
		}

		lastPaymentToAddressIndex[recipient] = _lastIndexToIterate;

		return totalAmount;
	}

	function _getTokensTime(address account, uint256 startBlock, uint256 endBlock) private view returns (uint256) {
		require(startBlock <= endBlock, "Start block must be less than or equal to end block");

		uint256 nSnapshots = _numSnapshots[account];

		require(nSnapshots>0, "Never owned this token");

		uint256 tokensTime = 0;

		Snapshot memory currentSnapshot;
		Snapshot memory nextSnapshot;
		uint256 currentBlockNumber;
		uint256 nextBlockNumber;

		// Question: Is it reasonable to worry about hitting gas limits here?
		// (i.e. nSapshots too large)

		for (uint256 i = 0; i < nSnapshots - 1; i++) {
			currentSnapshot = _snapshots[account][i];
			currentBlockNumber = currentSnapshot.fromBlock;

			if (currentBlockNumber >= endBlock) {
				break;
			}

			nextSnapshot = _snapshots[account][i+1];
			nextBlockNumber = nextSnapshot.fromBlock;

			if (currentBlockNumber >= startBlock) {
				tokensTime += currentSnapshot.balance * (nextBlockNumber - currentBlockNumber);
			}
		}

		currentSnapshot = _snapshots[account][nSnapshots-1];
		currentBlockNumber = currentSnapshot.fromBlock.max(startBlock);
		nextBlockNumber = endBlock;

		if (currentBlockNumber < nextBlockNumber) {
			tokensTime += currentSnapshot.balance * (nextBlockNumber - currentBlockNumber);
		}


		return tokensTime;
	}



}

