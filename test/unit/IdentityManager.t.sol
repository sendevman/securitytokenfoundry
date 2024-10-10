pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {IdentityManager} from "../../src/IdentityManager.sol";

contract IdentityManagerTest is Test {
    IdentityManager public identityManager;
    address public USER = makeAddr("user");
    address public other_user = makeAddr("other");

    function setUp() public {
        //Owner = = address(this) => address(IdentityManagerTest)
        identityManager = new IdentityManager(address(this));
    }

    function testOnlyOwnerCanWhitelist() public {
        identityManager.transferOwnership(USER);
        vm.expectRevert();
        identityManager.addToWhitelist(other_user);
        vm.expectRevert();
        identityManager.removeFromWhitelist(other_user);
    }

    function testIsWhitelistWorking() public {
        assertEq(
            identityManager.isWhitelisted(USER),
            false,
            "Initial status should be false"
        );

        identityManager.addToWhitelist(USER);
        assertEq(
            identityManager.isWhitelisted(USER),
            true,
            "User should be whitelisted after adding"
        );

        identityManager.removeFromWhitelist(USER);
        assertEq(
            identityManager.isWhitelisted(USER),
            false,
            "User should not be whitelisted after removal"
        );
    }

    function testRevertIfNotOwnerAddToWhitelist() public {
        assertEq(
            identityManager.isWhitelisted(USER),
            false,
            "Initial status should be false"
        );
        identityManager.transferOwnership(msg.sender);
        // still will be reverted because msg.sender is us/me but the caller is not us/me instead it's address(this)/IdentityManagerTest
        vm.expectRevert();
        identityManager.addToWhitelist(USER);
        assertEq(
            identityManager.isWhitelisted(USER),
            false,
            "User should not be whitelisted by non-owner"
        );
    }

    function testRevertIfNotOwnerRemoveFromWhitelist() public {
        identityManager.addToWhitelist(USER);
        assertEq(
            identityManager.isWhitelisted(USER),
            true,
            "User should be whitelisted initially"
        );
        identityManager.transferOwnership(msg.sender);
        // still will be reverted because msg.sender is us/me but the caller is not us/me instead it's address(this)/IdentityManagerTest
        vm.expectRevert();
        identityManager.removeFromWhitelist(USER);
        assertEq(
            identityManager.isWhitelisted(USER),
            true,
            "User should still be whitelisted by non-owner"
        );
    }
}
