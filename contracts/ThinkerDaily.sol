//SPDX-License-Identifier:MIT
pragma solidity 0.8.15;

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

contract ThinkerDaily {
	
	uint256 public constant TWENTY_HOURS = 72_000;
    uint256 public constant ENTRY_PRICE = 0.05 ether;
	address public immutable owner;
	uint256 public uniqueSubmissions;

	struct SecretAnswer {
		bytes32 hashedAnswer;
		string ipfsCid;
		bool needsRevealed;
		uint256 timestamp;
	}

	struct RevealedAnswer {
		uint256 guess;
		uint256 secret;
		uint256 timestamp;
	}
  
    mapping(address => SecretAnswer) public secretAnswers;
    mapping(address => RevealedAnswer) public revealedAnswers;
    mapping(address => bool) public submitted;
	mapping(address => bool) public claimedWinnings;

    uint256 public expiryTimeAnswer;
	uint256 public expiryTimeReveal;
	bool public gameStarted;
	bytes32 public MERKLE_ROOT;

	bool public feeSet = false;
    address[3] private contributorAddresses;
    uint256[3] private contributorWeights;
    uint256 private protocolFee;

	event AnswerRevealed(address indexed playerAddress, uint256 answer, uint256 secret, uint256 submitted_at);
	event AnswerSubmitted(address indexed playerAddress, bytes32 hashedAnswer, string ipfsCid, bool needsRevealed);


	constructor(address[3] memory _contributorAddresses, address _owner) {
        contributorAddresses[0] = _contributorAddresses[0];
        contributorAddresses[1] = _contributorAddresses[1];
        contributorAddresses[2] = _contributorAddresses[2];
        contributorWeights[0] = 8000;
        contributorWeights[1] = 1500;
        contributorWeights[2] = 500;
		owner = _owner;
    }

	modifier gameInProgress() {
		require(gameStarted, "GIP");
		_;
	}

	modifier onlyOwner {
		require(msg.sender == owner);
		_;
	}


	function beginGame() external onlyOwner {
		require(!gameStarted, "BG:AS");
		gameStarted = true;
		expiryTimeAnswer = block.timestamp + TWENTY_HOURS; 
		expiryTimeReveal = block.timestamp + TWENTY_HOURS + 10_800;
	}

	function submitDirect(bytes32 _hashedAnswer) external payable gameInProgress {
		require(block.timestamp <= expiryTimeAnswer, "SD:SPE");
		require(!submitted[msg.sender] && msg.value >= ENTRY_PRICE, "SD:SUB||ETH");
		SecretAnswer memory secretAnswer = SecretAnswer(_hashedAnswer, "", true, block.timestamp);
		secretAnswers[msg.sender] = secretAnswer;
		unchecked {uniqueSubmissions++;} 
		submitted[msg.sender] = true;
		emit AnswerSubmitted(msg.sender, _hashedAnswer, "", true);
	}

	function resubmitDirect(bytes32 _hashedAnswer) external gameInProgress {
		require(submitted[msg.sender], "RD:!SUB");
		require(block.timestamp <= expiryTimeAnswer, "RD:SPE");
		SecretAnswer memory secretAnswer = SecretAnswer(_hashedAnswer, "", true, block.timestamp);
		secretAnswers[msg.sender] = secretAnswer;
		emit AnswerSubmitted(msg.sender, _hashedAnswer, "", true);
	}

	function submitIPFS(string calldata _ipfsCID) external payable gameInProgress {
		require(block.timestamp <= expiryTimeAnswer, "SI:SPE");
		require(!submitted[msg.sender] && msg.value >= ENTRY_PRICE, "SI:SUB||ETH");
		SecretAnswer memory secretAnswer = SecretAnswer(bytes32(0), _ipfsCID, false, block.timestamp);
		secretAnswers[msg.sender] = secretAnswer;
		unchecked {uniqueSubmissions++;} 
		submitted[msg.sender] = true;
		emit AnswerSubmitted(msg.sender, bytes32(0), _ipfsCID, false);
	}

	function rebsubmitIPFS(string calldata _ipfsCID) external gameInProgress {
		require(submitted[msg.sender], "RI:!SUB");
		require(block.timestamp <= expiryTimeAnswer, "RI:SPE");
		SecretAnswer memory secretAnswer = SecretAnswer(bytes32(0), _ipfsCID, false, block.timestamp);
		secretAnswers[msg.sender] = secretAnswer;
		emit AnswerSubmitted(msg.sender, bytes32(0), _ipfsCID, false);
	}

	function revealAnswer(uint256 _answer, uint256 _secret) external gameInProgress {
		require(block.timestamp <= expiryTimeReveal, "RA:RPE");
		require(block.timestamp > expiryTimeAnswer, "RA:RPNS");
		SecretAnswer memory secretAnswer = secretAnswers[msg.sender];
		require(submitted[msg.sender] && secretAnswer.needsRevealed, "RA:!SUB");
		require(keccak256(abi.encodePacked(_answer, _secret)) == secretAnswer.hashedAnswer, "RA:!HASH");
		RevealedAnswer memory revealedAnswer = RevealedAnswer(_answer, _secret, secretAnswers[msg.sender].timestamp);
		revealedAnswers[msg.sender] = revealedAnswer;
		emit AnswerRevealed(msg.sender, _answer, _secret, revealedAnswer.timestamp);
	}

	function setFee() external onlyOwner gameInProgress {
		require(!feeSet, "SF:SET");
		require(block.timestamp > expiryTimeAnswer, "SF:SPIP");
		protocolFee = address(this).balance *  100 / 1000;
		feeSet = true;
	}

	function gradeRound(bytes32 _merkleRoot) external onlyOwner gameInProgress {
		require(feeSet, "GR:!SF");
		require(block.timestamp > expiryTimeReveal, "GR:RPIP");
		MERKLE_ROOT = _merkleRoot;
	}

	function availableToClaim(bytes32[] calldata _proof, uint256 _amount, address _claimer) external view returns (uint256) {
		bytes32 leaf = keccak256(abi.encodePacked(_claimer, _amount));
		(bool verify,) = MerkleProof.verify(_proof,MERKLE_ROOT, leaf);
		if(verify && !claimedWinnings[_claimer]){
				return _amount;
		}		
		return 0;
	}

	function claimWinnings(bytes32[] calldata _proof, uint256 _amount) external {
		bytes32 leaf = keccak256(abi.encodePacked(msg.sender, _amount));
		(bool verify,) = MerkleProof.verify(_proof, MERKLE_ROOT ,leaf);
        require(verify && !claimedWinnings[msg.sender], "CW:INV");
	    claimedWinnings[msg.sender] = true;
		(bool sent, ) = msg.sender.call{value:_amount}("");
		require(sent, "CW:ETH");
	}

    function withdraw() external onlyOwner {
        uint256 payout = protocolFee;
        for (uint i=0; i<contributorAddresses.length; i++) {
           (bool success, ) = contributorAddresses[i].call{value: payout * contributorWeights[i]/10000}("");
            require(success, "W:ETH");
        }
    }
}