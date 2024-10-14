// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "src/interfaces/IDSIP.sol";
import "src/interfaces/IEmergencyFund.sol";

contract EmergencyFund is IEmergencyFund, Ownable {
  IDSIP public dsipToken;
  uint256 public emergencyFundBalance;

  constructor(address _issuer) Ownable(_issuer) {
    emergencyFundBalance = 0;
  }

  function setDSIPToken(IDSIP _dsipToken) external onlyOwner {
    dsipToken = _dsipToken;
  }

  function deposit(address sender, uint256 amount) internal {
    emergencyFundBalance += amount;
    dsipToken.transferFrom(sender, address(this), amount);
    emit FundDeposited(msg.sender, amount);
  }

  function withdraw(uint256 amount) external onlyOwner {
    require(amount <= emergencyFundBalance, "Insufficient emergency fund balance");
    emergencyFundBalance -= amount;
    payable(owner()).transfer(amount);
    emit FundWithdrawn(msg.sender, amount);
  }

  function recoverFunds() external onlyOwner {
    uint256 amount = emergencyFundBalance;
    emergencyFundBalance = 0;
    payable(owner()).transfer(amount);
    emit FundWithdrawn(msg.sender, amount);
  }

  function receiveFee(address sender, uint256 depositAmount) external onlyOwner {
    deposit(sender, depositAmount);
  }
}
