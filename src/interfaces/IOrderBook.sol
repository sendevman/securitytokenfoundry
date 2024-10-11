// SPDX-License-Identifier: All rights reserved and belonging to REClosure Ltd. 2023
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/interfaces/IDSIP.sol";

interface IOrderBook {

  error OrderNotFoundOrExpired();
  error InvalidOrderType();

  event OrderPlaced(Order);
  event OrderDeleted(Order);
  event OrderUpdated(Order);

  struct Order {
    uint256 id;
    uint256 amountSecurityToken;
    uint256 amountSaleToken;
    address trader;
    uint256 blockNumArrival;
    bool isBuyOrder;
    uint256 expiryTimestamp;
  }

  function cancelOrder(uint256 orderId) external;

  function placeOrder(address trader, bool isBuyOrder, uint256 amountSecurityToken, uint256 amountSaleToken, uint256 expiryTimestamp) external returns (uint256 orderId); 

  function matchOrders(uint256 order1Id, uint256 order2Id) external returns (address traderA, address traderB, uint256 amountSaleToken, uint256 amountSecurityToken); 

  function getOrder(uint256 _id) external view returns (Order memory);

  function setMaxPriceDiffForNewOrdersPct(uint8 _pct) external;
}
