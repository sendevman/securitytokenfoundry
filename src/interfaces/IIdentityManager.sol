// SPDX-License-Identifier: All rights reserved and belonging to REClosure Ltd. 2023
pragma solidity ^0.8.18;


interface IIdentityManager {


	event WhitelistUpdated(address, bool);

	function isWhitelisted(address account) external view returns (bool); 

    function addToWhitelist(address account) external;

    function removeFromWhitelist(address account) external;

}

