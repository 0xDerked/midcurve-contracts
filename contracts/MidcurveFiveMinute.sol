//SPDX-License-Identifier:MIT
pragma solidity 0.8.19;

import './MerkleProof.sol';
import './MidcurveErrors.sol';

interface IMidcurveRewards {
	function receiveRewards(address _referrer) external payable;
}

contract MidcurveFiveMinute {
	
	uint256 public constant FIVE_MINUTES = 300; 
    uint256 public constant ENTRY_PRICE = 0.01 ether;
    address public constant REWARDS_MANAGER = 0x21CA2d30B09589Dbb56c20925d2200fbbc97b354;
	address public immutable owner;
	uint256 public uniqueSubmissions;

	struct SecretAnswer {
		string cid;
		uint256 timestamp;
	}
  
    mapping(address => SecretAnswer) public secretAnswers; 
	mapping(address => bool) public claimedWinnings;

    uint256 public expiryTimeAnswer;
	uint256 public expiryTimeClaim;
	bytes32 public merkleRoot;

	uint256 public protocolFee; 
	bool public claimedProtocolFee;

	event AnswerSubmitted(address indexed playerAddress, string cid, uint256 timestamp);

	modifier gameStarted {
		if(expiryTimeAnswer == 0) revert GameNotStarted();
		_;
	}

	modifier onlyOwner {
		if (msg.sender != owner) revert OnlyOwner();
		_;
	}

	constructor(address _owner) {
		owner = _owner;
    }

	receive() external payable {}

	function beginGame() external onlyOwner {
		if (expiryTimeAnswer > 0) revert GameAlreadyStarted();
		expiryTimeAnswer = block.timestamp + FIVE_MINUTES; 
		expiryTimeClaim = block.timestamp + FIVE_MINUTES + 7_776_000; //90 days
	}

	function submit(string calldata _cid, address _referrer) external payable gameStarted {
		if (block.timestamp > expiryTimeAnswer) revert AnswerTimeExpired();
		if (msg.value != ENTRY_PRICE) revert WrongEntryPrice();

		SecretAnswer storage secretAnswer = secretAnswers[msg.sender];

		if (secretAnswer.timestamp != 0) revert AlreadySubmitted();

		IMidcurveRewards(REWARDS_MANAGER).receiveRewards{value: msg.value * 50 / 1000}(_referrer);
		
		secretAnswer.cid = _cid;
		secretAnswer.timestamp = block.timestamp;

		unchecked {uniqueSubmissions++;} 
		emit AnswerSubmitted(msg.sender, _cid, block.timestamp);
	}

	function rebsubmit(string calldata _cid) external gameStarted {
		SecretAnswer storage secretAnswer = secretAnswers[msg.sender];

		if (secretAnswer.timestamp == 0) revert NoFirstSubmission();
		if (block.timestamp > expiryTimeAnswer) revert AnswerTimeExpired();

 		secretAnswer.cid = _cid;
		secretAnswer.timestamp = block.timestamp;
		emit AnswerSubmitted(msg.sender, _cid, block.timestamp);
	}

	function setFee() external onlyOwner gameStarted {
		if (protocolFee > 0) revert FeeAlreadySet();
		if (block.timestamp <= expiryTimeAnswer) revert AnswerTimeInProgress();
		protocolFee = address(this).balance *  50 / 1000;
	}

	function gradeRound(bytes32 _merkleRoot) external onlyOwner gameStarted {
		if(protocolFee == 0) revert FeeNotSet();
		if (block.timestamp <= expiryTimeAnswer) revert AnswerTimeInProgress();
		merkleRoot = _merkleRoot;
	}

	function claimWinnings(bytes32[] calldata _proof, uint256 _amount) external {
		bytes32 leaf = keccak256(abi.encodePacked(msg.sender, _amount));
		(bool verify,) = MerkleProof.verify(_proof, merkleRoot ,leaf);
		if(!verify) revert MerkleNotVerified();
		if (claimedWinnings[msg.sender]) revert AlreadyClaimed();
	    claimedWinnings[msg.sender] = true;
		(bool success, ) = msg.sender.call{value:_amount}("");
		if(!success) revert EthNotSent();
	}

    function withdraw() external onlyOwner {
		if (claimedProtocolFee) revert AlreadyClaimed();
		if(protocolFee == 0) revert FeeNotSet();
		claimedProtocolFee = true;
    	(bool success, ) = owner.call{value: protocolFee}("");
        if(!success) revert EthNotSent();
    }

	function retrieveForfeited() external onlyOwner {
		if (block.timestamp <= expiryTimeClaim) revert ClaimStillInProgress();
		(bool success, ) = owner.call{value: address(this).balance}("");
		if(!success) revert EthNotSent();
	}

	function availableToClaim(bytes32[] calldata _proof, uint256 _amount, address _claimer) external view returns (uint256) {
		bytes32 leaf = keccak256(abi.encodePacked(_claimer, _amount));
		(bool verify,) = MerkleProof.verify(_proof,merkleRoot, leaf);
		if(verify && !claimedWinnings[_claimer]){
				return _amount;
		}		
		return 0;
	}
}
	