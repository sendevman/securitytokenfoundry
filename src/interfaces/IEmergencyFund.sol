// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "src/interfaces/IDSIP.sol";

interface IEmergencyFund {

  event FundDeposited(address indexed from, uint256 amount);
  event FundWithdrawn(address indexed to, uint256 amount);

  function setDSIPToken(IDSIP _dsipToken) external;
  function withdraw(uint256 amount) external;
  function recoverFunds() external;
  function receiveFee(address sender, uint256 depositAmount) external;
}
