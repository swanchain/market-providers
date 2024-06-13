// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ECPCollateral is Ownable {
    uint public slashedFunds;
    uint public baseCollateral;
    uint public taskBalance;
    uint public collateralRatio;
    uint public slashRatio;

    mapping(address => bool) public isAdmin;
    mapping(address => int) public balances;
    mapping(address => uint) public frozenBalance;
    mapping(address => Task) public tasks;
    mapping(address => string) public cpStatus;

    // Task status constants
    uint private constant STATUS_LOCKED = 1;
    uint private constant STATUS_UNLOCKED = 2;
    uint private constant STATUS_SLASHED = 3;

    struct Task {
        address cpAccountAddress;
        uint collateral;
        uint status; // Status represented as a uint
    }

    struct ContractInfo {
        uint slashedFunds;
        uint baseCollateral;
        uint taskBalance;
        uint collateralRatio;
        uint slashRatio;
    }

    struct CPInfo {
        address cp;
        int balance;
        uint frozenBalance;
        string status;
    }

    event Deposit(address indexed fundingWallet, address indexed cpAccount, uint depositAmount);
    event Withdraw(address indexed cpOwner, address indexed cpAccount, uint withdrawAmount);
    event WithdrawSlash(address indexed collateralContratOwner, uint slashfund);
    event CollateralLocked(address indexed cp, uint collateralAmount, address taskContractAddress);
    event CollateralUnlocked(address indexed cp, uint collateralAmount, address taskContractAddress);
    event CollateralSlashed(address indexed cp, uint amount, address taskContractAddress);
    event TaskCreated(address indexed taskContractAddress, address cpAccountAddress, uint collateral);
    event TaskStatusChanged(address indexed taskContractAddress, uint newStatus);
    event CollateralAdjusted(address indexed cp, uint frozenAmount, uint balanceAmount, string operation);
    event DisputeProof(address indexed challenger, address indexed taskContractAddress);

    constructor() Ownable(msg.sender) {
        _transferOwnership(msg.sender);
        isAdmin[msg.sender] = true;
        collateralRatio = 5; // Default collateral ratio
        slashRatio = 2; // Default slash ratio
    }

    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "Only the admin can call this function.");
        _;
    }

    function addAdmin(address newAdmin) external onlyOwner {
        isAdmin[newAdmin] = true;
    }

    function removeAdmin(address admin) external onlyOwner {
        isAdmin[admin] = false;
    }

    function lockCollateral(address cp, address taskContractAddress) external onlyAdmin {
        uint taskCollateral = uint(collateralRatio * baseCollateral);
        require(balances[cp] >= int(taskCollateral), "Not enough balance for collateral");
        balances[cp] -= int(taskCollateral);
        frozenBalance[cp] += taskCollateral;
        tasks[taskContractAddress] = Task({
            cpAccountAddress: cp,
            collateral: taskCollateral,
            status: STATUS_LOCKED
        });
        checkCpInfo(cp);
        emit CollateralLocked(cp, taskCollateral, taskContractAddress);
        emit TaskCreated(taskContractAddress, cp, taskCollateral);
    }

    function unlockCollateral(address taskContractAddress) public onlyAdmin {
        Task storage task = tasks[taskContractAddress];
        uint availableAmount = frozenBalance[task.cpAccountAddress];
        uint unlockAmount = task.collateral > availableAmount ? availableAmount : task.collateral;

        frozenBalance[task.cpAccountAddress] -= unlockAmount;
        balances[task.cpAccountAddress] += int(unlockAmount);
        task.collateral = 0;
        task.status = STATUS_UNLOCKED;
        checkCpInfo(task.cpAccountAddress);
        emit CollateralUnlocked(task.cpAccountAddress, unlockAmount, taskContractAddress);
        emit TaskStatusChanged(taskContractAddress, STATUS_UNLOCKED);
    }

    function slashCollateral(address taskContractAddress) external onlyAdmin {
        Task storage task = tasks[taskContractAddress];
        uint slashAmount = uint(baseCollateral * slashRatio);
        uint availableFrozen = frozenBalance[task.cpAccountAddress];
        uint fromFrozen = slashAmount > availableFrozen ? availableFrozen : slashAmount;
        uint fromBalance = slashAmount > fromFrozen ? slashAmount - fromFrozen : 0;
        frozenBalance[task.cpAccountAddress] -= fromFrozen;
        balances[task.cpAccountAddress] -= int(fromBalance);
        slashedFunds += slashAmount;
        task.status = STATUS_SLASHED;
        task.collateral = task.collateral > slashAmount ? task.collateral - slashAmount : 0;
        checkCpInfo(task.cpAccountAddress);
        emit CollateralSlashed(task.cpAccountAddress, slashAmount, taskContractAddress);
        emit TaskStatusChanged(taskContractAddress, STATUS_SLASHED);
        emit CollateralAdjusted(task.cpAccountAddress, fromFrozen, fromBalance, "Slashed");

        if (task.collateral > 0) {
            unlockCollateral(taskContractAddress);
        }
    }

    function disputeProof(address taskContractAddress) public {
        emit DisputeProof(msg.sender, taskContractAddress);
    }
    function deposit(address cpAccount) public payable {
        balances[cpAccount] += int(msg.value);
        emit Deposit(msg.sender, cpAccount, msg.value);
        checkCpInfo(cpAccount);
    }

    function withdraw(address cpAccount, uint amount) external {
        (bool success, bytes memory CPOwner) = cpAccount.call(abi.encodeWithSignature("getOwner()"));
        require(success, "Failed to call getOwner function of CPAccount");
        address cpOwner = abi.decode(CPOwner, (address));
        require(balances[cpAccount] >= int(amount), "Withdraw amount exceeds balance");
        require(msg.sender == cpOwner, "Only CP's owner can withdraw the collateral funds");
        balances[cpAccount] -= int(amount);
        payable(msg.sender).transfer(amount);

        checkCpInfo(cpAccount);
        emit Withdraw(msg.sender, cpAccount, amount);
        
    }

    function getECPCollateralInfo() external view returns (ContractInfo memory) {
        return ContractInfo({
            slashedFunds: slashedFunds,
            baseCollateral: baseCollateral,
            taskBalance: taskBalance,
            collateralRatio: collateralRatio,
            slashRatio: slashRatio
        });
    }

    function setCollateralRatio(uint _collateralRatio) external onlyOwner {
        collateralRatio = _collateralRatio;
    }

    function setSlashRatio(uint _slashRatio) external onlyOwner {
        slashRatio = _slashRatio;
    }

    function setBaseCollateral(uint _baseCollateral) external onlyAdmin {
        baseCollateral = _baseCollateral;
    }

    function getBaseCollateral() external view returns (uint) {
        return baseCollateral;
    }

    function cpInfo(address cpAddress) external view returns (CPInfo memory) {
        return CPInfo({
            cp: cpAddress,
            balance: balances[cpAddress],
            frozenBalance: frozenBalance[cpAddress],
            status: cpStatus[cpAddress]
        });
    }

    function checkCpInfo(address cpAddress) internal {
        if (balances[cpAddress] >= int(collateralRatio * baseCollateral)) {
            cpStatus[cpAddress] = 'zkAuction';
        } else {
            cpStatus[cpAddress] = 'NSC';
        }
    }
    function withdrawSlashedFunds(uint slashfund) public onlyOwner {
        require(slashedFunds >= slashfund, "Withdraw slashfund amount exceeds slashedFunds");
        slashedFunds -= slashfund;

        payable(msg.sender).transfer(slashfund);
        emit WithdrawSlash(msg.sender, slashfund);
    }

    function getTaskInfo(address taskContractAddress) external view returns (Task memory) {
        return tasks[taskContractAddress];
    }

    receive() external payable {
        deposit(msg.sender);
    }
}
