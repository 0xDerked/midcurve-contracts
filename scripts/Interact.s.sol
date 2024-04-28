//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../contracts/IMidcurve.sol";

contract ReadScript is Script {
    address payable public constant MIDCURVE = payable(0xe5bF5e3C63F87e71beDFcE684186dd76f3AA9743);
    IMidcurve midcurve = IMidcurve(MIDCURVE);

    function run() external {
        address owner = midcurve.owner();
        console.log("Owner: ", owner);
    }
}