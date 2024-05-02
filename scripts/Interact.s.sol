//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../lib/forge-std/src/Script.sol";
import "../lib/forge-std/src/console.sol";
import "../contracts/IMidcurve.sol";

contract ReadScript is Script {
    address payable public constant MIDCURVE = payable(0xe5bF5e3C63F87e71beDFcE684186dd76f3AA9743);
    IMidcurve midcurve = IMidcurve(MIDCURVE);

    function run() external {
        address owner = midcurve.owner();
        console.log("Owner: ", owner);
    }
}

 contract BeginGame is Script {
    address payable public constant MIDCURVE = payable(0xe5bF5e3C63F87e71beDFcE684186dd76f3AA9743);
    IMidcurve midcurve = IMidcurve(MIDCURVE);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        midcurve.beginGame();
        vm.stopBroadcast();
    }
 }

 