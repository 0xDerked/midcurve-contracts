//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import "../contracts/Midcurve.sol";
import "../contracts/MidcurveTest.sol";

contract DeployMidcurve is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address owner = vm.addr(deployerPrivateKey);
        new Midcurve(owner, 0x6250D780c8415b26cA1ad290F233baeB215f131B);
        vm.stopBroadcast();
    }
}


contract DeployMidcurveTestAndBegin is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address owner = vm.addr(deployerPrivateKey);
        Midcurve midcurve = new Midcurve(owner, 0x6250D780c8415b26cA1ad290F233baeB215f131B);
        midcurve.beginGame();
        vm.stopBroadcast();
    }
}