//SPDX-License-Identifier:MIT
pragma solidity 0.8.19;

import './MerkleProof.sol';

/*
  _____ _     _       _               ____        _ _       
 |_   _| |__ (_)_ __ | | _____ _ __  |  _ \  __ _(_) |_   _ 
   | | | '_ \| | '_ \| |/ / _ \ '__| | | | |/ _` | | | | | |
   | | | | | | | | | |   <  __/ |    | |_| | (_| | | | |_| |
   |_| |_| |_|_|_| |_|_|\_\___|_|    |____/ \__,_|_|_|\__, |
                                                      |___/ 

	Date:
	Question:  
*/

interface IThinkerRewards {
	function receiveRewards(address _referrer) external payable;
}

contract ThinkerDaily {
	
	uint256 public constant TWENTY_THREE_HOURS = 82_800; 
    uint256 public constant ENTRY_PRICE = 0.03 ether;
	address public immutable owner;
	address public immutable rewardsManager;
	uint256 public uniqueSubmissions;

	struct SecretAnswer {
		bytes32 hashedAnswer;
		string cid;
		bool needsRevealed;
		uint256 timestamp;
	}

	struct RevealedAnswer {
		uint256 guess;
		string secret;
		uint256 timestamp;
	}
  
    mapping(address => SecretAnswer) public secretAnswers;
    mapping(address => RevealedAnswer) public revealedAnswers;
    mapping(address => bool) public submitted;
	mapping(address => bool) public claimedWinnings;

    uint256 public expiryTimeAnswer;
	uint256 public expiryTimeReveal;
	uint256 public expiryTimeClaim;
	bool public gameStarted;
	bytes32 public MERKLE_ROOT;

	bool public feeSet = false;
    uint256 private protocolFee;

	error OnlyOwner();
	error GameNotStarted();
	error GameAlreadyStarted();
	error AnswerTimeExpired();
	error AnswerTimeInProgress();
	error RevealTimeExpired();
	error RevealTimeNotStarted();
	error RevealTimeInProgress();
	error WrongEntryPrice();
	error AlreadySubmitted();
	error NoFirstSubmission();
	error EthNotSent();
	error MerkleNotVerified();
	error AlreadyClaimed();
	error DoesNotNeedRevealed();
	error CannotMatchHash();
	error FeeNotSet();
	error FeeAlreadySet();

	event AnswerRevealed(address indexed playerAddress, uint256 answer, string secret, uint256 submitted_at);
	event AnswerSubmitted(address indexed playerAddress, bytes32 hashedAnswer, string ipfsCid, bool needsRevealed);


	constructor(address _rewardsManager) {
		owner = msg.sender;
		rewardsManager = _rewardsManager;
    }

	modifier gameInProgress() {
		if(!gameStarted) revert GameNotStarted();
		_;
	}

	modifier onlyOwner {
		if (msg.sender != owner) revert OnlyOwner();
		_;
	}


	function beginGame() external onlyOwner {
		if (gameStarted) revert GameAlreadyStarted();
		gameStarted = true;
		expiryTimeAnswer = block.timestamp + TWENTY_THREE_HOURS; 
		expiryTimeReveal = block.timestamp + TWENTY_THREE_HOURS + 10_800;
		expiryTimeClaim = block.timestamp + TWENTY_THREE_HOURS + 7_776_000; //90 days
	}

	function submitDirect(bytes32 _hashedAnswer) external payable gameInProgress {
		if (block.timestamp > expiryTimeAnswer) revert AnswerTimeExpired();
		if (msg.value != ENTRY_PRICE) revert WrongEntryPrice();
		if (submitted[msg.sender]) revert AlreadySubmitted();

		IThinkerRewards(rewardsManager).receiveRewards{value: msg.value * 50 / 1000}(address(0));
		secretAnswers[msg.sender] = SecretAnswer(_hashedAnswer, "", true, block.timestamp);
		unchecked {uniqueSubmissions++;} 
		submitted[msg.sender] = true;
		emit AnswerSubmitted(msg.sender, _hashedAnswer, "", true);
	}

	function resubmitDirect(bytes32 _hashedAnswer) external gameInProgress {
		if (!submitted[msg.sender]) revert NoFirstSubmission();
		if (block.timestamp > expiryTimeAnswer) revert AnswerTimeExpired();

		secretAnswers[msg.sender] = SecretAnswer(_hashedAnswer, "", true, block.timestamp);
		emit AnswerSubmitted(msg.sender, _hashedAnswer, "", true);
	}

	function submitClient(string calldata _cid, address _referrer) external payable gameInProgress {
		if (block.timestamp > expiryTimeAnswer) revert AnswerTimeExpired();
		if (msg.value != ENTRY_PRICE) revert WrongEntryPrice();
		if (submitted[msg.sender]) revert AlreadySubmitted();

		IThinkerRewards(rewardsManager).receiveRewards{value: msg.value * 50 / 1000}(_referrer);
		secretAnswers[msg.sender] = SecretAnswer(bytes32(0), _cid, false, block.timestamp);
		unchecked {uniqueSubmissions++;} 
		submitted[msg.sender] = true;
		emit AnswerSubmitted(msg.sender, bytes32(0), _cid, false);
	}

	function rebsubmitClient(string calldata _cid) external gameInProgress {
		if (!submitted[msg.sender]) revert NoFirstSubmission();
		if (block.timestamp > expiryTimeAnswer) revert AnswerTimeExpired();

 		secretAnswers[msg.sender] = SecretAnswer(bytes32(0), _cid, false, block.timestamp);
		emit AnswerSubmitted(msg.sender, bytes32(0), _cid, false);
	}

	function revealAnswer(uint256 _answer, string calldata _secret) external gameInProgress {
		if (block.timestamp > expiryTimeReveal) revert RevealTimeExpired();
		if (block.timestamp <= expiryTimeAnswer) revert RevealTimeNotStarted();
		SecretAnswer memory secretAnswer = secretAnswers[msg.sender];
		if (!submitted[msg.sender]) revert NoFirstSubmission();
		if (!secretAnswer.needsRevealed) revert DoesNotNeedRevealed();
		if (!(keccak256(abi.encodePacked(_answer, _secret)) == secretAnswer.hashedAnswer)) revert CannotMatchHash();
		RevealedAnswer memory revealedAnswer = RevealedAnswer(_answer, _secret, secretAnswers[msg.sender].timestamp);
		revealedAnswers[msg.sender] = revealedAnswer;
		emit AnswerRevealed(msg.sender, _answer, _secret, revealedAnswer.timestamp);
	}

	function setFee() external onlyOwner gameInProgress {
		if (feeSet) revert FeeAlreadySet();
		if (block.timestamp <= expiryTimeAnswer) revert RevealTimeNotStarted();
		protocolFee = address(this).balance *  50 / 1000;
		feeSet = true;
	}

	function gradeRound(bytes32 _merkleRoot) external onlyOwner gameInProgress {
		if(!feeSet) revert FeeNotSet();
		if (block.timestamp <= expiryTimeReveal) revert RevealTimeInProgress();
		MERKLE_ROOT = _merkleRoot;
	}

	function claimWinnings(bytes32[] calldata _proof, uint256 _amount) external {
		bytes32 leaf = keccak256(abi.encodePacked(msg.sender, _amount));
		(bool verify,) = MerkleProof.verify(_proof, MERKLE_ROOT ,leaf);
		if(!verify) revert MerkleNotVerified();
		if (claimedWinnings[msg.sender]) revert AlreadyClaimed();
	    claimedWinnings[msg.sender] = true;
		(bool success, ) = msg.sender.call{value:_amount}("");
		if(!success) revert EthNotSent();
	}

    function withdraw() external onlyOwner {
    	(bool success, ) = owner.call{value: protocolFee}("");
        require(success, "W:ETH");
    }

	function retrieveForfeited() external onlyOwner {
		require (block.timestamp > expiryTimeClaim, "RF:CIP");
		(bool success, ) = owner.call{value: address(this).balance}("");
		require(success, "RF:ETH");
	}

	function availableToClaim(bytes32[] calldata _proof, uint256 _amount, address _claimer) external view returns (uint256) {
		bytes32 leaf = keccak256(abi.encodePacked(_claimer, _amount));
		(bool verify,) = MerkleProof.verify(_proof,MERKLE_ROOT, leaf);
		if(verify && !claimedWinnings[_claimer]){
				return _amount;
		}		
		return 0;
	}

	receive() external payable {}
}