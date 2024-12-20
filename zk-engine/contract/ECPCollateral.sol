// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ECPCollateral is Ownable {
    IERC20 public collateralToken;
    uint public slashedFunds;
    uint public baseCollateral;
    uint public collateralRatio;
    uint public slashRatio;
    uint public withdrawDelay = 120960;

    mapping(address => bool) public isAdmin;
    mapping(address => int) public balances;
    mapping(address => uint) public frozenBalance;
    mapping(address => string) public cpStatus;
    mapping(address => WithdrawRequest) public withdrawRequests;

    struct ContractInfo {
        address collateralToken;
        uint slashedFunds;
        uint baseCollateral;
        uint collateralRatio;
        uint slashRatio;
        uint withdrawDelay;
    }

    struct CPInfo {
        address cp;
        int balance;
        uint frozenBalance;
        string status;
    }

    struct WithdrawRequest {
        uint amount;
        uint requestBlock;
    }

    event Deposit(address indexed fundingWallet, address indexed cpAccount, uint depositAmount);
    event Withdraw(address indexed cpOwner, address indexed cpAccount, uint withdrawAmount);
    event WithdrawSlash(address indexed collateralContratOwner, uint slashfund);
    event CollateralLocked(address indexed cp, uint collateralAmount);
    event CollateralUnlocked(address indexed cp, uint collateralAmount);
    event CollateralSlashed(address indexed cp, uint amount);
    event CollateralAdjusted(address indexed cp, uint frozenAmount, uint balanceAmount, string operation);
    event DisputeProof(address indexed challenger, address indexed taskContractAddress, address cpAccount, uint taskID);
    event WithdrawRequested(address indexed cp, uint amount);
    event WithdrawConfirmed(address indexed cp, address cpOwner, uint amount);
    event WithdrawRequestCanceled(address indexed cp, uint amount);
    event BatchFrozenDeposit(address indexed admin, address[] cps, uint[] amounts);

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

    function lockCollateral(address cp, uint taskCollateral) public onlyAdmin {
        require(cp != address(0), "Invalid address: cp cannot be the zero address");
        require(balances[cp] >= int(taskCollateral), "Not enough balance for collateral");
        balances[cp] -= int(taskCollateral);
        frozenBalance[cp] += taskCollateral;
        checkCpInfo(cp);
        emit CollateralLocked(cp, taskCollateral);
    }

    function unlockCollateral(address cp, uint taskCollateral) public onlyAdmin {
        require(cp != address(0), "Invalid address: cp cannot be the zero address");
        uint availableAmount = frozenBalance[cp];
        uint unlockAmount = taskCollateral > availableAmount ? availableAmount : taskCollateral;

        frozenBalance[cp] -= unlockAmount;
        balances[cp] += int(unlockAmount);
        checkCpInfo(cp);
        emit CollateralUnlocked(cp, unlockAmount);
    }

    function slashCollateral(address cp, uint slashAmount) public onlyAdmin {
        require(cp != address(0), "Invalid address: cp cannot be the zero address");
        require(slashAmount > 0, "Invalid amount: slashAmount must be greater than zero");
        uint availableFrozen = frozenBalance[cp];
        uint availableBalance = balances[cp] > 0 ? uint(balances[cp]) : 0;

        uint fromFrozen = slashAmount > availableFrozen ? availableFrozen : slashAmount;
        uint remainingToSlash = slashAmount > fromFrozen ? slashAmount - fromFrozen : 0;
        uint fromBalance = remainingToSlash > availableBalance ? availableBalance : remainingToSlash;
        uint actualSlashed = fromFrozen + fromBalance;
        frozenBalance[cp] -= fromFrozen;
        balances[cp] -= int(remainingToSlash);


        slashedFunds += actualSlashed;
        checkCpInfo(cp);
        emit CollateralSlashed(cp, actualSlashed);
        emit CollateralAdjusted(cp, fromFrozen, fromBalance, "Slashed");
    }

    function batchLock(address[] calldata cps, uint[] calldata taskCollaterals) external onlyAdmin {
        require(cps.length == taskCollaterals.length, "Array lengths must match");

        for (uint i = 0; i < cps.length; i++) {
            require(cps[i] != address(0), "Invalid address: cp cannot be the zero address");
            lockCollateral(cps[i], taskCollaterals[i]);
        }
    }

    function batchUnlock(address[] calldata cps, uint[] calldata taskCollaterals) external onlyAdmin {
        require(cps.length == taskCollaterals.length, "Array lengths must match");
        for (uint i = 0; i < cps.length; i++) {
            require(cps[i] != address(0), "Invalid address: cp cannot be the zero address");
            unlockCollateral(cps[i], taskCollaterals[i]);
        }
    }

    function batchSlash(address[] calldata cps, uint[] calldata slashAmounts) external onlyAdmin {
        require(cps.length == slashAmounts.length, "Array lengths must match");
        for (uint i = 0; i < cps.length; i++) {
            require(cps[i] != address(0), "Invalid address: cp cannot be the zero address");
            slashCollateral(cps[i], slashAmounts[i]);
        }
    }

    function batchFrozenDeposit(address[] calldata cps, uint[] calldata amounts) external onlyAdmin {
        require(cps.length == amounts.length, "Array lengths must match");
        uint totalAmount = 0;
        for (uint i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        require(collateralToken.transferFrom(msg.sender, address(this), totalAmount), "Token transfer failed");
        for (uint i = 0; i < cps.length; i++) {
            require(cps[i] != address(0), "Invalid address: cp cannot be the zero address");
            frozenBalance[cps[i]] += amounts[i];
            checkCpInfo(cps[i]);
        }
        emit BatchFrozenDeposit(msg.sender, cps, amounts);
    }

    function disputeProof(address taskContractAddress, address cpAccount, uint taskID) public {
        require(cpAccount != address(0), "Invalid address: cpAccount cannot be the zero address");
        require(taskContractAddress != address(0), "Invalid address: taskContract cannot be the zero address");
        emit DisputeProof(msg.sender, taskContractAddress, cpAccount, taskID);
    }

    function requestWithdraw(address cpAccount, uint amount) public {
        require(cpAccount != address(0), "Invalid address: cpAccount cannot be the zero address");
        (bool success, bytes memory CPOwner) = cpAccount.call(abi.encodeWithSignature("getOwner()"));
        require(success, "Failed to call getOwner function of CPAccount");
        address cpOwner = abi.decode(CPOwner, (address));
        require(msg.sender == cpOwner, "Only CP's owner can request withdrawal");

        require(frozenBalance[cpAccount] >= amount, "Not enough frozen balance to withdraw");

        withdrawRequests[cpAccount] = WithdrawRequest({
            amount: amount,
            requestBlock: block.number
        });

        emit WithdrawRequested(cpAccount, amount);
    }

    function confirmWithdraw(address cpAccount) public {
        require(cpAccount != address(0), "Invalid address: cpAccount cannot be the zero address");
        (bool success, bytes memory CPOwner) = cpAccount.call(abi.encodeWithSignature("getOwner()"));
        require(success, "Failed to call getOwner function of CPAccount");
        address cpOwner = abi.decode(CPOwner, (address));
        require(msg.sender == cpOwner, "Only CP's owner can confirm withdrawal");

        WithdrawRequest storage request = withdrawRequests[cpAccount];
        require(request.amount > 0, "No pending withdraw request");
        require(block.number >= request.requestBlock + withdrawDelay, "Withdraw delay not passed");
        require(frozenBalance[cpAccount] >= request.amount, "Not enough frozen balance to withdraw");

        uint withdrawAmount = request.amount;
        frozenBalance[cpAccount] -= withdrawAmount;
        collateralToken.transfer(cpOwner, withdrawAmount);

        emit WithdrawConfirmed(cpAccount, cpOwner, withdrawAmount);

        delete withdrawRequests[cpAccount];
    }

    function cancelWithdrawRequest(address cpAccount) public {
        require(cpAccount != address(0), "Invalid address: cpAccount cannot be the zero address");
        (bool success, bytes memory CPOwner) = cpAccount.call(abi.encodeWithSignature("getOwner()"));
        require(success, "Failed to call getOwner function of CPAccount");
        address cpOwner = abi.decode(CPOwner, (address));
        require(msg.sender == cpOwner, "Only CP's owner can cancel withdraw request");

        WithdrawRequest storage request = withdrawRequests[cpAccount];
        require(request.amount > 0, "No pending withdraw request");

        emit WithdrawRequestCanceled(cpAccount, request.amount);

        delete withdrawRequests[cpAccount];
    }
    function viewWithdrawRequest(address cpAccount) external view returns (WithdrawRequest memory) {
        require(cpAccount != address(0), "Invalid address: cpAccount cannot be the zero address");
        return withdrawRequests[cpAccount];
    }

    function deposit(address cpAccount, uint amount) public {
        require(cpAccount != address(0), "Invalid address: cpAccount cannot be the zero address");
        require(amount > 0, "Invalid amount: must be greater than zero");
        collateralToken.transferFrom(msg.sender, address(this), amount);
        balances[cpAccount] += int(amount);
        emit Deposit(msg.sender, cpAccount, amount);
        checkCpInfo(cpAccount);
    }

    function withdraw(address cpAccount, uint amount) external {
        require(cpAccount != address(0), "Invalid address: cpAccount cannot be the zero address");
        (bool success, bytes memory CPOwner) = cpAccount.call(abi.encodeWithSignature("getOwner()"));
        require(success, "Failed to call getOwner function of CPAccount");
        address cpOwner = abi.decode(CPOwner, (address));
        require(balances[cpAccount] >= int(amount), "Withdraw amount exceeds balance");
        require(msg.sender == cpOwner, "Only CP's owner can withdraw the collateral funds");
        balances[cpAccount] -= int(amount);
        collateralToken.transfer(msg.sender, amount);

        checkCpInfo(cpAccount);
        emit Withdraw(msg.sender, cpAccount, amount);
    }

    function getECPCollateralInfo() external view returns (ContractInfo memory) {
        return ContractInfo({
            collateralToken: address(collateralToken), // 返回 collateralToken 地址
            slashedFunds: slashedFunds,
            baseCollateral: baseCollateral,
            collateralRatio: collateralRatio,
            slashRatio: slashRatio,
            withdrawDelay: withdrawDelay
        });
    }

    function setCollateralToken(address tokenAddress) external onlyOwner {
        require(tokenAddress != address(0), "Invalid address: tokenAddress cannot be the zero address");
        collateralToken = IERC20(tokenAddress);
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

    function setWithdrawDelay(uint _withdrawDelay) external onlyOwner {
        withdrawDelay = _withdrawDelay;
    }

    function getBaseCollateral() external view returns (uint) {
        return baseCollateral;
    }

    function cpInfo(address cpAccount) external view returns (CPInfo memory) {
        require(cpAccount != address(0), "Invalid address: cpAccount cannot be the zero address");
        return CPInfo({
            cp: cpAccount,
            balance: balances[cpAccount],
            frozenBalance: frozenBalance[cpAccount],
            status: cpStatus[cpAccount]
        });
    }

    function checkCpInfo(address cpAccount) internal {
        require(cpAccount != address(0), "Invalid address: cpAccount cannot be the zero address");
        if (balances[cpAccount] == 0 && frozenBalance[cpAccount] == 0) {
            cpStatus[cpAccount] = "NSC";
        } else {
            cpStatus[cpAccount] = "Active";
        }
    }

    function withdrawSlashedFunds(uint slashfund) public onlyOwner {
        require(slashedFunds >= slashfund, "Withdraw slashfund amount exceeds slashedFunds");
        slashedFunds -= slashfund;
        collateralToken.transfer(msg.sender, slashfund);
        emit WithdrawSlash(msg.sender, slashfund);
    }
}
