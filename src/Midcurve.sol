//SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./MidcurveErrors.sol";

interface IBlast {
    function configureClaimableYield() external;
    function configureClaimableGas() external;
    function claimAllYield(address contractAddress, address recipientOfYield) external returns (uint256);
    function claimAllGas(address contractAddress, address recipientOfGas) external returns (uint256);
}

contract Midcurve {
    address private constant BLAST = 0x4300000000000000000000000000000000000002;
    address private constant SIGNER = 0x2B8274C301E7e1aAE6c160859f27867F94da6E8f;

    uint256 public constant ENTRY_PRICE = 0.02 ether;
    uint256 private constant FIVE_PERCENT = 0.001 ether;
    uint256 private constant TWO_HALF_PERCENT = 0.0005 ether;

    address private immutable owner;
    address private immutable contributor;

    uint256 public uniqueSubmissions;

    struct SecretAnswer {
        string cid;
        uint256 timestamp;
    }

    mapping(address => SecretAnswer) public secretAnswers;
    mapping(address => bool) public claimedWinnings;
    mapping(address => uint256) public nonces;

    uint256 public expiryTimeAnswer;
    uint256 public expiryTimeClaim;
    bytes32 public merkleRoot;

    event AnswerSubmitted(address indexed playerAddress, string cid, uint256 timestamp);

    modifier gameStarted() {
        if (expiryTimeAnswer == 0) revert GameNotStarted();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    constructor(address _owner, address _contributor) {
        owner = _owner;
        contributor = _contributor;
        IBlast(BLAST).configureClaimableYield();
        IBlast(BLAST).configureClaimableGas();
    }

    receive() external payable {}

    function beginGame() external onlyOwner {
        if (expiryTimeAnswer > 0) revert GameAlreadyStarted();
        expiryTimeAnswer = block.timestamp + 1 days;
        expiryTimeClaim = block.timestamp + 91 days;
    }

    function submit(string calldata _cid, address _referrer, bytes memory _signature) external payable gameStarted {
        if (block.timestamp > expiryTimeAnswer) revert AnswerTimeExpired();
        if (msg.value != ENTRY_PRICE) revert WrongEntryPrice();

        if(!_verifySig(msg.sender, _cid, nonces[msg.sender], _signature)) revert InvalidSignature();

        SecretAnswer storage secretAnswer = secretAnswers[msg.sender];

        if (secretAnswer.timestamp != 0) revert AlreadySubmitted();

        if (_referrer != address(0)) {
            _sendEth(_referrer, FIVE_PERCENT);
            _sendEth(contributor, TWO_HALF_PERCENT);
            _sendEth(owner, TWO_HALF_PERCENT);
        } else {
            _sendEth(contributor, FIVE_PERCENT);
            _sendEth(owner, FIVE_PERCENT);
        }

        secretAnswer.cid = _cid;
        secretAnswer.timestamp = block.timestamp;

        unchecked {
            uniqueSubmissions++;
            nonces[msg.sender]++;
        }
        emit AnswerSubmitted(msg.sender, _cid, block.timestamp);
    }

    function rebsubmit(string calldata _cid,  bytes memory _signature) external gameStarted {
        SecretAnswer storage secretAnswer = secretAnswers[msg.sender];

        if (secretAnswer.timestamp == 0) revert NoFirstSubmission();
        if (block.timestamp > expiryTimeAnswer) revert AnswerTimeExpired();

        if(!_verifySig(msg.sender, _cid, nonces[msg.sender], _signature)) revert InvalidSignature();

        unchecked {
            nonces[msg.sender]++;
        }

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
        if(!MerkleProof.verify(_proof, merkleRoot, leaf)) revert MerkleNotVerified();
        if (claimedWinnings[msg.sender]) revert AlreadyClaimed();
        claimedWinnings[msg.sender] = true;
        _sendEth(msg.sender, _amount);
    }

    function availableToClaim(bytes32[] calldata _proof, uint256 _amount, address _claimer)
        external
        view
        returns (uint256)
    {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(_claimer, _amount))));
        if (MerkleProof.verify(_proof, merkleRoot, leaf) && !claimedWinnings[_claimer]) {
            return _amount;
        }
        return 0;
    }

    function retrieveForfeited() external onlyOwner {
        if (block.timestamp <= expiryTimeClaim) revert ClaimStillInProgress();
        _sendEth(owner, address(this).balance);
    }

    function claimAllYield() external onlyOwner {
        IBlast(BLAST).claimAllYield(address(this), owner);
    }

    function claimAllGas() external onlyOwner {
        IBlast(BLAST).claimAllGas(address(this), owner);
    }

    function _getMessageHash(address _sender, string calldata _message, uint256 _nonce)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_sender, _message, _nonce));
    }

    function _getEthSignedMessageHash(bytes32 _messageHash) internal pure returns (bytes32) {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash));
    }

    function _verifySig(address _sender, string calldata _cid, uint256 _nonce, bytes memory _signature)
        internal
        pure
        returns (bool)
    {
        return _recoverSigner(_getEthSignedMessageHash(_getMessageHash(_sender, _cid, _nonce)), _signature) == SIGNER;
    }

    function _splitSig(bytes memory _signature) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(_signature.length == 65, "Invalid signature length");
        assembly {
            r := mload(add(_signature, 32))
            s := mload(add(_signature, 64))
            v := byte(0, mload(add(_signature, 96)))
        }
    }

    function _recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = _splitSig(_signature);
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function _sendEth(address _to, uint256 _amount) internal {
        (bool success,) = _to.call{value: _amount}("");
        if (!success) revert EthNotSent();
    }

    function answerTimeExpired() external view returns (bool) {
        return block.timestamp > expiryTimeAnswer;
    }
}
