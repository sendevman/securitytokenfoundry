// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import "../../src/DSIP.sol";
import "../../src/OrderBook.sol";
import "../../src/IdentityManager.sol";
import "../../src/interfaces/IDSIP.sol";
import "../../src/interfaces/IOrderBook.sol";
import "../../src/interfaces/IIdentityManager.sol";
import "../util/SaleToken.sol";
import "../util/FeeToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract DSIPTest is Test {
    DSIP public dsip;
    IdentityManager public identityManager;
    IdentityManager public partnerManager;
    OrderBook public orderBook;
    SaleToken public saleToken;
    SaleToken public feeToken;

    address public owner = address(this);
    address public trader1 = address(0x1);
    address public trader2 = address(0x2);
    address public seller = address(0x3);

    uint256 public SECURITY_TOKEN_AMOUNT = 1000;
    uint256 public SALE_TOKEN_AMOUNT = 1000;
    uint256 public capAmount = 1000000000000 * 10 ** 18;

    function setUp() public {
        dsip = new DSIP("DSIP", "DSIP", capAmount, owner);
        identityManager = new IdentityManager(owner);
        partnerManager = new IdentityManager(owner);
        saleToken = new SaleToken(1000000000000000 * 10 ** 18);
        feeToken = saleToken;
        dsip.setSaleToken(saleToken);
        dsip.setFeeToken(feeToken);
        dsip.setIdentityManager(identityManager);
        dsip.setPartnerManager(partnerManager);
        dsip.setInitialSeller(address(this));
        orderBook = new OrderBook(address(dsip));
        dsip.setOrderBook(orderBook);
    }

    function testPauses() public {
        vm.startPrank(trader1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                trader1
            )
        );
        dsip.pause();
        vm.stopPrank();
        dsip.pause();
        bool isPaused = dsip.paused();
        assertEq(isPaused, true);
    }

    function testunpauses() public {
        dsip.pause();
        bool isPaused = dsip.paused();
        assertEq(isPaused, true);

        vm.startPrank(trader1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                trader1
            )
        );
        dsip.unpause();
        vm.stopPrank();
        dsip.unpause();
        bool unausedStatus = dsip.paused();
        assertEq(unausedStatus, false);
    }

    function testgetCap() public {
        uint256 cap = dsip.getCap();
        assertEq(cap, capAmount);
    }

    function testgetOrderBook() public {
        dsip.setOrderBook(orderBook);
        IOrderBook book = dsip.getOrderBook();
        assertEq(address(orderBook), address(book));
    }

    function testRevertIfNotOwnerCallingMintWithoutPayment() public {
        dsip.transferOwnership(trader2);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(this)
            )
        );
        dsip.mintWithoutPayment(trader1, SECURITY_TOKEN_AMOUNT);
    }

    function testIfCanMintWithoutPayment() public {
        identityManager.addToWhitelist(trader1);
        dsip.mintWithoutPayment(trader1, SECURITY_TOKEN_AMOUNT);
        uint256 balance = dsip.balanceOf(trader1);
        assertEq(balance, SECURITY_TOKEN_AMOUNT);
    }

    function testRevertIfToIsNotWLInMintWithoutPayment() public {
        vm.expectRevert(
            abi.encodeWithSelector(IDSIP.DSIPNotWhitelisted.selector, trader1)
        );
        dsip.mintWithoutPayment(trader1, SECURITY_TOKEN_AMOUNT);
    }

    function testMintWithPayment() public {
        dsip.setPricePrimaryMarket(1 ether);
        dsip.setFeeToken(feeToken);
        dsip.setSaleToken(saleToken);
        saleToken.approve(address(dsip), SECURITY_TOKEN_AMOUNT * 10e18);
        feeToken.approve(address(dsip), SECURITY_TOKEN_AMOUNT * 10e18);
        identityManager.addToWhitelist(address(this));
        dsip.mintWithPayment(address(this), SECURITY_TOKEN_AMOUNT);
        uint256 balance = dsip.balanceOf(address(this));
        assertEq(balance, SECURITY_TOKEN_AMOUNT);
    }

    function testOnlyOwnerCanCallsetIdentityManager() public {
        dsip.transferOwnership(trader1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(this)
            )
        );
        dsip.setIdentityManager(identityManager);
    }

    function testsetIdentityManager() public {
        dsip.setIdentityManager(IIdentityManager(trader1));
    }

    function testOOCsetInitialSeller() public {
        dsip.transferOwnership(trader1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(this)
            )
        );
        dsip.setInitialSeller(trader2);
    }

    function testsetInitialSeller() public {
        vm.expectRevert("Seller cannot be the zero address");
        dsip.setInitialSeller(address(0));
        dsip.setInitialSeller(trader1);
        address _seller = dsip.seller();
        assertEq(_seller, trader1);
    }

    function testOOCsetDividendPayer() public {
        dsip.transferOwnership(trader1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(this)
            )
        );
        dsip.setDividendPayer(trader2);
    }

    function testsetDividendPayer() public {
        vm.expectRevert("Dividend Payer cannot be the zero address");
        dsip.setDividendPayer(address(0));
        dsip.setDividendPayer(trader1);
        address payer = dsip.dividendPayer();
        assertEq(payer, trader1);
    }

    function testOOCsetOrderBook() public {
        dsip.transferOwnership(trader1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(this)
            )
        );
        dsip.setOrderBook(IOrderBook(trader2));
    }

    function testsetOrderBook() public {
        dsip.setOrderBook(IOrderBook(trader1));
        IOrderBook book = dsip.getOrderBook();
        assertEq(address(book), trader1);
    }

    function testsetFeeToken() public {
        dsip.setFeeToken(IERC20(trader1));
    }

    function testsetFeeStructure() public {
        dsip.setFeeStructure(
            1 * 10e2,
            1 * 10e2,
            1 * 10e2,
            1 * 10e2,
            1 * 10e2,
            0
        );
    }

    function testsetFeeReceiverShares() public {
        vm.expectRevert(
            abi.encodeWithSelector(IDSIP.DSIPNotWhitelisted.selector, trader1)
        );
        dsip.setFeeReceiverShares(1, trader1, 1 ether);
        identityManager.addToWhitelist(trader1);
        dsip.setFeeReceiverShares(1, trader1, 1 ether);
        dsip.setFeeReceiverShares(2, trader1, 1 ether);
    }

    function testredeemFee() public {
        dsip.setPricePrimaryMarket(1 ether);
        dsip.setFeeStructure(100, 100, 100, 100, 100, 0);
        dsip.setFeeToken(feeToken);
        dsip.setSaleToken(saleToken);
        saleToken.approve(address(dsip), SECURITY_TOKEN_AMOUNT * 10e18);
        feeToken.approve(address(dsip), SECURITY_TOKEN_AMOUNT * 10e18);
        identityManager.addToWhitelist(address(this));
        dsip.mintWithPayment(address(this), SECURITY_TOKEN_AMOUNT);
        identityManager.addToWhitelist(trader1);
        dsip.setFeeReceiverShares(1, trader1, 1 ether);
        dsip.setFeeReceiverShares(2, trader1, 1 ether);
        identityManager.removeFromWhitelist(trader1);
        vm.expectRevert(
            abi.encodeWithSelector(IDSIP.DSIPNotWhitelisted.selector, trader1)
        );
        dsip.redeemFee(1, feeToken, trader1);

        identityManager.addToWhitelist(trader1);

        dsip.redeemFee(1, feeToken, trader1);
    }

    function testsetSaleToken() public {
        IOrderBook bookP = dsip.getOrderBook();
        dsip.setSaleToken(IERC20(trader1));
        IOrderBook bookA = dsip.getOrderBook();
        assertFalse(bookP == bookA);
    }

    function testsetPricePrimaryMarket() public {
        vm.expectRevert("Price cannot exceed uint128");
        dsip.setPricePrimaryMarket(10000 * 10e18 ether);
        dsip.setPricePrimaryMarket(1 ether);
    }

    function testsetLockingTimeSeconds() public {
        dsip.setLockingTimeSeconds(1 ether);
    }

    function testsetNextPayment() public {
        dsip.setSaleToken(saleToken);
        saleToken.approve(address(dsip), SECURITY_TOKEN_AMOUNT * 10e18);
        vm.expectRevert("Not dividendPayer");
        dsip.setNextPayment(block.timestamp, 100, saleToken);
        dsip.setDividendPayer(address(this));
        dsip.setNextPayment(block.timestamp, 100, saleToken);
        vm.expectRevert("Block number must be larger than last one");
        dsip.setNextPayment(block.timestamp, 100, saleToken);
    }

    function testredeemDividends() public {
        dsip.setSaleToken(saleToken);
        saleToken.approve(address(dsip), SECURITY_TOKEN_AMOUNT * 10e18);
        identityManager.addToWhitelist(address(this));
        dsip.setDividendPayer(address(this));
        dsip.setNextPayment(block.timestamp, 100, saleToken);
        vm.expectRevert("Never owned this token");
        dsip.redeemDividends(address(this), 4);
        dsip.mintWithoutPayment(address(this), SECURITY_TOKEN_AMOUNT);
        dsip.redeemDividends(address(this), 4);
    }

    function testgetLastPaymentToAddressIndex() public {
        uint256 index = 1;
        uint256 prevIndex = dsip.getLastPaymentToAddressIndex(address(this));
        dsip.setSaleToken(saleToken);
        saleToken.approve(address(dsip), SECURITY_TOKEN_AMOUNT * 10e18);
        identityManager.addToWhitelist(address(this));
        dsip.setDividendPayer(address(this));
        dsip.setNextPayment(block.timestamp, 100, saleToken);
        dsip.mintWithoutPayment(address(this), SECURITY_TOKEN_AMOUNT);
        dsip.redeemDividends(address(this), index);
        uint256 currentIndex = dsip.getLastPaymentToAddressIndex(address(this));
        assertEq(currentIndex, prevIndex + index);
    }

    function testgetLastPaymentTermIndex() public {
        uint256 currentIndex = dsip.getLastPaymentTermIndex();
        dsip.setSaleToken(saleToken);
        saleToken.approve(address(dsip), SECURITY_TOKEN_AMOUNT * 10e18);
        dsip.setDividendPayer(address(this));
        dsip.setNextPayment(block.timestamp, 100, saleToken);
        uint256 updatedIndex = dsip.getLastPaymentTermIndex();
        assertEq(updatedIndex, currentIndex + 1);
    }

    function testApprove() public {
        uint256 currentAllownace = dsip.allowance(address(this), trader1);
        uint256 amountToApprove = 10e18;
        vm.expectRevert(
            abi.encodeWithSelector(IDSIP.DSIPNotWhitelisted.selector, trader1)
        );
        dsip.approve(trader1, amountToApprove);
        identityManager.addToWhitelist(trader1);
        dsip.approve(trader1, amountToApprove);
        uint256 updatedAllownace = dsip.allowance(address(this), trader1);
        assertEq(amountToApprove, updatedAllownace);
    }

    function testCanTransfer() public {
        identityManager.addToWhitelist(trader1);
        identityManager.addToWhitelist(trader2);

        uint256 balance0 = dsip.balanceOf(trader1);
        dsip.mintWithoutPayment(trader1, 20e18);
        uint256 balance1 = dsip.balanceOf(trader1);

        vm.startPrank(trader1);
        vm.expectRevert(
            abi.encodeWithSignature("DSIPDirectTransfersNotAllowed()")
        );
        dsip.transfer(trader2, 10e18);
		vm.stopPrank();
        uint256 balance2 = dsip.balanceOf(trader1);

        partnerManager.addToWhitelist(trader2);

        vm.startPrank(trader1);
        dsip.transfer(trader2, 10e18);
		vm.stopPrank();

        uint256 balance3 = dsip.balanceOf(trader1);

        vm.startPrank(trader2);
        dsip.transfer(trader1, 10e18);
		vm.stopPrank();

        uint256 balance4 = dsip.balanceOf(trader1);

        assertEq(balance1-balance0, 20e18, "Failed initial mint");
        assertEq(balance2-balance1, 0, "Failed unapproved transfer");
        assertEq(balance2-balance3, 10e18, "Failed approved transfer");
        assertEq(balance4-balance3, 10e18, "Failed approved refund ");
    }

    function testCannotTransfer() public {
        identityManager.addToWhitelist(address(this));
        identityManager.addToWhitelist(trader1);
        vm.expectRevert(
            abi.encodeWithSignature("DSIPDirectTransfersNotAllowed()")
        );
        dsip.transfer(trader1, 10e18);
    }

    function testCannotTransferFrom() public {
        identityManager.addToWhitelist(address(this));
        identityManager.addToWhitelist(trader1);
        dsip.approve(address(dsip), 10e18);
        vm.expectRevert(
            abi.encodeWithSignature("DSIPDirectTransfersNotAllowed()")
        );
        dsip.transferFrom(address(this), trader1, 10e18);
    }

    function testforceTransfer() public {
        identityManager.addToWhitelist(address(this));
        dsip.mintWithoutPayment(address(this), SECURITY_TOKEN_AMOUNT);
        vm.expectRevert(
            abi.encodeWithSelector(IDSIP.DSIPNotWhitelisted.selector, trader1)
        );
        dsip.forceTransfer(address(this), trader1, SECURITY_TOKEN_AMOUNT);
        identityManager.addToWhitelist(trader1);
        dsip.forceTransfer(address(this), trader1, SECURITY_TOKEN_AMOUNT);
        uint256 trader1Balance = dsip.balanceOf(trader1);
        assertEq(SECURITY_TOKEN_AMOUNT, trader1Balance);
    }

    function testRevertPlaceOrderWhenPaused() public {
        identityManager.addToWhitelist(address(this));
        dsip.pause();
        vm.expectRevert(
            abi.encodeWithSelector(Pausable.EnforcedPause.selector)
        );
        dsip.placeOrder(true, 1000, 1000, block.timestamp + 10);
    }

    function testRevertIFInsufficientsaletokenallowanceOnPlaceOrder() public {
        FeeToken feet = new FeeToken(1000000000000000 * 10 ** 18);
        identityManager.addToWhitelist(address(this));
        dsip.setFeeToken(feet);
        dsip.setSaleToken(saleToken);
        uint16 allFee = 10000;
        uint256 maxFee = 10000;
        dsip.setFeeStructure(allFee, allFee, allFee, allFee, allFee, 0);
        uint256 securityTokenAmount = 1000;
        uint256 saleTokenAmount = 1000;
        vm.expectRevert("Insufficient sale token allowance");
        dsip.placeOrder(
            true,
            securityTokenAmount,
            saleTokenAmount,
            block.timestamp + 10
        );
        saleTokenAmount = 1000000000000000 * 10 ** 18;
        saleToken.approve(address(dsip), saleTokenAmount * 2);
        vm.expectRevert("Insufficient sale token balance");
        dsip.placeOrder(
            true,
            securityTokenAmount,
            saleTokenAmount * 2,
            block.timestamp + 10
        );
        vm.expectRevert("Insufficient fee token allowance");
        dsip.placeOrder(
            true,
            securityTokenAmount,
            saleTokenAmount,
            block.timestamp + 10
        );
        feet.transfer(trader1, feet.balanceOf(address(this)));
        // saleTokenAmount = 1000;
        feet.approve(address(dsip), saleTokenAmount);
        console.log(saleToken.balanceOf(address(this)));
        vm.expectRevert("Insufficient fee token balance");
        dsip.placeOrder(
            true,
            securityTokenAmount,
            saleTokenAmount,
            block.timestamp + 10
        );
        vm.startPrank(trader1);
        feet.transfer(address(this), feet.balanceOf(trader1));
        vm.stopPrank();
        saleTokenAmount = 1000;
        vm.expectRevert("Insufficient security token");
        dsip.placeOrder(
            false,
            securityTokenAmount,
            saleTokenAmount,
            block.timestamp + 10
        );
        feet.approve(address(dsip), 0);
        identityManager.addToWhitelist(address(this));
        securityTokenAmount = 100000000000000000000000;
        feet.transfer(trader1, feeToken.balanceOf(address(this)) - 10);
        dsip.mintWithoutPayment(address(this), securityTokenAmount);
        vm.expectRevert("Insufficient fee token allowance");
        dsip.placeOrder(
            false,
            securityTokenAmount,
            saleTokenAmount,
            block.timestamp + 10
        );
        feet.approve(address(dsip), securityTokenAmount);
        vm.expectRevert("Insufficient fee token balance");
        dsip.placeOrder(
            false,
            securityTokenAmount,
            saleTokenAmount,
            block.timestamp + 10
        );
    }

    function testPlaceOrderDSIP() public {
        dsip.setFeeToken(feeToken);
        dsip.setSaleToken(saleToken);
        uint16 allFee = 10000;
        dsip.setFeeStructure(allFee, allFee, allFee, allFee, allFee, 0);
        identityManager.addToWhitelist(address(this));
        dsip.mintWithoutPayment(address(this), SECURITY_TOKEN_AMOUNT);
        saleToken.approve(address(dsip), SECURITY_TOKEN_AMOUNT);
        feeToken.approve(address(dsip), SECURITY_TOKEN_AMOUNT);
        uint256 orderId = dsip.placeOrder(
            true,
            SECURITY_TOKEN_AMOUNT,
            SALE_TOKEN_AMOUNT,
            block.timestamp + 3600
        );
        IOrderBook book = (dsip.getOrderBook());
        IOrderBook.Order memory order = book.getOrder(orderId);
        // return; // Place order is working but orders variable as well as nextOrderId is not updating accordingly
        assertEq(order.trader, address(this));
        assertTrue(order.isBuyOrder);
        assertEq(order.amountSecurityToken, SECURITY_TOKEN_AMOUNT);
        assertEq(order.amountSaleToken, SALE_TOKEN_AMOUNT);
    }

    function testMatchOrders() public {
        dsip.setFeeToken(feeToken);
        dsip.setSaleToken(saleToken);
        uint16 allFee = 10000;
        uint256 maxFee = 10000;
        dsip.setFeeStructure(allFee, allFee, allFee, allFee, allFee, 0);
        saleToken.approve(address(dsip), SALE_TOKEN_AMOUNT);
        feeToken.approve(address(dsip), SECURITY_TOKEN_AMOUNT * 1000);
        dsip.approve(address(dsip), SECURITY_TOKEN_AMOUNT);
        identityManager.addToWhitelist(address(this));
        dsip.mintWithoutPayment(address(this), SECURITY_TOKEN_AMOUNT);
        dsip.mintWithoutPayment(address(this), SECURITY_TOKEN_AMOUNT);

        uint256 order1Id = dsip.placeOrder(
            true,
            SECURITY_TOKEN_AMOUNT,
            SALE_TOKEN_AMOUNT,
            block.timestamp + 3600
        );
        uint256 order2Id = dsip.placeOrder(
            false,
            SALE_TOKEN_AMOUNT,
            SECURITY_TOKEN_AMOUNT,
            block.timestamp + 3600
        );

        dsip.matchOrders(order1Id, order2Id);

        uint256 trader1BalanceAfterTrade = dsip.balanceOf(address(this));

        assertEq(
            trader1BalanceAfterTrade,
            SECURITY_TOKEN_AMOUNT + SALE_TOKEN_AMOUNT
        );
		
    }

    function testMatchOrdersBatch() public {
        dsip.setFeeToken(feeToken);
        dsip.setSaleToken(saleToken);
        uint16 allFee = 10000;
        uint256 maxFee = 10000;
        dsip.setFeeStructure(allFee, allFee, allFee, allFee, allFee, 0);
        saleToken.approve(address(dsip), SALE_TOKEN_AMOUNT + SALE_TOKEN_AMOUNT);
        feeToken.approve(
            address(dsip),
            SECURITY_TOKEN_AMOUNT * SECURITY_TOKEN_AMOUNT
        );
        dsip.approve(
            address(dsip),
            SECURITY_TOKEN_AMOUNT + SECURITY_TOKEN_AMOUNT
        );
        identityManager.addToWhitelist(address(this));
        dsip.mintWithoutPayment(address(this), SECURITY_TOKEN_AMOUNT);
        dsip.mintWithoutPayment(address(this), SECURITY_TOKEN_AMOUNT);
        dsip.mintWithoutPayment(address(this), SECURITY_TOKEN_AMOUNT);
        dsip.mintWithoutPayment(address(this), SECURITY_TOKEN_AMOUNT);

        uint256 order1Id = dsip.placeOrder(
            true,
            SECURITY_TOKEN_AMOUNT,
            SALE_TOKEN_AMOUNT,
            block.timestamp + 3600
        );
        uint256 order2Id = dsip.placeOrder(
            false,
            SALE_TOKEN_AMOUNT,
            SECURITY_TOKEN_AMOUNT,
            block.timestamp + 3600
        );
        uint256 order3Id = dsip.placeOrder(
            true,
            SECURITY_TOKEN_AMOUNT,
            SALE_TOKEN_AMOUNT/100,
            block.timestamp + 3600
        );
        uint256 order4Id = dsip.placeOrder(
            false,
            SALE_TOKEN_AMOUNT/100,
            SECURITY_TOKEN_AMOUNT,
            block.timestamp + 3600
        );
        uint256 order5Id = dsip.placeOrder(
            true,
            SECURITY_TOKEN_AMOUNT,
            SALE_TOKEN_AMOUNT,
            block.timestamp + 3600
        );
        uint256 order6Id = dsip.placeOrder(
            false,
            SALE_TOKEN_AMOUNT,
            SECURITY_TOKEN_AMOUNT,
            block.timestamp + 3600
        );
        uint256[][2] memory orders;
        orders[0] = new uint256[](2);
        orders[1] = new uint256[](2);

        orders[0][0] = 1;
        orders[0][1] = 2;

        orders[1][0] = 3;
        orders[1][1] = 4;
        vm.expectRevert("Price deviation from weighted average too high");
        dsip.matchOrdersBatch(orders);

        orders[1][0] = 5;
        orders[1][1] = 6;
        dsip.matchOrdersBatch(orders);


        uint256 trader1BalanceAfterTrade = dsip.balanceOf(address(this));
        assertEq(
            trader1BalanceAfterTrade,
            (SECURITY_TOKEN_AMOUNT + SALE_TOKEN_AMOUNT) * 2
        );
    }

    function testplaceAndMatchOrder() public {
        dsip.setFeeToken(feeToken);
        dsip.setSaleToken(saleToken);
        uint16 allFee = 10000;
        uint256 maxFee = 10000;
        dsip.setFeeStructure(allFee, allFee, allFee, allFee, allFee, 0);
        saleToken.approve(address(dsip), SALE_TOKEN_AMOUNT);
        feeToken.approve(address(dsip), SECURITY_TOKEN_AMOUNT * 1000);
        dsip.approve(address(dsip), SECURITY_TOKEN_AMOUNT);
        identityManager.addToWhitelist(address(this));
        dsip.mintWithoutPayment(address(this), SECURITY_TOKEN_AMOUNT);
        dsip.mintWithoutPayment(address(this), SECURITY_TOKEN_AMOUNT);

        uint256 order1Id = dsip.placeOrder(
            true,
            SECURITY_TOKEN_AMOUNT,
            SALE_TOKEN_AMOUNT,
            block.timestamp + 3600
        );
        dsip.placeAndMatchOrder(
            false,
            SECURITY_TOKEN_AMOUNT,
            SALE_TOKEN_AMOUNT,
            1
        );

        // dsip.matchOrders(order1Id, order2Id);

        uint256 trader1BalanceAfterTrade = dsip.balanceOf(address(this));

        assertEq(
            trader1BalanceAfterTrade,
            SECURITY_TOKEN_AMOUNT + SALE_TOKEN_AMOUNT
        );
    }

    function testFeeTakenandDistributedWhenMintingTokens() public {
        dsip.setPricePrimaryMarket(1 ether);
        dsip.setFeeStructure(100, 100, 100, 100, 100, 0);
        FeeToken feet = new FeeToken(1000000000000000 * 10 ** 18);
        dsip.setFeeToken(feet);
        dsip.setSaleToken(saleToken);
        dsip.setInitialSeller(seller);
        saleToken.approve(address(dsip), SECURITY_TOKEN_AMOUNT * 10e18);
        feet.approve(address(dsip), SECURITY_TOKEN_AMOUNT * 10e18);
        feet.transfer(seller, SECURITY_TOKEN_AMOUNT * 10e18);
        vm.startPrank(seller);
        feet.approve(address(dsip), SECURITY_TOKEN_AMOUNT * 10e18);
        vm.stopPrank();
        identityManager.addToWhitelist(address(this));
        dsip.mintWithPayment(address(this), SECURITY_TOKEN_AMOUNT);
        uint256 primaryMarketFeeToSeller = (SECURITY_TOKEN_AMOUNT * 1 ether) /
            1e18;
        uint256 takeFeeFromBuyer = (SECURITY_TOKEN_AMOUNT * 100) / 10000;
        uint256 takeFeeFromSeller = (SECURITY_TOKEN_AMOUNT * 100) / 10000;

        assertEq(primaryMarketFeeToSeller, saleToken.balanceOf(seller));
        assertEq(
            takeFeeFromBuyer + takeFeeFromSeller,
            feet.balanceOf(address(dsip))
        );
    }

    function testFeeTakenandDistributedWhenMatchingOrders() public {
        FeeToken feet = new FeeToken(1000000000000000 * 10 ** 18);
        dsip.setFeeToken(feet);
        dsip.setSaleToken(saleToken);
        uint16 allFee = 10000;
        uint256 maxFee = 10000;
        dsip.setFeeStructure(allFee, allFee, allFee, allFee, allFee, 0);

        dsip.approve(address(dsip), SECURITY_TOKEN_AMOUNT);
        identityManager.addToWhitelist(trader1);
        identityManager.addToWhitelist(trader2);
        saleToken.transfer(trader1, SALE_TOKEN_AMOUNT);
        feet.transfer(trader1, SECURITY_TOKEN_AMOUNT);
        saleToken.transfer(trader2, SALE_TOKEN_AMOUNT);
        feet.transfer(trader2, SECURITY_TOKEN_AMOUNT);
        dsip.mintWithoutPayment(trader1, SECURITY_TOKEN_AMOUNT);
        dsip.mintWithoutPayment(trader2, SECURITY_TOKEN_AMOUNT);
        vm.startPrank(seller);
        feet.approve(address(dsip), SECURITY_TOKEN_AMOUNT);
        vm.stopPrank();
        vm.startPrank(trader1);
        saleToken.approve(address(dsip), SALE_TOKEN_AMOUNT);
        feet.approve(address(dsip), SECURITY_TOKEN_AMOUNT);
        uint256 order1Id = dsip.placeOrder(
            true,
            SECURITY_TOKEN_AMOUNT,
            SALE_TOKEN_AMOUNT,
            block.timestamp + 3600
        );
        vm.stopPrank();
        vm.startPrank(trader2);
        saleToken.approve(address(dsip), SALE_TOKEN_AMOUNT);
        feet.approve(address(dsip), SECURITY_TOKEN_AMOUNT);
        uint256 order2Id = dsip.placeOrder(
            false,
            SECURITY_TOKEN_AMOUNT,
            SALE_TOKEN_AMOUNT,
            block.timestamp + 3600
        );
        // dsip.placeAndMatchOrder(
        //     false,
        //     SECURITY_TOKEN_AMOUNT,
        //     SALE_TOKEN_AMOUNT,
        //     1
        // );
        vm.stopPrank();
        uint256 t1FBal = feet.balanceOf(trader1);
        uint256 t2FBal = feet.balanceOf(trader2);
        dsip.matchOrders(order1Id, order2Id);
        IOrderBook book = IOrderBook(dsip.getOrderBook());
        IOrderBook.Order memory order1 = book.getOrder(order1Id);
        IOrderBook.Order memory order2 = book.getOrder(order2Id);
        address t1 = order1.isBuyOrder ? order1.trader : order2.trader;
        address t2 = !order2.isBuyOrder ? order2.trader : order1.trader;
        assertEq(SALE_TOKEN_AMOUNT * 2, saleToken.balanceOf(t2));
        uint256 takeFeeFromBuyer = (SALE_TOKEN_AMOUNT * allFee) / 10000;
        uint256 takeFeeFromSeller = (SALE_TOKEN_AMOUNT * allFee) / 10000;
        assertEq(
            takeFeeFromBuyer + takeFeeFromSeller,
            feet.balanceOf(address(dsip))
        );
        assertEq(t1FBal - takeFeeFromBuyer, feet.balanceOf(trader1));
        assertEq(t2FBal - takeFeeFromSeller, feet.balanceOf(trader2));
    }

    function testTokenDistributeWhenRedeemDividends() public {
        address dividendPayer = address(100);
        address colister1 = address(0xa1);
        address colister2 = address(0xa2);
        address colister3 = address(0xa3);
        address colister4 = address(0xa4);
        address colister5 = address(0xa5);
        address colister6 = address(0xa6);
        address colister7 = address(0xa7);
        address colister8 = address(0xa8);
        address colister9 = address(0xa9);
        address colister10 = address(0xa10);

        identityManager.addToWhitelist(colister1);
        identityManager.addToWhitelist(colister2);
        identityManager.addToWhitelist(colister3);
        identityManager.addToWhitelist(colister4);
        identityManager.addToWhitelist(colister5);
        identityManager.addToWhitelist(colister6);
        identityManager.addToWhitelist(colister7);
        identityManager.addToWhitelist(colister8);
        identityManager.addToWhitelist(colister9);
        identityManager.addToWhitelist(colister10);

        dsip.setDividendPayer(dividendPayer);
        uint256 sharePercentage1 = 5;
        uint256 sharePercentage2 = 10;
        uint256 sharePercentage3 = 15;
        uint256 sharePercentage4 = 25;
        uint256 sharePercentage5 = 5;
        uint256 sharePercentage6 = 10;
        uint256 sharePercentage7 = 5;
        uint256 sharePercentage8 = 10;
        uint256 sharePercentage9 = 5;
        uint256 sharePercentage10 = 10;
        // Note that colister2 has double the shares
        // of colister1. We expect them to get 2x
        // the fees.
        dsip.setFeeReceiverShares(3, colister1, sharePercentage1);
        dsip.setFeeReceiverShares(3, colister2, sharePercentage2);
        dsip.setFeeReceiverShares(3, colister3, sharePercentage3);
        dsip.setFeeReceiverShares(3, colister4, sharePercentage4);
        dsip.setFeeReceiverShares(3, colister5, sharePercentage5);
        dsip.setFeeReceiverShares(3, colister6, sharePercentage6);
        dsip.setFeeReceiverShares(3, colister7, sharePercentage7);
        dsip.setFeeReceiverShares(3, colister8, sharePercentage8);
        dsip.setFeeReceiverShares(3, colister9, sharePercentage9);
        dsip.setFeeReceiverShares(3, colister10, sharePercentage10);

        // Set a 1% fee for all markets (both buyer and seller)
        dsip.setFeeStructure(100, 100, 100, 100, 100, 100);

        identityManager.addToWhitelist(trader1);
        dsip.mintWithoutPayment(trader1, 100e18);

        feeToken.mint(dividendPayer, 100e18);

        vm.roll(100);
        uint256 paymentAmount = 10e18;
        vm.expectRevert("Not dividendPayer");
        dsip.setNextPayment(block.number + 150, paymentAmount, feeToken);

        vm.startPrank(dividendPayer);
        feeToken.approve(address(dsip), 20e18);
        dsip.setNextPayment(block.number + 150, paymentAmount, feeToken);
        vm.stopPrank();

        vm.roll(251);

        dsip.redeemDividends(trader1, paymentAmount);
        dsip.redeemFee(3, feeToken, colister1);
        dsip.redeemFee(3, feeToken, colister2);
        dsip.redeemFee(3, feeToken, colister3);
        dsip.redeemFee(3, feeToken, colister4);
        dsip.redeemFee(3, feeToken, colister5);
        dsip.redeemFee(3, feeToken, colister6);
        dsip.redeemFee(3, feeToken, colister7);
        dsip.redeemFee(3, feeToken, colister8);
        dsip.redeemFee(3, feeToken, colister9);
        dsip.redeemFee(3, feeToken, colister10);
        uint256 totalShareAmountOutput = (paymentAmount * 2) / 100;
        assertEq(
            feeToken.balanceOf(colister1) +
                feeToken.balanceOf(colister2) +
                feeToken.balanceOf(colister3) +
                feeToken.balanceOf(colister4) +
                feeToken.balanceOf(colister5) +
                feeToken.balanceOf(colister6) +
                feeToken.balanceOf(colister7) +
                feeToken.balanceOf(colister8) +
                feeToken.balanceOf(colister9) +
                feeToken.balanceOf(colister10),
            totalShareAmountOutput
        );
        assertTrue(
            feeToken.balanceOf(colister1) ==
                (totalShareAmountOutput * sharePercentage1) / 100 &&
                feeToken.balanceOf(colister2) ==
                (totalShareAmountOutput * sharePercentage2) / 100 &&
                feeToken.balanceOf(colister3) ==
                (totalShareAmountOutput * sharePercentage3) / 100 &&
                feeToken.balanceOf(colister4) ==
                (totalShareAmountOutput * sharePercentage4) / 100 &&
                feeToken.balanceOf(colister5) ==
                (totalShareAmountOutput * sharePercentage5) / 100 &&
                feeToken.balanceOf(colister6) ==
                (totalShareAmountOutput * sharePercentage6) / 100 &&
                feeToken.balanceOf(colister7) ==
                (totalShareAmountOutput * sharePercentage7) / 100 &&
                feeToken.balanceOf(colister8) ==
                (totalShareAmountOutput * sharePercentage8) / 100 &&
                feeToken.balanceOf(colister9) ==
                (totalShareAmountOutput * sharePercentage9) / 100 &&
                feeToken.balanceOf(colister10) ==
                (totalShareAmountOutput * sharePercentage10) / 100
        );
    }
}
