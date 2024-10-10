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
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract DSIPTest is Test {
    using Math for uint;
    DSIP public dsip;
    IdentityManager public identityManager;
    OrderBook public orderBook;
    SaleToken public saleToken;
    FeeToken public feeToken;

    address public owner = address(this);
    address public trader1 = address(0x1);
    address public trader2 = address(0x2);
    address public seller = address(0x3);

    address investor1 = vm.addr(10);
    address investor2 = vm.addr(11);
    address investor3 = vm.addr(12);
    address investor4 = vm.addr(13);

    address colister1 = vm.addr(20);
    address colister2 = vm.addr(21);
    address colister3 = vm.addr(22);

    uint256 public SECURITY_TOKEN_AMOUNT = 1000;
    uint256 public SALE_TOKEN_AMOUNT = 1000;
    uint256 public capAmount =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;
    uint256 public totalMaxSupply =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;

    function setUp() public {
        dsip = new DSIP("DSIP", "DSIP", capAmount, owner);
        identityManager = new IdentityManager(owner);
        saleToken = new SaleToken(totalMaxSupply);
        feeToken = new FeeToken(totalMaxSupply);
        dsip.setIdentityManager(identityManager);
        dsip.setInitialSeller(address(this));
        orderBook = new OrderBook(address(dsip));
        dsip.setOrderBook(orderBook);
        dsip.setFeeToken(feeToken);
        dsip.setSaleToken(saleToken);
        uint16 allFee = 1;
        dsip.setFeeStructure(allFee, allFee, allFee, allFee, allFee, 0);
    }

    function testMintWithoutPaymentFuzz(
        address to,
        uint256 tokenAmount
    ) public {
        if (
            to != address(0) &&
            to != address(this) &&
            to != address(dsip) &&
            tokenAmount != 0
        ) {
            vm.expectRevert();
            dsip.mintWithoutPayment(to, tokenAmount);
            identityManager.addToWhitelist(to);
            uint256 startbalance = dsip.balanceOf(to);
            uint256 totalCap = tokenAmount + dsip.totalSupply();
            if (totalCap > capAmount) {
                vm.expectRevert(
                    abi.encodeWithSignature(
                        "ERC20ExceededCap(uint256 increasedSupply, uint256 cap)",
                        tokenAmount,
                        capAmount
                    )
                );
                dsip.mintWithoutPayment(to, tokenAmount);
            } else {
                dsip.mintWithoutPayment(to, tokenAmount);
                uint256 endbalance = dsip.balanceOf(to);
                assertEq(endbalance - startbalance, tokenAmount);
            }
        }
    }

    function testMintWithPaymentFuzz(address to, uint128 tokenAmount) public {
        vm.assume(tokenAmount < type(uint128).max - 1);
        vm.assume(tokenAmount < totalMaxSupply);
        vm.assume(to != address(dsip));
        if (
            to != address(0) &&
            tokenAmount != 0 &&
            saleToken.balanceOf(address(this)) > tokenAmount &&
            feeToken.balanceOf(address(this)) > tokenAmount &&
            tokenAmount < totalMaxSupply
        ) {
            dsip.setPricePrimaryMarket(1 ether);
            uint16 allFee = 10000;
            dsip.setFeeStructure(allFee, allFee, allFee, allFee, allFee, 0);
            dsip.setFeeToken(feeToken);
            dsip.setSaleToken(saleToken);
            feeToken.transfer(to, tokenAmount); //as fee == tokenAmount has been set.
            saleToken.transfer(to, tokenAmount); //as fee == tokenAmount has been set.
            vm.startPrank(to);
            saleToken.approve(address(dsip), tokenAmount);
            feeToken.approve(address(dsip), tokenAmount);
            vm.stopPrank();
            feeToken.approve(address(dsip), tokenAmount);
            vm.expectRevert();
            dsip.mintWithPayment(to, tokenAmount);
            identityManager.addToWhitelist(to);
            uint256 startbalance = dsip.balanceOf(to);
            uint256 startSbalance = saleToken.balanceOf(seller);
            uint256 startFbalance = feeToken.balanceOf(address(dsip));
            uint256 totalCap = tokenAmount + dsip.totalSupply();
            if (totalCap > capAmount) {
                vm.expectRevert();
                dsip.mintWithPayment(to, tokenAmount);
            } else {
                dsip.mintWithPayment(to, tokenAmount);
                uint256 endbalance = dsip.balanceOf(to);
                uint256 endSbalance = saleToken.balanceOf(seller);
                uint256 endFbalance = feeToken.balanceOf(address(dsip));
                assertEq(endbalance - startbalance, tokenAmount);
                assertEq(startSbalance, 0);
                assertEq(endSbalance, 0);
                assertTrue(endFbalance - startFbalance >= tokenAmount);
                assertEq(saleToken.balanceOf(to), 0);
                assertEq(feeToken.balanceOf(to), 0);
            }
        }
    }

    function testredeemFeeFuzz(address investor, address _recipient) public {
        // if (investor == address(this) || _recipient == address(this)) {
        //     return;
        // }

        IERC20 _token = IERC20(feeToken);
        if (
            investor != address(0) &&
            address(_token) != address(0) &&
            _recipient != (address(0)) &&
            investor != address(this) &&
            _recipient != address(this) &&
            investor != address(dsip) &&
            _recipient != address(dsip)
        ) {
            if (!identityManager.isWhitelisted(_recipient)) {
                vm.expectRevert(
                    abi.encodeWithSignature(
                        "DSIPNotWhitelisted(address)",
                        _recipient
                    )
                );
                dsip.setFeeReceiverShares(1, _recipient, 1 ether);
            }
            identityManager.addToWhitelist(_recipient);

            dsip.setFeeReceiverShares(1, _recipient, 1 ether);
            dsip.setFeeReceiverShares(2, _recipient, 1 ether);
            uint256 tokenAmount = 100000;
            dsip.setPricePrimaryMarket(1 ether);
            uint16 allFee = 10000;
            dsip.setFeeStructure(allFee, allFee, allFee, allFee, allFee, 0);
            dsip.setFeeToken(feeToken);
            dsip.setSaleToken(saleToken);
            feeToken.transfer(investor, tokenAmount);
            saleToken.transfer(investor, tokenAmount);
            vm.startPrank(investor);
            saleToken.approve(address(dsip), tokenAmount);
            feeToken.approve(address(dsip), tokenAmount);
            vm.stopPrank();
            feeToken.approve(address(dsip), tokenAmount);
            // vm.expectRevert();
            // dsip.mintWithPayment(investor, tokenAmount);
            identityManager.addToWhitelist(investor);
            dsip.mintWithPayment(investor, tokenAmount);
            uint256 startBalance = _token.balanceOf(_recipient);
            if (address(_token) == address(dsip)) {
                vm.expectRevert("Cannot redeem DSIP token");
                dsip.redeemFee(1, _token, _recipient);
            } else {
                dsip.redeemFee(1, _token, _recipient);
                uint256 endBalance = _token.balanceOf(_recipient);
                assertTrue(endBalance > startBalance);
                console.log(endBalance, tokenAmount);
                assertEq(endBalance, tokenAmount * 2); //as fee and max_fee is equal and both buyer fee and seller fee
            }
        }
    }

    function testplaceOrderFuzz(
        address trader,
        bool isBuyOrder,
        uint256 amountSecurityToken,
        uint256 amountSaleToken,
        uint256 expiryTimestamp
    ) public {
        vm.assume(amountSecurityToken < capAmount);
        vm.assume(amountSaleToken < capAmount);
        vm.assume(expiryTimestamp < 4000 days);
        if (
            trader == address(0) ||
            amountSaleToken == 0 ||
            amountSecurityToken == 0
        ) {
            return;
        }
        dsip.pause();

		identityManager.addToWhitelist(address(this));
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        dsip.placeOrder(
            isBuyOrder,
            amountSecurityToken,
            amountSaleToken,
            block.timestamp + expiryTimestamp
        );
        dsip.unpause();
        identityManager.addToWhitelist(trader);
        dsip.mintWithoutPayment(trader, amountSecurityToken);
        feeToken.transfer(trader, amountSaleToken);
        saleToken.transfer(trader, amountSaleToken);
        vm.startPrank(trader);
        saleToken.approve(address(dsip), amountSaleToken);
        feeToken.approve(address(dsip), amountSaleToken);
        uint256 orderId = dsip.placeOrder(
            isBuyOrder,
            amountSecurityToken,
            amountSaleToken,
            block.timestamp + expiryTimestamp
        );
        IOrderBook book = dsip.getOrderBook();
        IOrderBook.Order memory order = book.getOrder(orderId);
        vm.stopPrank();

        assertEq(order.trader, trader);
        assertTrue(order.isBuyOrder == isBuyOrder);
        assertEq(order.amountSecurityToken, amountSecurityToken);
        assertEq(order.amountSaleToken, amountSaleToken);
    }

    function testmatchOrdersFuzz(
        address traderA,
        address traderB,
        bool isBuyOrderA,
        bool isBuyOrderB,
        uint128 amountSecurityTokenA,
        uint128 amountSaleTokenA,
        uint32 expiryTimestampA,
        uint32 expiryTimestampB
    ) public {
        // bool isBuyOrderB = !isBuyOrderA;
        uint128 amountSecurityTokenB = amountSecurityTokenA;
        uint128 amountSaleTokenB = amountSaleTokenA;
        vm.assume(amountSecurityTokenA < type(uint128).max - 1);
        vm.assume(amountSecurityTokenB < type(uint128).max - 1);
        vm.assume(amountSaleTokenA < type(uint128).max - 1);
        vm.assume(amountSaleTokenB < type(uint128).max - 1);
        vm.assume(expiryTimestampA < type(uint32).max - 1);
        vm.assume(expiryTimestampB < type(uint32).max - 1);

        if (
            traderA == address(0) ||
            amountSaleTokenA == 0 ||
            amountSecurityTokenA == 0 ||
            traderB == address(0) ||
            amountSaleTokenB == 0 ||
            amountSecurityTokenB == 0 ||
            expiryTimestampA == 0 ||
            expiryTimestampB == 0
        ) {
            return;
        }
        dsip.pause();

        identityManager.addToWhitelist(address(this));
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        dsip.placeOrder(
            isBuyOrderA,
            amountSecurityTokenA,
            amountSaleTokenA,
            block.timestamp + expiryTimestampA
        );
        dsip.unpause();
        identityManager.addToWhitelist(traderA);
        identityManager.addToWhitelist(traderB);
        dsip.mintWithoutPayment(traderA, amountSecurityTokenA);
        dsip.mintWithoutPayment(traderB, amountSecurityTokenB);
        if (feeToken.balanceOf(address(this)) < amountSaleTokenA) {
            vm.expectRevert(
                abi.encodeWithSignature(
                    "ERC20InsufficientBalance(from, fromBalance, value)",
                    address(this),
                    feeToken.balanceOf(address(this)),
                    amountSaleTokenA
                )
            );

            feeToken.transfer(traderA, amountSaleTokenA);
            return;
        }
        feeToken.transfer(traderA, amountSaleTokenA);
        if (feeToken.balanceOf(address(this)) < amountSaleTokenB) {
            vm.expectRevert();
            abi.encodeWithSignature(
                "ERC20InsufficientBalance(from, fromBalance, value)",
                address(this),
                feeToken.balanceOf(address(this)),
                amountSaleTokenB
            );

            feeToken.transfer(traderB, amountSaleTokenB);
            return;
        }

        feeToken.transfer(traderB, amountSaleTokenB);
        saleToken.transfer(traderA, amountSaleTokenA);
        saleToken.transfer(traderB, amountSaleTokenB);
        feeToken.approve(address(dsip), amountSaleTokenB);
        feeToken.approve(address(dsip), amountSaleTokenA);
        uint256 tABal = saleToken.balanceOf(traderA);
        uint256 tBBal = saleToken.balanceOf(traderB);
        vm.startPrank(traderA);
        saleToken.approve(address(dsip), amountSaleTokenA);
        feeToken.approve(address(dsip), amountSaleTokenA);
        uint256 orderIdA = dsip.placeOrder(
            isBuyOrderA,
            amountSecurityTokenA,
            amountSaleTokenA,
            block.timestamp + expiryTimestampA
        );
        vm.stopPrank();
        vm.startPrank(traderB);
        saleToken.approve(address(dsip), amountSaleTokenB);
        feeToken.approve(address(dsip), amountSaleTokenB);
        uint256 orderIdB = dsip.placeOrder(
            isBuyOrderB,
            amountSecurityTokenB,
            amountSaleTokenB,
            block.timestamp + expiryTimestampB
        );
        vm.stopPrank();

        IOrderBook book = dsip.getOrderBook();
        IOrderBook.Order memory orderA = book.getOrder(orderIdA);
        IOrderBook.Order memory orderB = book.getOrder(orderIdB);

        uint256 _priceA = (orderA.amountSaleToken * 1e18) /
            orderA.amountSecurityToken;
        uint256 _priceB = (orderB.amountSaleToken * 1e18) /
            orderB.amountSecurityToken;
        if (isBuyOrderA == isBuyOrderB) {
            vm.expectRevert(abi.encodeWithSignature("InvalidOrderType()"));
            dsip.matchOrders(orderIdA, orderIdB);
            return;
        } else if (isBuyOrderA) {
            if (_priceA < _priceB) {
                vm.expectRevert("Orders don't match");
                dsip.matchOrders(orderIdA, orderIdB);
            }
        } else if (isBuyOrderB) {
            if (_priceA > _priceB) {
                vm.expectRevert("Orders don't match");
                dsip.matchOrders(orderIdA, orderIdB);
            }
        } else {
            dsip.matchOrders(orderIdA, orderIdB);
        }

        // if (isBuyOrderA && !isBuyOrderB) {
        //     // uint256 traderBBal = saleToken.balanceOf(traderB);
        //     assertEq(saleToken.balanceOf(traderB), amountSaleTokenA);
        // }
    }

    function testplaceAndMatchOrderFuzz(
        address trader,
        bool isBuyOrder,
        uint128 amountSecurity,
        uint128 amountSale
    ) public {
        vm.assume(amountSecurity < type(uint128).max - 1);
        vm.assume(amountSale < type(uint128).max - 1);
        uint256 amountSecurityToken = uint256(amountSecurity);
        uint256 amountSaleToken = uint256(amountSale);
        if (
            trader == address(0) ||
            amountSaleToken == 0 ||
            amountSecurityToken == 0
        ) {
            return;
        }
        identityManager.addToWhitelist(trader);
        identityManager.addToWhitelist(address(this));
        dsip.mintWithoutPayment(trader, amountSecurityToken);
        dsip.mintWithoutPayment(address(this), amountSecurityToken);
        feeToken.transfer(trader, amountSaleToken);
        saleToken.transfer(trader, amountSaleToken);
        vm.startPrank(trader);
        saleToken.approve(address(dsip), amountSaleToken);
        feeToken.approve(address(dsip), amountSaleToken);
        uint256 orderId = dsip.placeOrder(
            isBuyOrder,
            amountSecurityToken,
            amountSaleToken,
            block.timestamp + 300
        );
        // IOrderBook book = dsip.getOrderBook();
        // IOrderBook.Order memory order = book.getOrder(orderId);
        vm.stopPrank();
        saleToken.approve(address(dsip), amountSaleToken);
        feeToken.approve(address(dsip), amountSaleToken);
        uint256 startBalance = saleToken.balanceOf(address(this));
        dsip.placeAndMatchOrder(
            !isBuyOrder,
            amountSecurityToken,
            amountSaleToken,
            orderId
        );

        if (isBuyOrder) {
            assertEq(
                saleToken.balanceOf(address(this)) - startBalance,
                amountSaleToken
            );
        } else {
            assertEq(saleToken.balanceOf(trader), amountSaleToken * 2);
        }
    }

    function testMatchOrdersBatchFuzz(
        address traderA,
        address traderB,
        address traderC,
        address traderD
    ) public {
        if (
            traderA == address(0) ||
            traderB == address(0) ||
            traderC == address(0) ||
            traderD == address(0) ||
            traderA == traderB ||
            traderA == traderC ||
            traderD == traderA ||
            traderB == traderA ||
            traderB == traderC ||
            traderB == traderD ||
            traderC == traderD ||
            traderC == traderA ||
            traderC == traderD
        ) {
            return;
        }
        identityManager.addToWhitelist(traderA);
        identityManager.addToWhitelist(traderB);
        identityManager.addToWhitelist(traderC);
        identityManager.addToWhitelist(traderD);
        dsip.mintWithoutPayment(traderA, SECURITY_TOKEN_AMOUNT);
        dsip.mintWithoutPayment(traderB, SECURITY_TOKEN_AMOUNT);
        dsip.mintWithoutPayment(traderC, SECURITY_TOKEN_AMOUNT);
        dsip.mintWithoutPayment(traderD, SECURITY_TOKEN_AMOUNT);
        feeToken.transfer(traderA, SECURITY_TOKEN_AMOUNT);
        saleToken.transfer(traderA, SALE_TOKEN_AMOUNT);
        feeToken.transfer(traderB, SECURITY_TOKEN_AMOUNT);
        saleToken.transfer(traderB, SALE_TOKEN_AMOUNT);
        feeToken.transfer(traderC, SECURITY_TOKEN_AMOUNT);
        saleToken.transfer(traderC, SALE_TOKEN_AMOUNT);
        feeToken.transfer(traderD, SECURITY_TOKEN_AMOUNT);
        saleToken.transfer(traderD, SALE_TOKEN_AMOUNT);
        vm.startPrank(traderA);
        saleToken.approve(address(dsip), SALE_TOKEN_AMOUNT + SALE_TOKEN_AMOUNT);
        feeToken.approve(
            address(dsip),
            SECURITY_TOKEN_AMOUNT * SECURITY_TOKEN_AMOUNT
        );
        dsip.approve(
            address(dsip),
            SECURITY_TOKEN_AMOUNT + SECURITY_TOKEN_AMOUNT
        );

        uint256 order1Id = dsip.placeOrder(
            true,
            SECURITY_TOKEN_AMOUNT,
            SALE_TOKEN_AMOUNT,
            block.timestamp + 3600
        );
        vm.stopPrank();
        vm.startPrank(traderB);
        saleToken.approve(address(dsip), SALE_TOKEN_AMOUNT + SALE_TOKEN_AMOUNT);
        feeToken.approve(
            address(dsip),
            SECURITY_TOKEN_AMOUNT * SECURITY_TOKEN_AMOUNT
        );
        dsip.approve(
            address(dsip),
            SECURITY_TOKEN_AMOUNT + SECURITY_TOKEN_AMOUNT
        );

        uint256 order2Id = dsip.placeOrder(
            false,
            SALE_TOKEN_AMOUNT,
            SECURITY_TOKEN_AMOUNT,
            block.timestamp + 3600
        );
        vm.stopPrank();
        vm.startPrank(traderC);
        saleToken.approve(address(dsip), SALE_TOKEN_AMOUNT + SALE_TOKEN_AMOUNT);
        feeToken.approve(
            address(dsip),
            SECURITY_TOKEN_AMOUNT * SECURITY_TOKEN_AMOUNT
        );
        dsip.approve(
            address(dsip),
            SECURITY_TOKEN_AMOUNT + SECURITY_TOKEN_AMOUNT
        );

        uint256 order3Id = dsip.placeOrder(
            true,
            SECURITY_TOKEN_AMOUNT,
            SALE_TOKEN_AMOUNT,
            block.timestamp + 3600
        );
        vm.stopPrank();
        vm.startPrank(traderD);
        saleToken.approve(address(dsip), SALE_TOKEN_AMOUNT + SALE_TOKEN_AMOUNT);
        feeToken.approve(
            address(dsip),
            SECURITY_TOKEN_AMOUNT * SECURITY_TOKEN_AMOUNT
        );
        dsip.approve(
            address(dsip),
            SECURITY_TOKEN_AMOUNT + SECURITY_TOKEN_AMOUNT
        );

        uint256 order4Id = dsip.placeOrder(
            false,
            SALE_TOKEN_AMOUNT,
            SECURITY_TOKEN_AMOUNT,
            block.timestamp + 3600
        );
        vm.stopPrank();

        uint256[][2] memory orders;
        orders[0] = new uint256[](2);
        orders[1] = new uint256[](2);

        orders[0][0] = 1;
        orders[0][1] = 2;
        orders[1][0] = 3;
        orders[1][1] = 4;
        dsip.matchOrdersBatch(orders);
        uint256 traderABalanceAfterTrade = dsip.balanceOf(traderA);
        assertEq(
            traderABalanceAfterTrade,
            (SECURITY_TOKEN_AMOUNT + SALE_TOKEN_AMOUNT)
        );
    }

    function testsetFeeReceiverSharesFuzz(
        address traderA,
        uint104 _shares
    ) public {
        vm.assume(_shares < type(uint104).max - 1);
        // vm.expectRevert(
        //     abi.encodeWithSelector(IDSIP.DSIPNotWhitelisted.selector, trader1)
        // );
        // dsip.setFeeReceiverShares(1, trader1, 1 ether);
        if (traderA == address(0) || _shares == 0) {
            return;
        }
        identityManager.addToWhitelist(traderA);
        dsip.setFeeReceiverShares(1, traderA, uint256(_shares));
        dsip.setFeeReceiverShares(2, traderA, uint256(_shares));
        dsip.setFeeReceiverShares(3, traderA, uint256(_shares));
    }

    function testTokenDistributeWhenRedeemDividendsFuzz(
        address[11] memory _addresses
    ) public {
        for (uint256 i = 0; i < _addresses.length; i++) {
            for (uint256 j = 0; j < _addresses.length; j++) {
                if (i != j) {
                    vm.assume(_addresses[i] != _addresses[j]);
                }
            }
            if (
                _addresses[i] == address(dsip) ||
                _addresses[i] == address(this) ||
                _addresses[i] == address(0)
            ) {
                return;
            }
        }
        // if(col1 == address(0) ||col2 == address(0) ||col3 == address(0) ||col4 == address(0) ||col5 == address(0) ||col6 == address(0) ||col7 == address(0) ||col8 == address(0) ||col9 == address(0) || col10 == address(0) || _dividentPayer == address(0) ){
        //     return;
        // }

        address dividendPayer = _addresses[0];
        address colister1 = _addresses[1];
        address colister2 = _addresses[2];
        address colister3 = _addresses[3];
        address colister4 = _addresses[4];
        address colister5 = _addresses[5];
        address colister6 = _addresses[6];
        address colister7 = _addresses[7];
        address colister8 = _addresses[8];
        address colister9 = _addresses[9];
        address colister10 = _addresses[10];

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

        feeToken.transfer(dividendPayer, 100e18);

        vm.roll(100);
        uint256 paymentAmount = 10000;
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

    // function testtryTestingRedeemFeeFuzz() public {
    //     // testredeemFeeFuzz(
    //     //     0x71Eb859D540F0900EDC10b6AAabc70b78061123A,
    //     //     0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
    //     // );
    //     // testMatchOrdersBatchFuzz(
    //     //     0xdBaf8eA784f936CCC7fcB726022E5f770Df73926,
    //     //     0xA43EDF602b835Eb5b2028Db0C20F39007937E0a1,
    //     //     0xdBaf8eA784f936CCC7fcB726022E5f770Df73926,
    //     //     0x00E229020894C14410f08cD49bFaED459383EE03
    //     // );
    //     // testTokenDistributeWhenRedeemDividendsFuzz(
    //     //     [
    //     //         0x643da243195784B45fa40570017B2EC4AAa823bF,
    //     //         0x266d8f9c8Ab039617BE4E9098412B51cc686d7E9,
    //     //         0x0000000000000000000000000000000000006082,
    //     //         0x759988C793BC0Bb014213D598C0DB47989e342a4,
    //     //         0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f,
    //     //         0x0000000000000000000000000000000000000018,
    //     //         0x0000000000000000000000000000000000001DB1,
    //     //         0x2039cB6ACE23bEf4b99aFE6eA1569eAb946F044D,
    //     //         0x0000000000000000000000000000000000005f0E,
    //     //         0x00000000000000000000000000000000000000F2,
    //     //         0xD648314D5C990C9BAF4842B13Cd830D53B897EaA
    //     //     ]
    //     // );
    // }
    //     function testArithmeticErrorFuzz(
    //         uint256 _number,
    //         uint256 _bigNumber
    //     ) public {
    //         vm.assume(_number < type(uint256).max - 1);
    //         vm.assume(_bigNumber < type(uint256).max - 1);
    //         // vm.assume((_bigNumber + _number) < type(uint256).max - 1);
    //         uint256 big;
    //         vm.assume(big < type(uint256).max - 1);
    //         if (_number < _bigNumber) {
    //             assertTrue(_number < _bigNumber);
    //         } else {
    //             assertTrue(_number >= _bigNumber);
    //         }
    //         big = _number + _bigNumber;
    //     }

    //     function testArithmeticFuzzz(uint128 _number, uint128 _bigNumber) public {
    //         vm.assume(_number < type(uint128).max - 1);
    //         vm.assume(_bigNumber < type(uint128).max - 1);
    //         // vm.assume(_bigNumber + _number < type(uint104).max - 1);
    //         uint256 big;
    //         vm.assume(big < type(uint256).max - 1);
    //         if (uint256(_number) < uint256(_bigNumber)) {
    //             assertTrue(uint256(_number) < uint256(_bigNumber));
    //         } else {
    //             assertTrue(uint256(_number) >= uint256(_bigNumber));
    //         }
    //         big = uint256(_number) + uint256(_bigNumber);
    //     }
}
