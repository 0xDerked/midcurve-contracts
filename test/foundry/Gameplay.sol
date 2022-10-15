pragma solidity 0.8.15;
import "forge-std/Test.sol";
import "../../contracts/ThinkerDaily.sol";

contract Gameplay is Test {

    ThinkerDaily private thinkerDaily;
    address private owner = address(this);
    address private c1 = vm.addr(1);
    address private c2 = vm.addr(2);

    uint256 private constant START = 100;

    function setUp() public {
        thinkerDaily = new ThinkerDaily([owner, c1, c2], owner);
        vm.warp(START);
    }

    function _beginGame() internal {
        thinkerDaily.beginGame();
    }

    function testBeginGame() public {
        assertFalse(thinkerDaily.gameStarted());
        thinkerDaily.beginGame();
        assertTrue(thinkerDaily.gameStarted());
        assertEq(START + 43200, thinkerDaily.expiryTimeAnswer());
        assertEq(START + 86400, thinkerDaily.expiryTimeReveal());
    }

    function testSubmitAnswer() public {
        _beginGame();
        uint256 answer = 42;
        uint256 secret = 1337;
        address user = vm.addr(3);
        vm.deal(user, 10 ether);
        bytes32 hashedAnswer = keccak256(abi.encodePacked(answer, secret));
        assertFalse(thinkerDaily.submitted(user));
        vm.prank(user);
        thinkerDaily.submitAnswer{value: 0.05 ether}(hashedAnswer);
        assertTrue(thinkerDaily.submitted(user));
        assertEq(thinkerDaily.uniqueSubmissions(), 1);
        assertEq(address(thinkerDaily).balance, 0.05 ether);
    }

    function testChangeAnswer() public {
        _beginGame();
        uint256 answer = 42;
        uint256 secret = 1337;
        address user = vm.addr(3);
        vm.deal(user, 10 ether);
        bytes32 hashedAnswer = keccak256(abi.encodePacked(answer, secret));
        vm.prank(user);
        thinkerDaily.submitAnswer{value: 0.05 ether}(hashedAnswer);
        assertEq(thinkerDaily.uniqueSubmissions(), 1);
        uint256 answer2=420;
        bytes32 hashedAnswer2 = keccak256(abi.encodePacked(answer2, secret));
        vm.prank(user);
        thinkerDaily.submitAnswer(hashedAnswer2);
        assertEq(thinkerDaily.uniqueSubmissions(), 1);
        assertEq(address(thinkerDaily).balance, 0.05 ether);
    }

    function testFuzzSubmitAnswer(uint256 _secret, uint256 _answer) public {
        vm.assume(_secret != 0);
        vm.assume(_answer != 0);
        _beginGame();
        address user = vm.addr(3);
        vm.deal(user, 10 ether);
        bytes32 hashedAnswer = keccak256(abi.encodePacked(_answer, _secret));
        assertFalse(thinkerDaily.submitted(user));
        vm.prank(user);
        thinkerDaily.submitAnswer{value: 0.05 ether}(hashedAnswer);
        assertTrue(thinkerDaily.submitted(user));
        assertEq(thinkerDaily.uniqueSubmissions(), 1);
        assertEq(address(thinkerDaily).balance, 0.05 ether);
    }

}