// SPDX-License-Identifier: All rights reserved and belonging to REClosure Ltd. 2023
pragma solidity ^0.8.18;

import "src/interfaces/IOrderBook.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract OrderBook is IOrderBook {

  using Math for uint;

  uint256 public nextOrderId;

  // Weighted price
  uint8 private maxPriceDiffForNewOrdersPct = 10;
  uint256 private weightedSum = 0;
  uint256 private totalSharesForWeightedSum = 0;
  uint256 private lastOrderTime = 0;
  uint256 private decayFactor = 90; 

  mapping(uint256 => Order) public orders;

  address public immutable mainExchange;

  modifier onlyMainExchange() {
    require(msg.sender == mainExchange, "Not security token");
    _;
  }

  constructor(address _mainExchange) {
    mainExchange = _mainExchange;
  }

  function setMaxPriceDiffForNewOrdersPct(uint8 _pct) external onlyMainExchange {
    maxPriceDiffForNewOrdersPct = _pct;
  }

  function placeOrder(
    address trader,
    bool isBuyOrder,
    uint256 amountDSIPToken,
    uint256 amountPROPTOToken,
    uint256 expiryTimestamp
  ) public onlyMainExchange returns (uint256) {
    nextOrderId++;
    uint256 orderId = nextOrderId;
    Order memory _order = Order(orderId, amountDSIPToken, amountPROPTOToken, trader, block.number, isBuyOrder, expiryTimestamp);
    orders[orderId] = _order;
    emit OrderPlaced(_order);
    return orderId;
  }

  function cancelOrder(uint256 orderId) public {
    Order storage order = orders[orderId];
    require( order.trader == msg.sender, "Not order owner");
    require(order.id != 0, "Order not found");

    emit OrderDeleted(order);
    delete orders[orderId];
  }

  function matchOrders(
    uint256 order1Id,
    uint256 order2Id
  ) public onlyMainExchange returns (address, address, uint256, uint256) {
    require (
      (order1Id <= nextOrderId) && 
      (order2Id <= nextOrderId) && 
      (order1Id != order2Id),
      "Invalid order indices"
    );

    Order memory order1 = orders[order1Id];
    Order memory order2 = orders[order2Id];

    // N.B.: Slither and other automated auditors don't
    // like .timestamp. But the leeway miners have to
    // tamper with the timestamp is much less than the
    // error the user will have when estimating the 
    // exact block number at the time they want their 
    // order expired.
    if (block.timestamp > order1.expiryTimestamp) {
      emit OrderDeleted(order1);
      delete orders[order1Id];
      revert OrderNotFoundOrExpired();
    }

    // If both orders are expired, they won't be both
    // deleted at the same time. That's okay, let's
    // optimize for the valid path and make sure that
    // it reverts somewhere otherwise. It'll be deleted
    // eventually.
    if (block.timestamp > order2.expiryTimestamp) {
      emit OrderDeleted(order2);
      delete orders[order2Id];
      revert OrderNotFoundOrExpired();
    }

    uint256 _price1 = order1.amountPROPTOToken * 1e18 / order1.amountDSIPToken;
    uint256 _price2 = order2.amountPROPTOToken * 1e18 / order2.amountDSIPToken;

    uint256 _amountDSIPToken;
    uint256 _amountPROPTOToken;

    _amountDSIPToken = order1.amountDSIPToken.min(order2.amountDSIPToken);

    // We take the price of the first arriving order
    if (order1.blockNumArrival < order2.blockNumArrival) {
      _amountPROPTOToken = _amountDSIPToken * order1.amountPROPTOToken / order1.amountDSIPToken;
    } else {
      _amountPROPTOToken = _amountDSIPToken * order2.amountPROPTOToken / order2.amountDSIPToken;
    }

    if (orders[order1Id].amountDSIPToken == _amountDSIPToken) {
      // Order 1 matched completely
      emit OrderDeleted(order1);
      delete orders[order1Id];

      orders[order2Id].amountDSIPToken -= _amountDSIPToken;
    } else {
      // Order 2 matched completely
      emit OrderDeleted(order2);
      delete orders[order2Id];

      orders[order1Id].amountDSIPToken -= _amountDSIPToken;

      emit OrderUpdated(order2);
    }

    // Make sure the price of the order does not
    // exceed 10% of the running last price
    if (totalSharesForWeightedSum > 0) {
      uint256 weightedAveragePrice = weightedSum * 1e18 / totalSharesForWeightedSum; 
      uint8 maxPct = maxPriceDiffForNewOrdersPct;
      require(
        (_price1 <= weightedAveragePrice * (100 + maxPct) / 100) && (_price1 >= weightedAveragePrice * (100 - maxPct) / 100) &&
        (_price2 <= weightedAveragePrice * (100 + maxPct) / 100) && (_price2 >= weightedAveragePrice * (100 - maxPct) / 100),
        "Price deviation from weighted average too high"
      );
    }

    uint256 timeDelta = block.timestamp - lastOrderTime;
    uint256 decay = decayFactor ** timeDelta / 100 ** timeDelta; 
    weightedSum = weightedSum * decay + _amountPROPTOToken;
    totalSharesForWeightedSum = totalSharesForWeightedSum * decay + _amountDSIPToken;
    lastOrderTime = block.timestamp;

    // We could have made this test earlier and fail early in case
    // orders don't match. But we need the token amounts to trigger
    // the actual transfer, so there's no harm on optimizing fot the
    // correct case and mildly increase gas costs for invalid orders.
    if (order1.isBuyOrder && !order2.isBuyOrder) {
      require(_price1 >= _price2, "Orders don't match");
      return (order1.trader, order2.trader, _amountPROPTOToken, _amountDSIPToken);
    } else if (order2.isBuyOrder && !order1.isBuyOrder) {
      require(_price1 <= _price2, "Orders don't match");
      return (order2.trader, order1.trader, _amountPROPTOToken, _amountDSIPToken);
    } else {
      revert InvalidOrderType();
    }
  }

  function getOrder(uint256 _id) public view returns (Order memory) {
    return orders[_id];
  }
}
