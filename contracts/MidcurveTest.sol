//SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import '../lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol';
import './MidcurveErrors.sol';

contract MidcurveTest {
	
	uint256 public constant TWENTY_FOUR_HOURS = 86_400; 
    uint256 public constant ENTRY_PRICE = 0.02 ether;
	uint256 public constant CONTRIBUTOR_FEE = 0.0005 ether;
	uint256 public constant REFERRAL_FEE = 0.001 ether;

	address public immutable owner;
	address public immutable contributor;

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

	event AnswerSubmitted(address indexed playerAddress, string cid, uint256 timestamp);

	modifier gameStarted {
		if(expiryTimeAnswer == 0) revert GameNotStarted();
		_;
	}

	modifier onlyOwner {
		if (msg.sender != owner) revert OnlyOwner();
		_;
	}

	constructor(address _owner, address _contributor) {
		owner = _owner;
		contributor = _contributor;
    }

	receive() external payable {}

	function beginGame() external onlyOwner {
		if (expiryTimeAnswer > 0) revert GameAlreadyStarted();
		expiryTimeAnswer = block.timestamp + 7_776_000;  //test only
		expiryTimeClaim = block.timestamp + TWENTY_FOUR_HOURS + 7_776_000; //90 days
	}

	function submit(string calldata _cid, address _referrer) external payable gameStarted {
		if (block.timestamp > expiryTimeAnswer) revert AnswerTimeExpired();
		if (msg.value != ENTRY_PRICE) revert WrongEntryPrice();

		SecretAnswer storage secretAnswer = secretAnswers[msg.sender];

		if (secretAnswer.timestamp != 0) revert AlreadySubmitted();

		if (_referrer != address(0)) {
			(bool refEth, ) = _referrer.call{value: REFERRAL_FEE}("");
			if(!refEth) revert EthNotSent();
			
			(bool contEth, ) = contributor.call{value: CONTRIBUTOR_FEE}("");
			if(!contEth) revert EthNotSent();

			(bool ownEth, ) = owner.call{value: CONTRIBUTOR_FEE}("");
			if(!ownEth) revert EthNotSent();
		} else {
			(bool contEth, ) = contributor.call{value: REFERRAL_FEE}("");
			if(!contEth) revert EthNotSent();

			(bool ownEth, ) = owner.call{value: REFERRAL_FEE}("");
			if(!ownEth) revert EthNotSent();
		}
		
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

	function gradeRound(bytes32 _merkleRoot) external onlyOwner gameStarted {
		if (block.timestamp <= expiryTimeAnswer) revert AnswerTimeInProgress();
		merkleRoot = _merkleRoot;
	}

	function claimWinnings(bytes32[] calldata _proof, uint256 _amount) external {
		bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, _amount))));
		bool verify = MerkleProof.verify(_proof, merkleRoot ,leaf);
		if(!verify) revert MerkleNotVerified();
		if (claimedWinnings[msg.sender]) revert AlreadyClaimed();
	    claimedWinnings[msg.sender] = true;
		(bool success, ) = msg.sender.call{value:_amount}("");
		if(!success) revert EthNotSent();
	}

	function retrieveForfeited() external onlyOwner {
		if (block.timestamp <= expiryTimeClaim) revert ClaimStillInProgress();
		(bool success, ) = owner.call{value: address(this).balance}("");
		if(!success) revert EthNotSent();
	}

	function availableToClaim(bytes32[] calldata _proof, uint256 _amount, address _claimer) external view returns (uint256) {
		bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(_claimer, _amount))));
		bool verify = MerkleProof.verify(_proof,merkleRoot, leaf);
		if(verify && !claimedWinnings[_claimer]){
				return _amount;
		}		
		return 0;
	}
}
	