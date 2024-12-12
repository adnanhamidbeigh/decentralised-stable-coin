// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Narrows down how to narrow down invariants calls.
import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralisedStableCoin} from "src/DecentralisedStableCoin.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DSCEngine engine;
    DecentralisedStableCoin dsc;
    MockV3Aggregator ethUsdPriceFeed;
    ERC20Mock weth;
    ERC20Mock wbtc;
    uint256 public timesMintCalled;
    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    address[] public usersWithCollateralDeposited;

    constructor(DSCEngine _engine, DecentralisedStableCoin _dsc) {
        engine = _engine;
        dsc = _dsc;
        address[] memory collateralTokens = engine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(engine.getTokenCollateralPriceFeed(address(weth)));
    }
    // redeem collateral

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(engine), amountCollateral);

        engine.depositCollateral(address(collateral), amountCollateral); //aprove the collateral first
        vm.stopPrank();
        usersWithCollateralDeposited.push(msg.sender); //double push
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = engine.getCollateralBalanceOfUser(address(collateral), msg.sender);
        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);

        if (amountCollateral == 0) {
            return;
        }

        engine.redeemCollateral(address(collateral), amountCollateral);
    }

    function mintDsc(uint256 amount, uint256 addressSeed) public {
        if (usersWithCollateralDeposited.length == 0) {
            return;
        }

        address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(sender);
        int256 maxDscToMint = ((int256(collateralValueInUsd) / 2) - int256(totalDscMinted));

        if (maxDscToMint < 0) {
            return;
        }
        amount = bound(amount, 0, uint256(maxDscToMint));
        if (amount == 0) {
            return;
        }
        vm.startPrank(sender);
        engine.mintDSC(amount); // mint less than collateral value
        vm.stopPrank();
        timesMintCalled++;
    }

    // function updateCollateralPrice(uint96 newPrice) public {
    //     int256 newPriceInt = int256(uint256(newPrice));
    //     ethUsdPriceFeed.updateAnswer(newPriceInt);
    // }

    // helper functions
    function _getCollateralFromSeed(uint256 _seed) private view returns (ERC20Mock) {
        if (_seed % 2 == 0) {
            console.log("weth", address(weth));
            return weth;
        }
        console.log("wbtc", address(wbtc));
        return wbtc;
    }
}
