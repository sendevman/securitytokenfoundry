// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "src/interfaces/IDSIP.sol";
import "src/interfaces/IIdentityManager.sol";

import "src/DSIP.sol";
import "src/IdentityManager.sol";

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

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


contract EndToEnd is Test {
	
	IIdentityManager identityManager;

	IDSIP tokenDSIP1;
	IDSIP tokenDSIP2;

	MyToken USDT;

	address investor1 = vm.addr(10);
	address investor2 = vm.addr(11);
	address investor3 = vm.addr(12);
	address investor4 = vm.addr(13);

	address colister1 = vm.addr(20);
	address colister2 = vm.addr(21);
	address colister3 = vm.addr(22);

	address seller1 = vm.addr(30);
	address seller2 = vm.addr(31);

	address propertyManager = vm.addr(41);

	uint256 pricePrimaryMarket1 = 1e18;
	uint256 pricePrimaryMarket2 = 1e18;

	uint256 CAP = 100e21;
	uint256 lockingTime = 365*86400;

	uint16 fee1 = 50;
	uint16 fee2 = 100;


    function setUp() public {

		identityManager = new IdentityManager(
					address(this)
		);

		USDT = new MyToken("StableCoin", "USDT");
		
		tokenDSIP1 = new DSIP(
				"Property 1",
				"DSIP#00001",
				CAP,
				address(this)
		);

        tokenDSIP1.setIdentityManager(identityManager);
        tokenDSIP1.setInitialSeller(seller1);
        tokenDSIP1.setDividendPayer(propertyManager);
        tokenDSIP1.setFeeToken(USDT);
        tokenDSIP1.setSaleToken(USDT);
        tokenDSIP1.setPricePrimaryMarket(pricePrimaryMarket1);
        tokenDSIP1.setLockingTimeSeconds(0);
        tokenDSIP1.setFeeStructure(fee1, fee1, fee1, fee1, 0, 0);


		tokenDSIP2 = new DSIP(
				"Property 2",
				"DSIP#00002",
				CAP,
				address(this)
		);

        tokenDSIP2.setIdentityManager(identityManager);
        tokenDSIP2.setInitialSeller(seller2);
        tokenDSIP2.setDividendPayer(propertyManager);
        tokenDSIP2.setFeeToken(USDT);
        tokenDSIP2.setSaleToken(USDT);
        tokenDSIP2.setPricePrimaryMarket(pricePrimaryMarket2);
        tokenDSIP2.setLockingTimeSeconds(0);
        tokenDSIP2.setFeeStructure(fee2, fee2, fee2, fee2, 0, 0);

		// Distribute initial funds and approvals
		address[] memory _users = new address[](8);
		_users[0] = investor1;
		_users[1] = investor2;
		_users[2] = investor3;
		_users[3] = investor4;
		_users[4] = colister1;
		_users[5] = colister2;
		_users[6] = seller1;
		_users[7] = seller2;

		for (uint i = 0; i < _users.length; i++) 
		{
		
			// Distribute some funds (to purchase property
			// and/or pay fees)
			USDT.mint(_users[i], 1e6*1e18);

			// Add to whitelist
			identityManager.addToWhitelist(_users[i]);

			vm.startPrank(_users[i]);
			USDT.approve(address(tokenDSIP1), 1e6*1e18);
			USDT.approve(address(tokenDSIP2), 1e6*1e18);
			vm.stopPrank();

		}


	}


	function advanceBlocks(uint256 numBlocks) internal {
		uint256 targetBlock = block.number + numBlocks;
		vm.roll(targetBlock);
	}



	function testFull() public
	{

		uint tokenAmount = 10*1e21;

		uint256 balance0USDTinvestor1 = USDT.balanceOf(investor1);
		uint256 balance0USDTseller1 = USDT.balanceOf(seller1);

		tokenDSIP1.mintWithPayment(investor1, tokenAmount);

		assertEq(
				balance0USDTinvestor1 - USDT.balanceOf(investor1),
				tokenAmount * pricePrimaryMarket1 / 1e18 + tokenAmount * fee1 / 10000
		);

		assertEq(
				USDT.balanceOf(seller1) - balance0USDTseller1,
				tokenAmount * pricePrimaryMarket1 / 1e18 - tokenAmount * fee1 / 10000
		);

		tokenDSIP1.mintWithPayment(investor2, 5*1e21);
		tokenDSIP1.mintWithPayment(investor2, 2*1e21);
		tokenDSIP1.mintWithPayment(investor2, 1*1e21);

		tokenDSIP2.mintWithPayment(investor1, 1*1e21);
		tokenDSIP2.mintWithPayment(investor2, 2*1e21);
		tokenDSIP2.mintWithPayment(investor2, 5*1e21);
		tokenDSIP2.mintWithPayment(investor2, 10*1e21);

		// TO DO

	}

	
}

