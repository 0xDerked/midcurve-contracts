// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IMidcurve {
    error AlreadyClaimed();
    error AlreadySubmitted();
    error AnswerTimeExpired();
    error AnswerTimeInProgress();
    error ClaimStillInProgress();
    error EthNotSent();
    error GameAlreadyStarted();
    error GameNotStarted();
    error InvalidSignature();
    error MerkleNotVerified();
    error NoFirstSubmission();
    error OnlyOwner();
    error WrongEntryPrice();

    event AnswerSubmitted(address indexed playerAddress, string cid, uint256 timestamp);

    receive() external payable;

    function ENTRY_PRICE() external view returns (uint256);
    function FIVE_PERCENT() external view returns (uint256);
    function TWO_HALF_PERCENT() external view returns (uint256);
    function availableToClaim(bytes32[] memory _proof, uint256 _amount, address _claimer)
        external
        view
        returns (uint256);
    function beginGame() external;
    function claimAllGas() external;
    function claimAllYield() external;
    function claimWinnings(bytes32[] memory _proof, uint256 _amount) external;
    function claimedWinnings(address) external view returns (bool);
    function contributor() external view returns (address);
    function expiryTimeAnswer() external view returns (uint256);
    function expiryTimeClaim() external view returns (uint256);
    function gradeRound(bytes32 _merkleRoot) external;
    function merkleRoot() external view returns (bytes32);
    function nonces(address) external view returns (uint256);
    function owner() external view returns (address);
    function rebsubmit(string memory _cid, bytes memory _signature) external;
    function retrieveForfeited() external;
    function secretAnswers(address) external view returns (string memory cid, uint256 timestamp);
    function submit(string memory _cid, address _referrer, bytes memory _signature) external payable;
    function uniqueSubmissions() external view returns (uint256);
}
