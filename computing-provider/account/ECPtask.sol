// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ECPTask is Ownable {

    struct TaskInfo {
        uint taskType;
        uint resourceType;
        string inputParam;
        string verifyParam;
        address cpContractAddress;
        string status;
        string rewardTx;
        string proof;
        string challengeTx;
        string lockFundTx;
        string unlockFundTx;
        string slashTx;
        uint deadline;
        bool isSubmitted;
        bool isChallenged;
    }


    uint public taskType;
    uint public resourceType;
    string public inputParam;
    string public verifyParam;
    address public cpContractAddress;
    string public status;
    string public rewardTx;
    string public proof;
    string public challengeTx;
    string public lockFundTx;
    string public unlockFundTx;
    string public slashTx;
    uint public deadline;
    bool public isSubmitted;
    bool public isChallenged;

    // TaskInfo public taskInfo;
    mapping(address => bool) public isAdmin;

    event RewardAndStatusUpdated(string rewardTx, string status);
    event LockAndStatusUpdated(address cpContractAddress, string lockFundTx, string status);
    event UnlockAndStatusUpdated(string unlockFundTx, string status);
    event ChallengeAndStatusUpdated(string challengeTx, string status);
    event SlashAndStatusUpdated(string slashTx, string status);

    event SubmitProof(string proof);

    constructor(
        uint _taskType,
        uint _resourceType,
        string memory _inputParam,
        string memory _verifyParam,
        address _cpContractAddress,
        string memory _status,
        string memory _lockFundTx,
        uint _deadline
    ) Ownable(msg.sender) {

            require(_taskType > 0, "Invalid task type");
            require(_resourceType >= 0, "Invalid resource type");
            require(bytes(_inputParam).length > 0, "Input parameter cannot be empty");
            require(bytes(_status).length > 0, "Status cannot be empty");
            require(_deadline > 0, "Deadline must be positive");

            taskType = _taskType;
            resourceType= _resourceType;
            inputParam= _inputParam;
            verifyParam= _verifyParam;
            cpContractAddress= _cpContractAddress;
            status = _status;
            deadline = _deadline;
            lockFundTx = _lockFundTx;
        isAdmin[msg.sender] = true;
    }

    // Modifier to check if the caller is the admin
    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "Only the admin can call this function.");
        _;
    }

    function updateRewardAndStatus(
        string memory _rewardTx,
        string memory _status
    ) public onlyAdmin {
        rewardTx = _rewardTx;
        status = _status;
        emit RewardAndStatusUpdated(rewardTx, status);
    }

    function updateLockAndStatus(
        string memory _lockFundTx,
        string memory _status,
        address _cpContractAddress
    ) public onlyAdmin {
        lockFundTx = _lockFundTx;
        status = _status;
        cpContractAddress = _cpContractAddress;
        emit LockAndStatusUpdated(cpContractAddress, lockFundTx, status);
    }

    function updateUnlockAndStatus(
        string memory _unlockFundTx,
        string memory _status
    ) public onlyAdmin {
        unlockFundTx = _unlockFundTx;
        status = _status;
        emit UnlockAndStatusUpdated(unlockFundTx, status);
    }

    function updateChallengeAndStatus(
        string memory _challengeTx,
        string memory _status
    ) public onlyAdmin {
        challengeTx = _challengeTx;
        status = _status;
        isChallenged = true;
        emit ChallengeAndStatusUpdated(challengeTx, status);
    }

    function updateSlashAndStatus(
        string memory _slashTx,
        string memory _status
    ) public onlyAdmin {
        slashTx = _slashTx;
        status = _status;
        emit SlashAndStatusUpdated(slashTx, status);
    }

    function submitProof(string memory _proof) public {
        (bool success, bytes memory CPOwner) = cpContractAddress.call(abi.encodeWithSignature("getOwner()"));
        require(success, "Failed to call getOwner function of CPAccount");
        address owner = abi.decode(CPOwner, (address));

        (bool ok, bytes memory CPWorker) = cpContractAddress.call(abi.encodeWithSignature("getWorker()"));
        require(ok, "Failed to call getWorker function of CPAccount");
        address worker = abi.decode(CPWorker, (address));

        require(msg.sender == owner || msg.sender == worker, "Only the CP contract owner or worker can submit proof.");

        proof = _proof;
        isSubmitted = true;
        emit SubmitProof(proof);
    }

    function getTaskInfo() public view returns(TaskInfo memory) {
        return TaskInfo(taskType, resourceType, inputParam,verifyParam, cpContractAddress,status,rewardTx,proof,challengeTx,lockFundTx,unlockFundTx,slashTx,deadline,isSubmitted,isChallenged);
    }

    function version() public pure returns(string memory) {
        return "1.0.0";
    }
}
