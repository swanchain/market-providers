// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ECPTask {
    // Task properties structure
    struct TaskInfo {
        uint taskID;
        uint taskType;
        uint resourceType;
        string inputParam;
        string verifyParam;
        address cpAccount;
        string proof;
        uint deadline;
        address taskRegistryContract;
        string checkCode;
        address owner;
        string version;
    }

    // Task properties
    TaskInfo public taskInfo;
    string public constant version = "3.0";

    // Event to log registration
    event RegisteredToTaskRegistry(address indexed taskContract, address indexed owner);
    event TaskCreated(uint taskID, address cpAccount, string inputParam, uint deadline, string checkCode);

    // Constructor to initialize the task properties and register the task contract
    constructor(
        uint _taskID,
        uint _taskType,
        uint _resourceType,
        string memory _inputParam,
        string memory _verifyParam,
        address _cpAccount,
        string memory _proof,
        uint _deadline,
        address _taskRegistryContract,
        string memory _checkCode
    ) {
        require(_taskID > 0, "Task ID must be greater than zero");
        require(_taskType > 0, "Task type must be greater than zero");
        require(_resourceType >= 0, "Resource type must be greater than or equal to zero");
        require(bytes(_inputParam).length > 0, "Input param must be provided");
        require(_cpAccount != address(0), "CP account address must be provided");
        require(_deadline > block.number, "Deadline must be in the future");
        require(_taskRegistryContract != address(0), "Task registry contract address must be provided");
        require(bytes(_checkCode).length > 0, "Check code must be provided");

        taskInfo = TaskInfo({
            taskID: _taskID,
            taskType: _taskType,
            resourceType: _resourceType,
            inputParam: _inputParam,
            verifyParam: _verifyParam,
            cpAccount: _cpAccount,
            proof: _proof,
            deadline: _deadline,
            taskRegistryContract: _taskRegistryContract,
            checkCode: _checkCode,
            owner: msg.sender,
            version: version
        });

        // Emit event to record task initialization
        emit TaskCreated(_taskID, _cpAccount, _inputParam, _deadline, _checkCode);

        // Register this task contract with the TaskRegistry
        registerToTaskRegistry();
    }

    // Private function to register this contract with the TaskRegistry
    function registerToTaskRegistry() private {
        (bool success, ) = taskInfo.taskRegistryContract.call(
            abi.encodeWithSignature(
                "registerTaskContract(address,address)",
                address(this),
                taskInfo.owner
            )
        );
        require(success, "Failed to register task contract to TaskRegistry");

        // Emit the event after successful registration
        emit RegisteredToTaskRegistry(address(this), taskInfo.owner);
    }
}
