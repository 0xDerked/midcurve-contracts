// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IMidcurve {
    error AlreadyClaimed();
    error AlreadySubmitted();
    error AnswerTimeExpired();
    error AnswerTimeInProgress();
    error ClaimStillInProgress();
    error EthNotSent();
    error FeeAlreadySet();
    error FeeNotSet();
    error GameAlreadyStarted();
    error GameNotStarted();
    error MerkleNotVerified();
    error NoFirstSubmission();
    error OnlyOwner();
    error WrongEntryPrice();

    event AnswerSubmitted(address indexed playerAddress, string cid, uint256 timestamp);

    receive() external payable;

    function ENTRY_PRICE() external view returns (uint256);
    function TWENTY_FOUR_HOURS() external view returns (uint256);
    function availableToClaim(bytes32[] memory _proof, uint256 _amount, address _claimer)
        external
        view
        returns (uint256);
    function beginGame() external;
    function claimWinnings(bytes32[] memory _proof, uint256 _amount) external;
    function claimedProtocolFee() external view returns (bool);
    function claimedWinnings(address) external view returns (bool);
    function expiryTimeAnswer() external view returns (uint256);
    function expiryTimeClaim() external view returns (uint256);
    function gradeRound(bytes32 _merkleRoot) external;
    function merkleRoot() external view returns (bytes32);
    function owner() external view returns (address);
    function protocolFee() external view returns (uint256);
    function rebsubmit(string memory _cid) external;
    function retrieveForfeited() external;
    function rewardsManager() external view returns (address);
    function secretAnswers(address) external view returns (string memory cid, uint256 timestamp);
    function setFee() external;
    function submit(string memory _cid, address _referrer) external payable;
    function uniqueSubmissions() external view returns (uint256);
    function withdraw() external;
}
