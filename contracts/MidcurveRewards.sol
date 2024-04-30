//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {EthNotSent} from "./MidcurveErrors.sol";

contract MidcurveRewards {
    mapping(address => uint256) public rewardBalance;
    address public defaultReferrer;
    constructor(address _defaultReferrer) {
        defaultReferrer = _defaultReferrer;
    }

    function receiveRewards(address _referrer) external payable {
        if (_referrer != address(0)) {
            rewardBalance[_referrer] += msg.value;
        } else {
            rewardBalance[defaultReferrer] += msg.value;
        }
    }

    function claimRewards() external {
        uint256 amount = rewardBalance[msg.sender];
        rewardBalance[msg.sender] = 0;
        (bool success,) = msg.sender.call{value: amount}("");
        if(!success) revert EthNotSent();
    }

    receive() external payable {
        rewardBalance[defaultReferrer] += msg.value;
    }
}