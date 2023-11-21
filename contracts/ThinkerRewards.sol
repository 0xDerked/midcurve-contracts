//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

contract ThinkerRewards {
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
        require(success, "1");
    }

    receive() external payable {
        rewardBalance[defaultReferrer] += msg.value;
    }
}