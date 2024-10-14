// SPDX-License-Identifier: All rights reserved and belonging to REClosure Ltd. 2023
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/interfaces/IMainExchange.sol";

interface IDSIP is IERC20 {

  // Events
  event ForceTransfer(address indexed from, address indexed to, uint256 amount);
  event SetInitialSeller(address indexed seller);
  event SetMainExchange(IMainExchange indexed mainExchange);
  // event Transfer(address from, address to, uint256 amount, IERC20 feeToken, uint256 totalBuyerFee, uint256 totalSellerFee);

  function pause() external;
  function unpause() external;
  function getCap() external view returns (uint256);

  // function mintWithoutPayment(address to, uint256 tokenAmount) external;
  // function mintWithPayment(address to, uint256 tokenAmount) external;
  function forceTransfer(address from, address to, uint256 amount) external returns (bool);

  function setInitialSeller(address _seller) external;
  function setMainExchange(IMainExchange _mainExchange) external;
}
