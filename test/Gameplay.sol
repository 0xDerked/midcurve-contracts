//SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Midcurve.sol";
import "../src/Merkle.sol";
import "forge-std/console.sol";
import "../src/mocks/BlastMock.sol";

contract Gameplay is Test {
    Midcurve private midcurve;
    uint256 private signerPrivateKey = vm.envUint("SIGNER_KEY");
    address private signer = vm.addr(signerPrivateKey);
    address private gameOwner = vm.addr(420);
    address private contributor = vm.addr(69);

    address private player1 = vm.addr(1);
    address private player2 = vm.addr(2);
    address private player3 = vm.addr(3);
    address private player4 = vm.addr(4);
    address private player5 = vm.addr(5);

    uint256 private constant START = 100;

    /**
        INTERNALS AND SET UP
     */

    function setUp() public {
        BlastMock blastMock = new BlastMock();
        vm.etch(0x4300000000000000000000000000000000000002, address(blastMock).code);
        vm.startPrank(gameOwner);
        midcurve = new Midcurve(gameOwner, contributor);
        vm.stopPrank();
        vm.warp(START);
    }

    function _getMessageHash(address _sender, string memory _message, uint256 _nonce)
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


    /**
        HAPPY PATH TESTS
     */

    function testCreateMerkle() public {
        Merkle m = new Merkle();
        bytes32[] memory leaves = new bytes32[](3);
        leaves[0] = keccak256(bytes.concat(keccak256(abi.encode(player1, 3 ether))));
        leaves[1] = keccak256(bytes.concat(keccak256(abi.encode(player2, 2 ether))));
        leaves[2] = keccak256(bytes.concat(keccak256(abi.encode(player3, 1 ether))));
        bytes32 root = m.getRoot(leaves);

        vm.startPrank(gameOwner);

        //begin game
        midcurve.beginGame();
        //send eth
        vm.deal(address(midcurve), 10 ether);
        //fast forward
        vm.warp(START + 1 days + 1 hours);
        //grade round
        midcurve.gradeRound(root);

        vm.stopPrank();

        bytes32[] memory p1Proof = m.getProof(leaves, 0);
        uint256 p1AvailToClaim = midcurve.availableToClaim(p1Proof, 3 ether, player1);
        assertEq(p1AvailToClaim, 3 ether);

        bytes32[] memory p2Proof = m.getProof(leaves, 1);
        uint256 p2AvailToClaim = midcurve.availableToClaim(p2Proof, 2 ether, player2);
        assertEq(p2AvailToClaim, 2 ether);

        bytes32[] memory p3Proof = m.getProof(leaves, 2);
        uint256 p3AvailToClaim = midcurve.availableToClaim(p3Proof, 1 ether, player3);
        assertEq(p3AvailToClaim, 1 ether);

        vm.prank(player1);
        midcurve.claimWinnings(p1Proof, 3 ether);
        assertEq(player1.balance, 3 ether);
        uint256 p1AvailToClaimAfter = midcurve.availableToClaim(p1Proof, 3 ether, player1);
        assertEq(p1AvailToClaimAfter, 0);


        vm.prank(player2);
        midcurve.claimWinnings(p2Proof, 2 ether);
        assertEq(player2.balance, 2 ether);
        uint256 p2AvailToClaimAfter = midcurve.availableToClaim(p2Proof, 2 ether, player2);
        assertEq(p2AvailToClaimAfter, 0);
    }

    function test_BeginGame() public {
        assertEq(midcurve.expiryTimeAnswer(), 0);
        vm.startPrank(gameOwner);
        midcurve.beginGame();
        assertEq(midcurve.expiryTimeAnswer(), START + 1 days);
        assertEq(START + 91 days, midcurve.expiryTimeClaim());
    }

    function test_SubmitAnswer() public {
        vm.startPrank(gameOwner);
        midcurve.beginGame();
        uint256 ownerBalBefore = address(gameOwner).balance;
        uint256 contributorBalBefore = address(contributor).balance;
        string memory cid = "abc123";
        bytes32 msgHash = _getMessageHash(player3, cid, midcurve.nonces(player3));
        bytes32 ethSignedMsgHash = _getEthSignedMessageHash(msgHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, ethSignedMsgHash);
        bytes memory signature = abi.encodePacked(r,s,v);
        vm.deal(player3, 10 ether);
        vm.startPrank(player3);
        midcurve.submit{value: 0.02 ether}(cid, address(0), signature);
        assertEq(midcurve.uniqueSubmissions(), 1);
        assertEq(address(midcurve).balance, 0.018 ether);
        assertEq(address(gameOwner).balance, ownerBalBefore + 0.001 ether);
        assertEq(address(contributor).balance, contributorBalBefore + 0.001 ether);
    }

    function test_SubmitAnswerWithReferrer() public {
        vm.prank(gameOwner);
        midcurve.beginGame();
        vm.deal(player1, 1 ether);
        bytes32 ethSignedMsgMash = _getEthSignedMessageHash(_getMessageHash(player1, "abc123", midcurve.nonces(player1)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, ethSignedMsgMash);
        bytes memory signature = abi.encodePacked(r,s,v);
        vm.prank(player1);
        midcurve.submit{value: 0.02 ether}("abc123", player2, signature);
        assertEq(midcurve.uniqueSubmissions(), 1);
        assertEq(address(midcurve).balance, 0.018 ether);
        assertEq(address(player2).balance, 0.001 ether);
        assertEq(address(player1).balance, 1 ether - 0.02 ether);
    }

    function test_MultipleSubmits() public {
        vm.prank(gameOwner);
        midcurve.beginGame();

        vm.deal(player1, 1 ether);
        vm.deal(player2, 1 ether);

        bytes32 ethSignedMsgMash = _getEthSignedMessageHash(_getMessageHash(player1, "abc123", midcurve.nonces(player1)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, ethSignedMsgMash);
        bytes memory sig1 = abi.encodePacked(r,s,v);

        ethSignedMsgMash = _getEthSignedMessageHash(_getMessageHash(player2, "abc123", midcurve.nonces(player2)));
        (v, r, s) = vm.sign(signerPrivateKey, ethSignedMsgMash);
        bytes memory sig2 = abi.encodePacked(r,s,v);

        vm.prank(player1);
        midcurve.submit{value: 0.02 ether}("abc123", address(0), sig1);

        assertEq(midcurve.uniqueSubmissions(), 1);
        assertEq(address(midcurve).balance, 0.018 ether);
        assertEq(address(gameOwner).balance, 0.001 ether);
        assertEq(address(contributor).balance, 0.001 ether);

        vm.prank(player2);
        midcurve.submit{value: 0.02 ether}("abc123", player1, sig2);

        assertEq(midcurve.uniqueSubmissions(), 2);
        assertEq(address(midcurve).balance, 0.036 ether);
        assertEq(address(player1).balance, 1 ether - 0.02 ether + 0.001 ether);
        assertEq(address(gameOwner).balance, 0.001 ether + 0.0005 ether);
        assertEq(address(contributor).balance, 0.001 ether + 0.0005 ether);
    }

    function test_Resubmit() public {
        vm.prank(gameOwner);
        midcurve.beginGame();
        vm.deal(player1, 1 ether);
        bytes32 ethSignedMsgMash = _getEthSignedMessageHash(_getMessageHash(player1, "abc123", midcurve.nonces(player1)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, ethSignedMsgMash);
        bytes memory sig1 = abi.encodePacked(r,s,v);
        vm.prank(player1);
        midcurve.submit{value: 0.02 ether}("abc123", address(0), sig1);
        assertEq(midcurve.uniqueSubmissions(), 1);
        assertEq(address(midcurve).balance, 0.018 ether);

        ethSignedMsgMash = _getEthSignedMessageHash(_getMessageHash(player1, "def345", midcurve.nonces(player1)));
        (v, r, s) = vm.sign(signerPrivateKey, ethSignedMsgMash);
        bytes memory sig2 = abi.encodePacked(r,s,v);
        vm.prank(player1);
        midcurve.rebsubmit("def345", sig2);
        assertEq(midcurve.uniqueSubmissions(), 1);
        assertEq(address(midcurve).balance, 0.018 ether);

        (string memory cid, ) = midcurve.secretAnswers(player1);

        assertEq(cid, "def345");
    }

    function test_FullPlay() public {
        //start game
        vm.prank(gameOwner);
        midcurve.beginGame();

        //deal eth to players
        vm.deal(player1, 1 ether);
        vm.deal(player2, 1 ether);
        vm.deal(player3, 1 ether);
        vm.deal(player4, 1 ether);
        vm.deal(player5, 1 ether);

        //get signatures for 5 players
        bytes[] memory signatures = _getSignatures();

        //submit for 5 players
        vm.prank(player1);
        midcurve.submit{value: 0.02 ether}("cid", address(0), signatures[0]);

        assertEq(midcurve.uniqueSubmissions(), 1);
        assertEq(address(midcurve).balance, 0.018 ether);

        vm.prank(player2);
        midcurve.submit{value: 0.02 ether}("cid", player1, signatures[1]);

        assertEq(midcurve.uniqueSubmissions(), 2);
        assertEq(address(midcurve).balance, 0.036 ether);
        assertEq(address(player1).balance, 1 ether - 0.02 ether + 0.001 ether);

        vm.prank(player3);
        midcurve.submit{value: 0.02 ether}("cid", player2, signatures[2]);

        assertEq(midcurve.uniqueSubmissions(), 3);
        assertEq(address(midcurve).balance, 0.054 ether);
        assertEq(address(player2).balance, 1 ether - 0.02 ether + 0.001 ether);


        vm.prank(player4);
        midcurve.submit{value: 0.02 ether}("cid", address(0), signatures[3]);

        assertEq(midcurve.uniqueSubmissions(), 4);
        assertEq(address(midcurve).balance, 0.072 ether);

        vm.prank(player5);
        midcurve.submit{value: 0.02 ether}("cid", address(0), signatures[4]);

        assertEq(midcurve.uniqueSubmissions(), 5);
        assertEq(address(midcurve).balance, 0.09 ether);

        //end game
        vm.warp(START + 1 days + 1 minutes);

        //create merkle tree
        Merkle m = new Merkle();
        bytes32[] memory leaves = new bytes32[](3);
        leaves[0] = keccak256(bytes.concat(keccak256(abi.encode(player1, 0.05 ether))));
        leaves[1] = keccak256(bytes.concat(keccak256(abi.encode(player2, 0.03 ether))));
        leaves[2] = keccak256(bytes.concat(keccak256(abi.encode(player3, 0.01 ether))));
        bytes32 root = m.getRoot(leaves);

        //grade round
        vm.prank(gameOwner);
        midcurve.gradeRound(root);

        //claims and check claims
        assertEq(midcurve.availableToClaim(m.getProof(leaves, 0), 0.05 ether, player1), 0.05 ether);
        assertEq(midcurve.availableToClaim(m.getProof(leaves, 1), 0.03 ether, player2), 0.03 ether);
        assertEq(midcurve.availableToClaim(m.getProof(leaves, 2), 0.01 ether, player3), 0.01 ether);


        //NEED TO USE START PRANK FOR NESTED CALLS, OTHERWISE MSG.SENDER MAY BE DIFFERENT IN CLAIM WINNINGS
        vm.startPrank(player1);
        midcurve.claimWinnings(m.getProof(leaves, 0), 0.05 ether);
        assertEq(player1.balance, 1 ether - 0.02 ether + 0.001 ether + 0.05 ether);
        assertEq(midcurve.availableToClaim(m.getProof(leaves, 0), 0.05 ether, player1), 0);

        vm.startPrank(player2);
        midcurve.claimWinnings(m.getProof(leaves, 1), 0.03 ether);
        assertEq(player2.balance, 1 ether - 0.02 ether + 0.001 ether + 0.03 ether);

        vm.startPrank(player3);
        midcurve.claimWinnings(m.getProof(leaves, 2), 0.01 ether);
        assertEq(player3.balance, 1 ether - 0.02 ether + 0.01 ether);

        assertEq(address(midcurve).balance, 0);
    }

    function _getSignatures() internal view returns(bytes[] memory) {

        bytes[] memory signatures = new bytes[](5);

        for(uint i = 0; i < 5; i++) {
            address player = vm.addr(i+1);
            bytes32 msgHash = _getEthSignedMessageHash(_getMessageHash(player, "cid", midcurve.nonces(player)));
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, msgHash);
            signatures[i] = abi.encodePacked(r,s,v);
        }
        
        return signatures;
    }


    /** 
        REVERSION TESTS
    */


    function test_RevertBeginGame_NotOwner() public {
        vm.expectRevert(OnlyOwner.selector);
        vm.prank(player1);
        midcurve.beginGame();
    }

    function test_RevertGradeRound_NotOwner() public {
        vm.prank(gameOwner);
        midcurve.beginGame();
        vm.warp(START + 1 days + 1 hours);
        bytes32 merkleRoot = keccak256("root");
        vm.expectRevert(OnlyOwner.selector);
        vm.prank(player1);
        midcurve.gradeRound(merkleRoot);
    }

    function test_RevertGradeRound_AnswerTimeInProgress() public {
        vm.prank(gameOwner);
        midcurve.beginGame();
        vm.warp(START + 0.5 days);
        bytes32 merkleRoot = keccak256("root");
        vm.expectRevert(AnswerTimeInProgress.selector);
        vm.prank(gameOwner);
        midcurve.gradeRound(merkleRoot);
    }

    function test_RevertClaimWinnings_MerkleNotVerified() public {
        vm.prank(gameOwner);
        midcurve.beginGame();
        vm.warp(START + 1 days + 1 hours);
        
        //create merkle tree
        Merkle m = new Merkle();
        bytes32[] memory leaves = new bytes32[](3);
        leaves[0] = keccak256(bytes.concat(keccak256(abi.encode(player1, 0.05 ether))));
        leaves[1] = keccak256(bytes.concat(keccak256(abi.encode(player2, 0.03 ether))));
        leaves[2] = keccak256(bytes.concat(keccak256(abi.encode(player3, 0.01 ether))));
        bytes32 root = m.getRoot(leaves);

        //grade round
        vm.prank(gameOwner);
        midcurve.gradeRound(root);

        //try to claim using player 1 merkle with player 2
        bytes32[] memory p1Proof = m.getProof(leaves, 0);
        vm.expectRevert(MerkleNotVerified.selector);
        vm.prank(player2);
        midcurve.claimWinnings(p1Proof, 0.05 ether);

        //try to claim using player 2 merkle with player 5
        bytes32[] memory p2Proof = m.getProof(leaves, 1);
        vm.expectRevert(MerkleNotVerified.selector);
        vm.prank(player5);
        midcurve.claimWinnings(p2Proof, 0.03 ether);
    }

    function test_RevertClaimWinnings_AlreadyClaimed() public {
        vm.prank(gameOwner);
        midcurve.beginGame();
        vm.warp(START + 1 days + 1 hours);
        
        //create merkle tree
        Merkle m = new Merkle();
        bytes32[] memory leaves = new bytes32[](3);
        leaves[0] = keccak256(bytes.concat(keccak256(abi.encode(player1, 0.05 ether))));
        leaves[1] = keccak256(bytes.concat(keccak256(abi.encode(player2, 0.03 ether))));
        leaves[2] = keccak256(bytes.concat(keccak256(abi.encode(player3, 0.01 ether))));
        bytes32 root = m.getRoot(leaves);

        //grade round
        vm.prank(gameOwner);
        midcurve.gradeRound(root);

        vm.deal(address(midcurve), 1 ether);

        //claim winnings
        bytes32[] memory p1Proof = m.getProof(leaves, 0);
        vm.prank(player1);
        midcurve.claimWinnings(p1Proof, 0.05 ether);

        //try to claim again
        vm.expectRevert(AlreadyClaimed.selector);
        vm.prank(player1);
        midcurve.claimWinnings(p1Proof, 0.05 ether);
    }

    function test_RevertSubmitAnswer_GameNotStarted() public {
        vm.startPrank(player1);
        bytes32 msgHash = _getMessageHash(player1, "abc123", midcurve.nonces(player1));
        bytes32 ethSignedMsgHash = _getEthSignedMessageHash(msgHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, ethSignedMsgHash);
        bytes memory signature = abi.encodePacked(r,s,v);
        vm.expectRevert(GameNotStarted.selector);
        midcurve.submit("abc123", address(0), signature);
    }

    function testFuzz_RevertSubmitAnswer_AnswerTimeExpired(uint256 _time) public {
        vm.prank(gameOwner);
        midcurve.beginGame();
        vm.assume(_time < 90 days && START + _time > midcurve.expiryTimeAnswer());
        vm.warp(START + _time);
        bytes32 msgHash = _getMessageHash(player1, "abc123", midcurve.nonces(player1));
        bytes32 ethSignedMsgHash = _getEthSignedMessageHash(msgHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, ethSignedMsgHash);
        bytes memory signature = abi.encodePacked(r,s,v);
        vm.expectRevert(AnswerTimeExpired.selector);
        vm.prank(player1);
        midcurve.submit("abc123", address(0), signature);
    }

    function testFuzz_RevertSubmitAnswer_NotEnoughEth(uint256 _amount) public {
        vm.assume(_amount < 0.02 ether);
        vm.prank(gameOwner);
        midcurve.beginGame();
        vm.deal(player1, 1 ether);
        bytes32 msgHash = _getMessageHash(player1, "abc123", midcurve.nonces(player1));
        bytes32 ethSignedMsgHash = _getEthSignedMessageHash(msgHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, ethSignedMsgHash);
        bytes memory signature = abi.encodePacked(r,s,v);
        vm.expectRevert(WrongEntryPrice.selector);
        vm.prank(player1);
        midcurve.submit{value: _amount}("abc123", address(0), signature);
    }

    function testFuzz_RevertSubmitAnswer_WrongEntryPrice(uint256 _amount) public {
        vm.assume(_amount != 0.02 ether && _amount <= 1 ether);
        vm.prank(gameOwner);
        midcurve.beginGame();
        vm.deal(player1, 1 ether);
        bytes32 msgHash = _getMessageHash(player1, "abc123", midcurve.nonces(player1));
        bytes32 ethSignedMsgHash = _getEthSignedMessageHash(msgHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, ethSignedMsgHash);
        bytes memory signature = abi.encodePacked(r,s,v);
        vm.expectRevert(WrongEntryPrice.selector);
        vm.prank(player1);
        midcurve.submit{value: _amount}("abc123", address(0), signature);
    }

    function testFuzz_RevertSubmitAnswer_InvalidSignature(string calldata _cid) public {
        vm.assume(keccak256(abi.encodePacked(_cid)) != keccak256(abi.encodePacked("abc123")));
        vm.prank(gameOwner);
        midcurve.beginGame();
        vm.deal(player1, 1 ether);
        bytes32 msgHash = _getMessageHash(player1, _cid, midcurve.nonces(player1));
        bytes32 ethSignedMsgHash = _getEthSignedMessageHash(msgHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, ethSignedMsgHash);
        bytes memory signature = abi.encodePacked(r,s,v);
        vm.expectRevert(InvalidSignature.selector);
        vm.prank(player1);
        midcurve.submit{value: 0.02 ether}("abc123", address(0), signature);
    }

    function test_RevertSubmitAnswer_AlreadySubmitted() public {}

    function test_RevertResubmit_NoFirstSubmission() public {}

    function test_RevertResubmit_InvalidSignature() public {}

    function test_RevertResubmit_NotPayable() public {}

}
