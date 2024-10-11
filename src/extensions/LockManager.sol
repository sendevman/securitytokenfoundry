// SPDX-License-Identifier: All rights reserved and belonging to REClosure Ltd. 2023
pragma solidity ^0.8.18;

abstract contract LockManager{

  uint256 lockingSeconds;

  struct LockedAmount {
    uint256 amount;
    uint256 receivedTimestamp;
  }

  // account => lockedAmounts (array)
  mapping(address => LockedAmount[]) private lockedAmounts;

  constructor() {}

  function unlockedTokens(address account, uint256 amount, uint256 totalBalance) internal view returns (bool) {
    if (lockingSeconds == 0) {
      // Skip calculations if not set
      return true;
    }

    uint256 _lockedAmount = 0;
    uint256 _lockingSeconds = lockingSeconds;

    for (uint256 i = 0; i < lockedAmounts[account].length; i++) {
      if (block.timestamp < (lockedAmounts[account][i].receivedTimestamp + _lockingSeconds)) {
        _lockedAmount += lockedAmounts[account][i].amount;
      }
    }
    return totalBalance - _lockedAmount >= amount;
  }

  function _annotateLockedFunds(address account, uint256 amount) internal {
    lockedAmounts[account].push(LockedAmount(amount, block.timestamp));
  }

  function _setLockingTimeSeconds(uint256 _lockingSeconds) internal {
    lockingSeconds = _lockingSeconds;
  }
}
