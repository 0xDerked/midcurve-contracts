pragma solidity 0.8.19;
import "forge-std/Test.sol";
import "../contracts/Midcurve.sol";
import "../contracts/MidcurveRewards.sol";
import "../contracts/Merkle.sol";

contract Gameplay is Test {

    Midcurve private midcurve;
    MidcurveRewards private midcurveRewards;
    address private owner = address(this);
    address private gameOwner = vm.addr(420);
    address private player1 = vm.addr(1);
    address private player2 = vm.addr(2);
    address private player3 = vm.addr(3);

    uint256 private constant START = 100;

    function setUp() public {
        vm.startPrank(gameOwner);
        midcurveRewards = new MidcurveRewards(gameOwner);
        midcurve = new Midcurve(address(midcurveRewards), gameOwner);
        vm.stopPrank();
        vm.warp(START);
    }

    // function testCreateMerkle() public {
    //     Merkle m = new Merkle();
    //     bytes32[] memory leaves = new bytes32[](3);
    //     leaves[0] = keccak256(abi.encodePacked(player1, uint256(3 ether)));
    //     leaves[1] = keccak256(abi.encodePacked(player2, uint256(2 ether)));
    //     leaves[2] = keccak256(abi.encodePacked(player3, uint256(1 ether)));
    //     bytes32 root = m.getRoot(leaves);

    //     //begin game
    //     midcurve.beginGame();
    //     //send eth
    //     vm.deal(address(midcurve), 10 ether);
    //     //fast forward
    //     vm.warp(START + 90_000);
    //     //set fee
    //     midcurve.setFee();

    //     midcurve.gradeRound(root);

    //     bytes32[] memory p1Proof = m.getProof(leaves, 0);
    //     uint256 p1AvailToClaim = midcurve.availableToClaim(p1Proof, 3 ether, player1);
    //     assertEq(p1AvailToClaim, 3 ether);

    //     bytes32[] memory p2Proof = m.getProof(leaves, 1);
    //     uint256 p2AvailToClaim = midcurve.availableToClaim(p2Proof, 2 ether, player2);
    //     assertEq(p2AvailToClaim, 2 ether);

    //     bytes32[] memory p3Proof = m.getProof(leaves, 2);
    //     uint256 p3AvailToClaim = midcurve.availableToClaim(p3Proof, 1 ether, player3);
    //     assertEq(p3AvailToClaim, 1 ether);

    //     vm.prank(player1);
    //     midcurve.claimWinnings(p1Proof, 3 ether);
    //     assertEq(player1.balance, 3 ether);
    //     uint256 p1AvailToClaimAfter = midcurve.availableToClaim(p1Proof, 3 ether, player1);
    //     assertEq(p1AvailToClaimAfter, 0);
    // }

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
        string memory cid = 'abc123';
        vm.deal(player3, 10 ether);
        vm.startPrank(player3);
        midcurve.submit{value: 0.02 ether}(cid, gameOwner);
        assertEq(midcurve.uniqueSubmissions(), 1);
        assertEq(address(midcurve).balance, 0.019 ether);
        assertEq(midcurveRewards.rewardBalance(gameOwner), 0.001 ether);
    }

    // function testChangeAnswer() public {
    //     midcurve.beginGame();
    //     string memory cid = 'abc123';
    //     address user = vm.addr(3);
    //     vm.deal(user, 10 ether);
    //     assertFalse(midcurve.submitted(user));
    //     vm.prank(user);
    //     midcurve.submitClient{value: 0.03 ether}(cid);
    //     assertTrue(midcurve.submitted(user));
    //     assertEq(midcurve.uniqueSubmissions(), 1);
    //     assertEq(address(midcurve).balance, 0.03 ether);
    //     string memory cid2 = "abc124";
    //     vm.prank(user);
    //     midcurve.rebsubmitClient(cid2);
    //     assertTrue(midcurve.submitted(user));
    //     assertEq(midcurve.uniqueSubmissions(), 1);
    //     assertEq(address(midcurve).balance, 0.03 ether);
    // }

    // function testFuzzSubmitAnswer(uint256 _secret, uint256 _answer) public {
    //     vm.assume(_secret != 0);
    //     vm.assume(_answer != 0);
    //     _beginGame();
    //     address user = vm.addr(3);
    //     vm.deal(user, 10 ether);
    //     bytes32 hashedAnswer = keccak256(abi.encodePacked(_answer, _secret));
    //     assertFalse(midcurve.submitted(user));
    //     vm.prank(user);
    //     midcurve.submitAnswer{value: 0.05 ether}(hashedAnswer);
    //     assertTrue(midcurve.submitted(user));
    //     assertEq(midcurve.uniqueSubmissions(), 1);
    //     assertEq(address(midcurve).balance, 0.05 ether);
    // }

}