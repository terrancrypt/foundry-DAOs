// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {TimelockController} from "lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";

contract TimeLock is TimelockController {
    // minDelay là thời gian bao lâu người dùng phải đợi để được thi hành proposal
    // proposers là danh sách address có thể đề xuất proposal
    // executors là danh sách address có thể thi hành proposal
    //
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors
    ) TimelockController(minDelay, proposers, executors, msg.sender) {}
}
