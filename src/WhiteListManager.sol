// SPDX-License-Identifier: All rights reserved and belonging to REClosure Ltd. 2023
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "src/interfaces/IWhiteListManager.sol";

contract WhiteListManager is IWhiteListManager, Ownable {

  mapping(address => bool) private whitelist;

  constructor(address issuer) Ownable(issuer) {}

  function isWhitelisted(address account) external view returns (bool) {
    return whitelist[account];
  }

  function addToWhitelist(address account) onlyOwner external {
    whitelist[account] = true;
    emit WhitelistUpdated(account, true);
  }

  function removeFromWhitelist(address account) onlyOwner external {
    whitelist[account] = false;
    emit WhitelistUpdated(account, false);
  }
}
