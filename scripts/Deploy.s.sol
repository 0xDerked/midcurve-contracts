//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "../contracts/MidcurveRewards.sol";

contract DeployScript is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);
        MidcurveRewards midcurveRewards = new MidcurveRewards(vm.addr(420));
        vm.stopBroadcast();
    }
}