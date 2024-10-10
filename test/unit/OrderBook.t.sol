// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../../src/OrderBook.sol";
import "../../src/DSIP.sol";
import "../../src/interfaces/IDSIP.sol";
import "../util/SaleToken.sol";

contract OrderBookTest is Test {
    OrderBook public orderBook;
    IDSIP public securityToken;
    SaleToken public saleToken;
    address public owner = address(this);
    address public TRADER = address(0x1);
    uint256 public SALE_TOKEN_AMOUNT = 1000;
    uint256 public SECURITY_TOKEN_AMOUNT = 1000;

    function setUp() public {
        securityToken = new DSIP(
            "DSIP",
            "DSIP",
            1000000000000 * 10 ** 18,
            owner
        );
        saleToken = new SaleToken(1000000000000000 * 10 ** 18);
        orderBook = new OrderBook(address(securityToken));
    }

    function testOnlySecurityContractCanCallPlaceOrder() public {
        vm.expectRevert("Not security token");
        uint256 orderId = orderBook.placeOrder(
            TRADER,
            true,
            SECURITY_TOKEN_AMOUNT,
            SALE_TOKEN_AMOUNT,
            block.timestamp + 3600
        );
    }

    function testPlaceOrder() public {
        orderBook = new OrderBook(address(this));
        uint256 orderId = orderBook.placeOrder(
            TRADER,
            true,
            SECURITY_TOKEN_AMOUNT,
            SALE_TOKEN_AMOUNT,
            block.timestamp + 3600
        );
        OrderBook.Order memory order = orderBook.getOrder(orderId);

        assertEq(order.trader, TRADER);
        assertTrue(order.isBuyOrder);
        assertEq(order.amountSecurityToken, SECURITY_TOKEN_AMOUNT);
        assertEq(order.amountSaleToken, SALE_TOKEN_AMOUNT);
    }

    function testMatchOrders() public {
        orderBook = new OrderBook(address(this));
        uint256 orderId1 = orderBook.placeOrder(
            TRADER,
            true,
            SECURITY_TOKEN_AMOUNT,
            SALE_TOKEN_AMOUNT,
            block.timestamp + 3600
        );
        uint256 orderId2 = orderBook.placeOrder(
            TRADER,
            false,
            SALE_TOKEN_AMOUNT,
            SECURITY_TOKEN_AMOUNT,
            block.timestamp + 3600
        );

        (
            address buyer,
            address seller,
            uint256 amountSaleToken,
            uint256 amountSecurityToken
        ) = orderBook.matchOrders(orderId1, orderId2);

        assertEq(buyer, TRADER);
        assertEq(seller, TRADER);
        assertEq(amountSaleToken, SALE_TOKEN_AMOUNT);
        assertEq(amountSecurityToken, SECURITY_TOKEN_AMOUNT);

    }

    function testOrderExpiry() public {
        orderBook = new OrderBook(address(this));
        uint256 orderId1 = orderBook.placeOrder(
            TRADER,
            true,
            SECURITY_TOKEN_AMOUNT,
            SALE_TOKEN_AMOUNT,
            block.timestamp - 1
        );
        uint256 orderId2 = orderBook.placeOrder(
            TRADER,
            false,
            SECURITY_TOKEN_AMOUNT,
            SALE_TOKEN_AMOUNT,
            block.timestamp + 360
        );
		vm.expectRevert(abi.encodeWithSignature("OrderNotFoundOrExpired()"));
        orderBook.matchOrders(orderId1, orderId2);
		vm.expectRevert(abi.encodeWithSignature("OrderNotFoundOrExpired()"));
        orderBook.matchOrders(orderId2, orderId1);
    }

    function testInvalidOrderIndex() public {
        orderBook = new OrderBook(address(this));
        uint256 orderId1 = orderBook.placeOrder(
            TRADER,
            true,
            SECURITY_TOKEN_AMOUNT,
            SALE_TOKEN_AMOUNT,
            block.timestamp - 1
        );
        uint256 orderId2 = orderBook.nextOrderId() + 1;
        vm.expectRevert("Invalid order indices");
        orderBook.matchOrders(orderId1, orderId2);
        vm.expectRevert("Invalid order indices");
        orderBook.matchOrders(orderId2, orderId1);
        vm.expectRevert("Invalid order indices");
        orderBook.matchOrders(orderId1, orderId1);
    }

    function testRevertIfOrder1NotMatch() public {
        orderBook = new OrderBook(address(this));
        uint256 orderId1 = orderBook.placeOrder(
            TRADER,
            true,
            SECURITY_TOKEN_AMOUNT,
            SALE_TOKEN_AMOUNT,
            block.timestamp + 60
        );
        uint256 orderId2 = orderBook.placeOrder(
            TRADER,
            false,
            SECURITY_TOKEN_AMOUNT,
            SALE_TOKEN_AMOUNT + 1,
            block.timestamp + 360
        );
        vm.expectRevert("Orders don't match");
        orderBook.matchOrders(orderId1, orderId2);
    }

    function testRevertIfOrder2NotMatch() public {
        orderBook = new OrderBook(address(this));
        uint256 orderId1 = orderBook.placeOrder(
            TRADER,
            false,
            SECURITY_TOKEN_AMOUNT,
            SALE_TOKEN_AMOUNT + 1,
            block.timestamp + 60
        );
        uint256 orderId2 = orderBook.placeOrder(
            TRADER,
            true,
            SECURITY_TOKEN_AMOUNT,
            SALE_TOKEN_AMOUNT,
            block.timestamp + 360
        );
        vm.expectRevert("Orders don't match");
        orderBook.matchOrders(orderId1, orderId2);
    }

    function testRevertIfBothSameOrderType() public {
        orderBook = new OrderBook(address(this));
        uint256 orderId1 = orderBook.placeOrder(
            TRADER,
            true,
            SECURITY_TOKEN_AMOUNT,
            SALE_TOKEN_AMOUNT,
            block.timestamp + 60
        );
        uint256 orderId2 = orderBook.placeOrder(
            TRADER,
            true,
            SECURITY_TOKEN_AMOUNT,
            SALE_TOKEN_AMOUNT,
            block.timestamp + 360
        );
		vm.expectRevert(abi.encodeWithSignature("InvalidOrderType()"));
        orderBook.matchOrders(orderId1, orderId2);
        uint256 orderId3 = orderBook.placeOrder(
            TRADER,
            false,
            SECURITY_TOKEN_AMOUNT,
            SALE_TOKEN_AMOUNT,
            block.timestamp + 60
        );
        uint256 orderId4 = orderBook.placeOrder(
            TRADER,
            false,
            SECURITY_TOKEN_AMOUNT,
            SALE_TOKEN_AMOUNT,
            block.timestamp + 360
        );
		vm.expectRevert(abi.encodeWithSignature("InvalidOrderType()"));
        orderBook.matchOrders(orderId3, orderId4);
    }
}
