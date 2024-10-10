// SPDX-License-Identifier: All rights reserver 2023 

pragma solidity ^0.8.18;

import "src/interfaces/IDSIP.sol";
import "src/interfaces/IIdentityManager.sol";

import "src/DSIP.sol";
import "src/IdentityManager.sol";

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20{

    constructor(
        string memory name,
        string memory symbol
    )
        ERC20(name, symbol)
    {
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

}



contract DSIPInvariantTest is Test{

    IDSIP tokenDSIP;
    IIdentityManager identityManager;

    address investor1 = vm.addr(1);
    address investor2 = vm.addr(2);

    address colister1 = vm.addr(3);
    address colister2 = vm.addr(4);

    address seller = vm.addr(5);

	address propertyManager = vm.addr(6);

    uint256 pricePrimaryMarket=1e18;
    uint16 fee=50;

    uint256 CAP = 100e21;
	uint256 lockingTime = 365*86400;

    MyToken tokenFee;
    MyToken tokenDividend;
    MyToken tokenPrimarySale;

    function setUp() public {

        identityManager = new IdentityManager(
                    address(this)
        );

        tokenFee = new MyToken("Fee Token", "FTK");
        tokenDividend = new MyToken("Divident Token", "DTK");
        tokenPrimarySale = new MyToken("Token Primary Sale", "USDT");


        tokenDSIP = new DSIP(
                "DSIP",
                "DSP",
                CAP,
                address(this)
        );


        tokenDSIP.setIdentityManager(identityManager);
        tokenDSIP.setInitialSeller(seller);
        tokenDSIP.setDividendPayer(propertyManager);
        tokenDSIP.setFeeToken(tokenFee);
        tokenDSIP.setSaleToken(tokenPrimarySale);
        tokenDSIP.setPricePrimaryMarket(pricePrimaryMarket);
        tokenDSIP.setLockingTimeSeconds(0);
        tokenDSIP.setFeeStructure(fee, fee, fee, fee, 0, 0);


        tokenFee.mint(investor1, 1e24);
        tokenFee.mint(investor2, 1e24);
        tokenFee.mint(seller, 1e24);

        tokenPrimarySale.mint(investor1, 1e6*1e18);
        tokenPrimarySale.mint(investor2, 1e6*1e18);
        tokenPrimarySale.mint(seller, 1e6*1e18);

        vm.startPrank(investor1);
        tokenFee.approve(address(tokenDSIP), 1e24);
        tokenPrimarySale.approve(address(tokenDSIP), 1e6*1e18);
        vm.stopPrank();

        vm.startPrank(investor2);
        tokenFee.approve(address(tokenDSIP), 1e24);
        tokenPrimarySale.approve(address(tokenDSIP), 1e6*1e18);
        vm.stopPrank();

        vm.startPrank(seller);
        tokenFee.approve(address(tokenDSIP), 100e22);
        tokenPrimarySale.approve(address(tokenDSIP), 1e6*1e18);
        vm.stopPrank();


    }






    function invariantCapNotExceeded() public {
        assert(tokenDSIP.totalSupply() <= tokenDSIP.getCap());
    }

    function invariantOnlyWhitelistedCanReceiveTokens() public {
        // Example of a test scenario
        address nonWhitelistedUser = address(3);
        bool isWhitelisted = identityManager.isWhitelisted(nonWhitelistedUser);
        if (!isWhitelisted) {
            try tokenDSIP.transfer(nonWhitelistedUser, 100) {
                fail("Should not transfer to non-whitelisted user");
            } catch {}
        }
    }



}

