//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "../contracts/MidcurveRewards.sol";
import "../contracts/Midcurve.sol";

contract DeployRewards is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address owner = vm.addr(deployerPrivateKey);
        MidcurveRewards midcurveRewards = new MidcurveRewards(owner);
        vm.stopBroadcast();
    }
}

contract DeployMidcurve is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address owner = vm.addr(deployerPrivateKey);
        Midcurve midcurve = new Midcurve(0x21CA2d30B09589Dbb56c20925d2200fbbc97b354, owner);
        vm.stopBroadcast();
    }
}