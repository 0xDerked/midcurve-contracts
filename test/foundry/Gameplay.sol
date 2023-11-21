pragma solidity 0.8.19;
import "forge-std/Test.sol";
import "../../contracts/ThinkerDaily.sol";
import "../../contracts/ThinkerRewards.sol";
import "../../contracts/Merkle.sol";

contract Gameplay is Test {

    ThinkerDaily private thinkerDaily;
    ThinkerRewards private thinkerRewards;
    address private owner = address(this);
    address private gameOwner = vm.addr(420);
    address private player1 = vm.addr(1);
    address private player2 = vm.addr(2);
    address private player3 = vm.addr(3);

    uint256 private constant START = 100;

    function setUp() public {
        vm.startPrank(gameOwner);
        thinkerRewards = new ThinkerRewards(gameOwner);
        thinkerDaily = new ThinkerDaily(address(thinkerRewards));
        vm.stopPrank();
        vm.warp(START);
    }

    function testCreateMerkle() public {
        Merkle m = new Merkle();
        bytes32[] memory leaves = new bytes32[](3);
        leaves[0] = keccak256(abi.encodePacked(player1, uint256(3 ether)));
        leaves[1] = keccak256(abi.encodePacked(player2, uint256(2 ether)));
        leaves[2] = keccak256(abi.encodePacked(player3, uint256(1 ether)));
        bytes32 root = m.getRoot(leaves);

        //begin game
        thinkerDaily.beginGame();
        //send eth
        vm.deal(address(thinkerDaily), 10 ether);
        //fast forward
        vm.warp(START + 90_000);
        //set fee
        thinkerDaily.setFee();

        thinkerDaily.gradeRound(root);

        bytes32[] memory p1Proof = m.getProof(leaves, 0);
        uint256 p1AvailToClaim = thinkerDaily.availableToClaim(p1Proof, 3 ether, player1);
        assertEq(p1AvailToClaim, 3 ether);

        bytes32[] memory p2Proof = m.getProof(leaves, 1);
        uint256 p2AvailToClaim = thinkerDaily.availableToClaim(p2Proof, 2 ether, player2);
        assertEq(p2AvailToClaim, 2 ether);

        bytes32[] memory p3Proof = m.getProof(leaves, 2);
        uint256 p3AvailToClaim = thinkerDaily.availableToClaim(p3Proof, 1 ether, player3);
        assertEq(p3AvailToClaim, 1 ether);

        vm.prank(player1);
        thinkerDaily.claimWinnings(p1Proof, 3 ether);
        assertEq(player1.balance, 3 ether);
        uint256 p1AvailToClaimAfter = thinkerDaily.availableToClaim(p1Proof, 3 ether, player1);
        assertEq(p1AvailToClaimAfter, 0);
    }
    function testBeginGame() public {
        assertFalse(thinkerDaily.gameStarted());
        thinkerDaily.beginGame();
        assertTrue(thinkerDaily.gameStarted());
        assertEq(START + 72_000, thinkerDaily.expiryTimeAnswer());
        assertEq(START + 72_000 + 10_800, thinkerDaily.expiryTimeReveal());
        assertEq(START + 72_000 + 7_776_000, thinkerDaily.expiryTimeClaim()); 
    }

    function testSubmitAnswer() public {
        thinkerDaily.beginGame();
        string memory cid = 'abc123';
        address user = vm.addr(3);
        vm.deal(user, 10 ether);
        assertFalse(thinkerDaily.submitted(user));
        vm.prank(user);
        thinkerDaily.submitClient{value: 0.03 ether}(cid, gameOwner);
        assertTrue(thinkerDaily.submitted(user));
        assertEq(thinkerDaily.uniqueSubmissions(), 1);
        assertEq(address(thinkerDaily).balance, 0.03 ether);
    }

    function testChangeAnswer() public {
        thinkerDaily.beginGame();
        string memory cid = 'abc123';
        address user = vm.addr(3);
        vm.deal(user, 10 ether);
        assertFalse(thinkerDaily.submitted(user));
        vm.prank(user);
        thinkerDaily.submitClient{value: 0.03 ether}(cid);
        assertTrue(thinkerDaily.submitted(user));
        assertEq(thinkerDaily.uniqueSubmissions(), 1);
        assertEq(address(thinkerDaily).balance, 0.03 ether);
        string memory cid2 = "abc124";
        vm.prank(user);
        thinkerDaily.rebsubmitClient(cid2);
        assertTrue(thinkerDaily.submitted(user));
        assertEq(thinkerDaily.uniqueSubmissions(), 1);
        assertEq(address(thinkerDaily).balance, 0.03 ether);
    }

    // function testFuzzSubmitAnswer(uint256 _secret, uint256 _answer) public {
    //     vm.assume(_secret != 0);
    //     vm.assume(_answer != 0);
    //     _beginGame();
    //     address user = vm.addr(3);
    //     vm.deal(user, 10 ether);
    //     bytes32 hashedAnswer = keccak256(abi.encodePacked(_answer, _secret));
    //     assertFalse(thinkerDaily.submitted(user));
    //     vm.prank(user);
    //     thinkerDaily.submitAnswer{value: 0.05 ether}(hashedAnswer);
    //     assertTrue(thinkerDaily.submitted(user));
    //     assertEq(thinkerDaily.uniqueSubmissions(), 1);
    //     assertEq(address(thinkerDaily).balance, 0.05 ether);
    // }

}