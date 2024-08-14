// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
contract TaskRegistry {
    struct TaskContractInfo {
        address owner;
        address taskContract;
    }

    mapping(address => TaskContractInfo) public taskContracts;

    event TaskContractRegistered(address indexed taskContract, address indexed owner);
    
    function registerTaskContract(address task, address owner) external {
        require(task != address(0), "Invalid task contract address");
        require(owner != address(0), "Invalid owner address");
        require(taskContracts[task].taskContract == address(0), "Task contract already registered");

        taskContracts[task] = TaskContractInfo({
            owner: owner,
            taskContract: task
        });

        emit TaskContractRegistered(task, owner);
    }
}
