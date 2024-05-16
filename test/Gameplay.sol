//SPDX-License-Identifier:MIT
pragma solidity 0.8.20;
import "../lib/forge-std/src/Test.sol";
import "../contracts/Midcurve.sol";
import "../contracts/Merkle.sol";
import "../lib/forge-std/src/console.sol";

contract Gameplay is Test {

    Midcurve private midcurve;
    address private owner = address(this);
    address private gameOwner = vm.addr(420);
    address private contributor = vm.addr(69);
    address private player1 = vm.addr(1);
    address private player2 = vm.addr(2);
    address private player3 = vm.addr(3);

    uint256 private constant START = 100;

    function setUp() public {
        vm.startPrank(gameOwner);
        midcurve = new Midcurve(gameOwner, contributor);
        vm.stopPrank();
        vm.warp(START);
    }

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
        vm.warp(START + 90_000);
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

        uint256 val = 200;
        bytes32 hashTest = keccak256(abi.encodePacked(0x70997970C51812dc3A010C7d01b50e0d17dc79C8, val));
        console.logBytes32(hashTest);        
    }

    function test_BeginGame() public {
        assertEq(midcurve.expiryTimeAnswer(), 0);
        vm.startPrank(gameOwner);
        midcurve.beginGame();
        assertEq(midcurve.expiryTimeAnswer(), 86_500);
        assertEq(START + 86_400 + 7_776_000, midcurve.expiryTimeClaim()); 
    }

    function test_SubmitAnswer() public {
        vm.startPrank(gameOwner);
        midcurve.beginGame();
        uint256 ownerBalBefore = address(gameOwner).balance;
        console.log(ownerBalBefore);
        uint256 contributorBalBefore = address(contributor).balance;
        string memory cid = 'abc123';
        vm.deal(player3, 10 ether);
        vm.startPrank(player3);
        midcurve.submit{value: 0.02 ether}(cid, address(0));
        assertEq(midcurve.uniqueSubmissions(), 1);
        assertEq(address(midcurve).balance, 0.018 ether);
        assertEq(address(gameOwner).balance, ownerBalBefore + 0.001 ether);
        assertEq(address(contributor).balance, contributorBalBefore + 0.001 ether);
    }

    function testFail_SubmitAnswer() public {
        vm.startPrank(gameOwner);
        midcurve.beginGame();
        string memory cid = 'abc123';
        vm.deal(player3, 10 ether);
        vm.startPrank(player3);
        midcurve.submit{value: 0.01 ether}(cid, gameOwner);
        assertEq(midcurve.uniqueSubmissions(), 0);
        assertEq(address(midcurve).balance, 0);
    }
}