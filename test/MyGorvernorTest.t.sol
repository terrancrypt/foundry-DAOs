// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Box} from "../src/Box.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";
import {TimeLock} from "../src/TimeLock.sol";

contract MyGorvernorTest is Test {
    MyGovernor governor;
    Box box;
    GovernanceToken govToken;
    TimeLock timeLock;

    address public USER = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 100 ether;

    uint256 public constant MIN_DELAY = 3600; // 1 hours - after vote passed
    uint256 public constant VOTING_DELAY = 1; // How many blocks till a vote is active
    uint256 public constant VOTING_PERIOD = 50400; // 1 week

    address[] public proposers;
    address[] public executors;

    uint256[] public values;
    bytes[] public calldatas;
    address[] public targets;

    function setUp() public {
        govToken = new GovernanceToken();
        govToken.mint(USER, INITIAL_SUPPLY);

        vm.startPrank(USER);
        govToken.delegate(USER);
        timeLock = new TimeLock(MIN_DELAY, proposers, executors);
        governor = new MyGovernor(govToken, timeLock);

        bytes32 proposerRole = timeLock.PROPOSER_ROLE();
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.TIMELOCK_ADMIN_ROLE();

        timeLock.grantRole(proposerRole, address(governor));
        timeLock.grantRole(executorRole, address(0));
        timeLock.revokeRole(adminRole, msg.sender);
        vm.stopPrank();

        box = new Box();
        box.transferOwnership(address(timeLock));
    }

    function testCanUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.store(1);
    }

    function testGovernaceUpdateBox() public {
        uint256 valueToStore = 888;
        string memory description = "store 1 in box";
        bytes memory encodedFunctionCall = abi.encodeWithSignature(
            "store(uint256)",
            valueToStore
        );
        values.push(0);
        calldatas.push(encodedFunctionCall);
        targets.push(address(box));

        // 1. propose to the DAO
        uint256 proposalID = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        // View the state of the proposal now
        console.log("Proposal state: ", uint256(governor.state(proposalID)));

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        console.log("Proposal state:", uint256(governor.state(proposalID)));

        // 2. Vote
        string memory reason = "Repetition is mother of learning";
        uint8 voteWay = 1; // Yes

        vm.prank(USER);
        governor.castVoteWithReason(proposalID, voteWay, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // 3. Queue the tx
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // 4. Execute
        governor.execute(targets, values, calldatas, descriptionHash);

        console.log("Box value: ", box.getNumber());
        assert(box.getNumber() == valueToStore);
    }
}
