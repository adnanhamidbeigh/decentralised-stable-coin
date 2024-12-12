// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Invariants: Properties

//1. total dsc should be less than collateral
//2. getter functions should never revert

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {DecentralisedStableCoin} from "src/DecentralisedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract Invariants is StdInvariant, Test {
    DeployDSC deployer;
    DecentralisedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;
    address weth;
    address wbtc;
    Handler handler;

    function setUp() public {
        deployer = new DeployDSC();

        (dsc, engine, config) = deployer.run();
        (,, weth, wbtc,) = config.activeNetworkConfig();
        // BUG DONT INVOKE HANDLER BEFORE SETTING TARGET CONTRACT
        handler = new Handler(engine, dsc);
        targetContract(address(handler));

        // Dont call redeem collateral without collateral
    }

    function invariant_testProtocolMustHaveMoreValueThanDsc() public view {
        // get all the values of all collateral
        // compare it to the debt

        uint256 totalSupply = dsc.totalSupply();

        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(engine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(engine));

        uint256 wethValue = engine.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = engine.getUsdValue(wbtc, totalWbtcDeposited);

        console.log("wethValue", wethValue);
        console.log("wbtcValue", wbtcValue);
        console.log("totalSupply", totalSupply);
        console.log("Times Mint Called", handler.timesMintCalled());
        assert(wethValue + wbtcValue >= totalSupply);
    }

    function invarient_gettersShouldNeverRevert() public view {
        engine.getLiquidationBonus();
        engine.getPrecision();
        engine.getLiquidationThreshold();
        engine.getCollateralTokens();
        engine.getCollateralBalanceOfUser(address(this), weth);
    }
}
