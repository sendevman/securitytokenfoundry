// SPDX-License-Identifier: All rights reserver 2023  
pragma solidity ^0.8.18;

import "src/interfaces/IDSIP.sol";
import "src/interfaces/IIdentityManager.sol";
import "src/interfaces/IOrderBook.sol";

import "src/DSIP.sol";
import "src/IdentityManager.sol";

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/console.sol";

contract MyToken is ERC20{

	constructor(
		string memory name,
		string memory symbol
	)
		ERC20(name, symbol)
	{
	}

	function mint(address to, uint256 amount) external {
		_mint(to, amount);
	}

}


contract DSIPTest is Test {
	
	IDSIP tokenDSIP;
	IIdentityManager identityManager;


	address investor1 = vm.addr(1);
	address investor2 = vm.addr(2);

	address colister1 = vm.addr(3);
	address colister2 = vm.addr(4);

	address seller = vm.addr(5);

	address propertyManager = vm.addr(6);

	uint256 pricePrimaryMarket=1e18;
	uint16 fee=50;

	uint256 CAP = 100e21;


	MyToken tokenFee;
	MyToken tokenDividend;
	MyToken tokenPrimarySale;

    function setUp() public {

		identityManager = new IdentityManager(
					address(this)
		);

		tokenFee = new MyToken("Fee Token", "FTK");
		tokenDividend = tokenFee; 
		tokenPrimarySale = new MyToken("Token Primary Sale", "USDT");
		
		tokenDSIP = new DSIP(
				"DSIP",
				"DSP",
				CAP,
				address(this)
		);

		
		// Token creation
		tokenDSIP.setIdentityManager(identityManager);
		tokenDSIP.setInitialSeller(seller);
		tokenDSIP.setDividendPayer(propertyManager);
		tokenDSIP.setFeeToken(tokenFee);
		tokenDSIP.setSaleToken(tokenPrimarySale);
		tokenDSIP.setPricePrimaryMarket(pricePrimaryMarket);
		tokenDSIP.setLockingTimeSeconds(0);
		tokenDSIP.setFeeStructure(fee, fee, fee, fee, 0, 0);

		// Distribute tokens to investor and seller
		// for them to pay fees and securities (ERC20)
		tokenFee.mint(investor1, 1e24);
		tokenFee.mint(investor2, 1e24);
		tokenFee.mint(seller, 1e24);

		tokenPrimarySale.mint(investor1, 1e6*1e18);
		tokenPrimarySale.mint(investor2, 1e6*1e18);
		tokenPrimarySale.mint(seller, 1e6*1e18);


		// Give the divident payer (property manager here)
		// some funds to pay for dividends
		tokenDividend.mint(address(propertyManager),1000e18);

		// Investors and seller must approve the DSIP
		// token to charge them fees
		vm.startPrank(investor1);
		tokenFee.approve(address(tokenDSIP), 1e24);
		tokenPrimarySale.approve(address(tokenDSIP), 1e6*1e18);
		vm.stopPrank();

		vm.startPrank(investor2);
		tokenFee.approve(address(tokenDSIP), 1e24);
		tokenPrimarySale.approve(address(tokenDSIP), 1e6*1e18);
		vm.stopPrank();

		vm.startPrank(seller);
		tokenFee.approve(address(tokenDSIP), 100e22);
		tokenPrimarySale.approve(address(tokenDSIP), 1e6*1e18);
		vm.stopPrank();
	}


	function advanceBlocks(uint256 numBlocks) internal {
		uint256 targetBlock = block.number + numBlocks;
		vm.roll(targetBlock);
	}



	function testMint() public
	{

        uint256 tokenAmount = 10*1e21;

		identityManager.addToWhitelist(investor1);

		uint256 balanceSaleSeller0 = tokenPrimarySale.balanceOf(seller);
		uint256 balanceSaleInvestor0 = tokenPrimarySale.balanceOf(investor1);

		uint256 balanceFeeSeller0 = tokenFee.balanceOf(seller);
		uint256 balanceFeeInvestor0 = tokenFee.balanceOf(investor1);


        tokenDSIP.mintWithPayment(investor1, tokenAmount);

		assertEq(
				tokenPrimarySale.balanceOf(seller) - balanceSaleSeller0,
				tokenAmount * pricePrimaryMarket / 1e18,
				"Seller didn't increase their tokens correctly"
		);

		assertEq(
				balanceSaleInvestor0 - tokenPrimarySale.balanceOf(investor1),
				tokenAmount * pricePrimaryMarket / 1e18,
				"Seller didn't increase their tokens correctly"
		);

		assertEq(
				balanceFeeSeller0 - tokenFee.balanceOf(seller),
				tokenAmount * fee / 10000,
				"Seller didn't pay the correct fee"
		);

		assertEq(
				balanceFeeInvestor0 - tokenFee.balanceOf(investor1),
				tokenAmount * fee / 10000,
				"Investor didn't pay the correct fee"
		);
		
	}

		

	function testWhitelist() public
	{

		vm.expectRevert(abi.encodeWithSignature("DSIPNotWhitelisted(address)", investor1));
		tokenDSIP.mintWithPayment(investor1, 1e18);

		identityManager.addToWhitelist(investor1);
		tokenDSIP.mintWithPayment(investor1, 1e18);
		tokenDSIP.mintWithPayment(investor1, 1e18);

		assertEq(tokenDSIP.balanceOf(investor1), 2e18);

		identityManager.removeFromWhitelist(investor1);

		vm.expectRevert(abi.encodeWithSignature("DSIPNotWhitelisted(address)", investor1));
		tokenDSIP.mintWithPayment(investor1, 1e18);

		assertEq(tokenDSIP.balanceOf(investor1), 2e18);
	}

	

	function testExceedCap() public
	{

		identityManager.addToWhitelist(investor1);
		tokenDSIP.mintWithPayment(investor1, 99e21);

		assertEq(tokenDSIP.balanceOf(investor1), 99e21);

		vm.expectRevert(abi.encodeWithSignature("ERC20ExceededCap(uint256,uint256)", 101e21, CAP));
		tokenDSIP.mintWithPayment(investor1, 2e21);
	}


	function testSplitFee() public
	{

		vm.expectRevert(abi.encodeWithSignature("DSIPNotWhitelisted(address)", colister1));
		tokenDSIP.setFeeReceiverShares(1, colister1, 10);

		identityManager.addToWhitelist(colister1);
		identityManager.addToWhitelist(colister2);

		tokenDSIP.setFeeReceiverShares(1,colister1, 80);
		tokenDSIP.setFeeReceiverShares(2,colister1, 80);

		tokenDSIP.setFeeReceiverShares(1,colister2, 20);
		tokenDSIP.setFeeReceiverShares(2,colister2, 20);


		// We mint some tokens, doesn't matter to whom.
		// We're testing the fee distribution
		identityManager.addToWhitelist(investor1);
		tokenDSIP.mintWithPayment(investor1, 10000e18);
		assertEq(tokenFee.balanceOf(address(tokenDSIP)), 100e18, "Balance tokenDSIP is not 100e18");

		assertEq(tokenFee.balanceOf(colister1), 0, "Balance colister1 is not 0");
		assertEq(tokenFee.balanceOf(colister2), 0, "Balance colister2 is not 0");

		vm.expectRevert("Cannot redeem DSIP token");
		tokenDSIP.redeemFee(1,tokenDSIP, colister1);

		tokenDSIP.redeemFee(1,tokenFee, colister1);

		vm.expectRevert("You are not owed any payment");
		tokenDSIP.redeemFee(1,tokenFee, colister1);

		assertEq(tokenFee.balanceOf(colister1), 80e18, "Balance colister1 is not 80e18");
		assertEq(tokenFee.balanceOf(colister2), 0, "Balance colister2 is not 0");

		// We mint some tokens, doesn't matter to whom.
		// We're testing the fee distribution
		tokenDSIP.mintWithPayment(investor1, 10000e18);

		assertEq(tokenFee.balanceOf(address(tokenDSIP)), 120e18, "Balance tokenDSIP is not 120e18");

		tokenDSIP.redeemFee(1,tokenFee, address(colister2));

		assertEq(tokenFee.balanceOf(colister1), 80e18, "Balance colister1 is not 80e18");
		assertEq(tokenFee.balanceOf(colister2), 40e18, "Balance colister2 is not 40e18");

		tokenDSIP.redeemFee(1,tokenFee, colister1);

		assertEq(tokenFee.balanceOf(colister1), 160e18, "Balance colister1 is not 160e18");
		assertEq(tokenFee.balanceOf(colister2), 40e18, "Balance colister2 is not 40e18 (bis)");

	}


	function testSetNextPayment() public
	{
		vm.startPrank(propertyManager);
		tokenDividend.approve(address(tokenDSIP), 100e18);
		vm.stopPrank();

		vm.expectRevert("Not dividendPayer");
		tokenDSIP.setNextPayment(300, 100e18, tokenDividend);

		vm.startPrank(propertyManager);
		tokenDSIP.setNextPayment(300, 100e18, tokenDividend);
		vm.stopPrank();
	}


/*
	function testDividends() public
	{

		vm.roll(0);

		identityManager.addToWhitelist(investor1);
		identityManager.addToWhitelist(investor2);


		assertEq(tokenDividend.balanceOf(investor1), 0);
		assertEq(tokenDividend.balanceOf(investor2), 0);
		assertEq(tokenDividend.balanceOf(address(tokenDSIP)), 0);

		tokenDSIP.mintWithPayment(investor1, 50000e18);
		tokenDSIP.mintWithPayment(investor2, 0e18);
		advanceBlocks(50);

		tokenDSIP.mintWithPayment(investor1, 0e18);
		tokenDSIP.mintWithPayment(investor2, 50000e18);

		advanceBlocks(60);

		vm.startPrank(propertyManager);
		tokenDividend.approve(address(tokenDSIP), 100e18);
		tokenDSIP.setNextPayment(100, 100e18, tokenDividend);
		vm.stopPrank();

		tokenDSIP.redeemDividends(investor1, type(uint256).max);
		tokenDSIP.redeemDividends(investor2, type(uint256).max);

		assertEq(block.number, 110);
		assertEq(tokenDividend.balanceOf(investor1), 50e18);
		assertEq(tokenDividend.balanceOf(investor2), 25e18);


		advanceBlocks(100);


		vm.startPrank(propertyManager);
		tokenDividend.approve(address(tokenDSIP), 100e18);
		tokenDSIP.setNextPayment(200, 100e18, tokenDividend);
		vm.stopPrank();

		tokenDSIP.redeemDividends(investor1, type(uint256).max);
		tokenDSIP.redeemDividends(investor2, type(uint256).max);

		assertEq(block.number, 210);
		assertEq(tokenDividend.balanceOf(investor1), 100e18);
		assertEq(tokenDividend.balanceOf(investor2), 75e18);

	}
*/


	function testForceTransfer() public
	{
		identityManager.addToWhitelist(investor1);
		identityManager.addToWhitelist(address(this));
		tokenDSIP.mintWithPayment(investor1, 99e21);
		assertEq(tokenDSIP.balanceOf(investor1), 99e21);

		tokenDSIP.forceTransfer(investor1, address(this), 98e21);	
		assertEq(tokenDSIP.balanceOf(investor1), 1e21);
	}

	function testTrade() public
	{

		identityManager.addToWhitelist(investor1);
		identityManager.addToWhitelist(investor2);

		// Investor1 attemps to buy 1e21 tokens
		// from investor2 (for 2e21 of saleToken)
        tokenDSIP.mintWithPayment(investor2, 1e21);
		
		uint256 balance0SaleTokenInvestor1= tokenPrimarySale.balanceOf(investor1);
		uint256 balance0FeeTokenInvestor1 = tokenFee.balanceOf(investor1);
		uint256 balance0DSIPInvestor1 = tokenDSIP.balanceOf(investor1);

		uint256 balance0SaleTokenInvestor2 = tokenPrimarySale.balanceOf(investor2);
		uint256 balance0DSIPInvestor2 = tokenDSIP.balanceOf(investor2);
		uint256 balance0FeeTokenInvestor2 = tokenFee.balanceOf(investor2);


		assertEq(tokenDSIP.balanceOf(investor2), 1e21);


		vm.startPrank(investor1);
		// Check that fee and sale token are correctly approved
		tokenPrimarySale.approve(address(tokenDSIP), 0);
		tokenFee.approve(address(tokenDSIP), 2e21);
		vm.expectRevert("Insufficient sale token allowance");
		tokenDSIP.placeOrder(true, 1e21, 2e21, block.timestamp + 1 days); 

		tokenPrimarySale.approve(address(tokenDSIP), 2e21);
		tokenFee.approve(address(tokenDSIP), 0);
		vm.expectRevert("Insufficient fee token allowance");
		tokenDSIP.placeOrder(true, 1e21, 2e21, block.timestamp + 1 days); 

		tokenPrimarySale.approve(address(tokenDSIP), 2e21);
		tokenFee.approve(address(tokenDSIP), 2e21);
		tokenDSIP.placeOrder(true, 1e21, 2e21, block.timestamp + 1 days); 
		vm.stopPrank();


		vm.startPrank(investor2);
		tokenDSIP.approve(address(tokenDSIP), 1e21);
		tokenFee.approve(address(tokenDSIP), 2e21);
		tokenDSIP.placeOrder(false, 1e21, 1e21, block.timestamp + 1 days); 
		vm.stopPrank();

		// Up to here nothing should have changed
		assertEq(balance0SaleTokenInvestor1, tokenPrimarySale.balanceOf(investor1));
		assertEq(balance0SaleTokenInvestor2, tokenPrimarySale.balanceOf(investor2));

		assertEq(balance0FeeTokenInvestor1, tokenFee.balanceOf(investor1));
		assertEq(balance0FeeTokenInvestor2, tokenFee.balanceOf(investor2));

		assertEq(balance0DSIPInvestor1, tokenDSIP.balanceOf(investor1));
		assertEq(balance0DSIPInvestor2, tokenDSIP.balanceOf(investor2));

		tokenDSIP.matchOrders(2,1);

		assertEq(
				balance0SaleTokenInvestor1 - tokenPrimarySale.balanceOf(investor1),
				2e21,
				"Sale tokens didn't decrease as expected for Investor1"
		);
		assertEq(
				tokenPrimarySale.balanceOf(investor2) - balance0SaleTokenInvestor2 ,
				2e21,
				"Sale tokens didn't incresase as expected for Investor2"
		);

		assertEq(
				tokenDSIP.balanceOf(investor1) - balance0DSIPInvestor1 ,
				1e21,
				"DSIP tokens didn't incresase as expected for Investor1"
		);
		assertEq(
				balance0DSIPInvestor2 - tokenDSIP.balanceOf(investor2),
				1e21,
				"DSIP tokens didn't decrease as expected for Investor2"
		);

		// N.B.: If I use "fee" (instead of the local _fee), I get 
		// an Arithmetic over/underflow. Still haven't found the reason.
		uint256 _fee = fee;
		assertEq(
			balance0FeeTokenInvestor1 - tokenFee.balanceOf(investor1),
			2e21*_fee/10000,
			"Wrong fee taken from Investor1"
		);

		assertEq(
			balance0FeeTokenInvestor2 - tokenFee.balanceOf(investor2),
			2e21*_fee/10000,
			"Wrong fee taken from Investor2"
		);

		

	}

	function testLockedTokens() public
	{

		uint lockingTime = 86400*365;
		tokenDSIP.setLockingTimeSeconds(lockingTime);

		identityManager.addToWhitelist(investor1);
		identityManager.addToWhitelist(investor2);
		tokenDSIP.mintWithPayment(investor1, 2e21);


		vm.startPrank(investor1);
		tokenPrimarySale.approve(address(tokenDSIP), 2e21);
		tokenFee.approve(address(tokenDSIP), 2e21);
		vm.expectRevert("Tokens are locked");
		// The check for locked tokens only happend in SELL orders
		tokenDSIP.placeOrder(false, 1e21, 2e21, block.timestamp + 1 days); 
		vm.stopPrank();

		vm.warp(block.timestamp + lockingTime + 1);

		vm.startPrank(investor1);
		tokenDSIP.placeOrder(false, 1e21, 2e21, block.timestamp + 1 days); 
		vm.stopPrank();
	}


	function testPauseUnpause() public
	{
		identityManager.addToWhitelist(investor1);
		identityManager.addToWhitelist(investor2);
		tokenDSIP.mintWithPayment(investor1, 2e21);

		tokenDSIP.pause();

		vm.startPrank(investor1);
		tokenPrimarySale.approve(address(tokenDSIP), 2e21);
		tokenFee.approve(address(tokenDSIP), 2e21);
		vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
		tokenDSIP.placeOrder(false, 1e21, 2e21, block.timestamp + 1 days); 
		vm.stopPrank();

		tokenDSIP.unpause();

		vm.startPrank(investor1);
		tokenDSIP.placeOrder(false, 1e21, 2e21, block.timestamp + 1 days); 
		vm.stopPrank();
	}

	function testNonOwnerMint() public
	{
		identityManager.addToWhitelist(investor1);
		vm.startPrank(investor2);
		vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", investor2));
		tokenDSIP.mintWithPayment(investor1, 10e18);
		vm.stopPrank();
	}


	function testNonOwnerPause() public
	{
		identityManager.addToWhitelist(investor1);
		identityManager.addToWhitelist(investor2);
		tokenDSIP.mintWithPayment(investor1, 2e21);

		vm.startPrank(investor1);
		vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", investor1));
		tokenDSIP.pause();
		vm.stopPrank();

		tokenDSIP.pause();

		vm.startPrank(investor1);
		vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", investor1));
		tokenDSIP.unpause();
		vm.stopPrank();

		tokenDSIP.unpause();

	}

	function testReplaceFeeToken() public
	{

		MyToken tokenFee2 = new MyToken("Fee Token2", "FTK2");
		tokenFee2.mint(seller, 1e24);
		tokenFee2.mint(investor1, 1e24);
	
		vm.startPrank(seller);
		tokenFee2.approve(address(tokenDSIP), 1e24);
		tokenPrimarySale.approve(address(tokenDSIP), 100e22);
		vm.stopPrank();

		vm.startPrank(investor1);
		tokenFee2.approve(address(tokenDSIP), 1e24);
		vm.stopPrank();
	

		identityManager.addToWhitelist(investor1);
		identityManager.addToWhitelist(colister1);
		identityManager.addToWhitelist(colister2);

		tokenDSIP.setFeeReceiverShares(1,colister1, 80);
		tokenDSIP.setFeeReceiverShares(2,colister1, 80);

		tokenDSIP.setFeeReceiverShares(1,colister2, 20);
		tokenDSIP.setFeeReceiverShares(2,colister2, 20);

		// Let's make sure seller has enough tokens
		// to mint twice
		tokenPrimarySale.mint(seller, 1e24);

		// We mint some tokens, doesn't matter to whom.
		// We're testing the fee distribution
		tokenDSIP.mintWithPayment(investor1, 10000e18);

		assertEq(tokenFee.balanceOf(address(tokenDSIP)), 100e18, "Balance tokenDSIP is not 100e18");
		assertEq(tokenFee.balanceOf(colister1), 0, "Balance colister1 is not 0");
		assertEq(tokenFee.balanceOf(colister2), 0, "Balance colister2 is not 0");

		assertEq(tokenFee2.balanceOf(address(tokenDSIP)), 0, "Balance tokenDSIP is not 0");
		assertEq(tokenFee2.balanceOf(colister1), 0, "Balance colister1 is not 0");
		assertEq(tokenFee2.balanceOf(colister2), 0, "Balance colister2 is not 0");



		// Now we change the fee token
		tokenDSIP.setFeeToken(tokenFee2);


		// We mint some tokens, doesn't matter to whom.
		// We're testing the fee distribution
		tokenDSIP.mintWithPayment(investor1, 10000e18);



		tokenDSIP.redeemFee(1,tokenFee, colister1);
		tokenDSIP.redeemFee(1,tokenFee, colister2);
		tokenDSIP.redeemFee(1,tokenFee2, colister1);
		tokenDSIP.redeemFee(1,tokenFee2, colister2);

		assertEq(tokenFee.balanceOf(colister1), 80e18, "Wrong fee received");
		assertEq(tokenFee.balanceOf(colister2), 20e18, "Wrong fee received");
		assertEq(tokenFee2.balanceOf(colister1), 80e18, "Wrong fee received");
		assertEq(tokenFee2.balanceOf(colister2), 20e18, "Wrong fee received");

	}


}

