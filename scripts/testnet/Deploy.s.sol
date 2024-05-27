//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import "../../src/testnet/MidcurveSepolia.sol";
import "../../src/mocks/BlastMock.sol";

contract DeployMidcurveTestAndBegin is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        BlastMock blastMock = new BlastMock();
        vm.etch(0x4300000000000000000000000000000000000002, address(blastMock).code);
        vm.startBroadcast(deployerPrivateKey);
        address owner = vm.addr(deployerPrivateKey);
        MidcurveSepolia midcurve = new MidcurveSepolia(owner, 0x6250D780c8415b26cA1ad290F233baeB215f131B);
        midcurve.beginGame();
    }
}