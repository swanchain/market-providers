// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ZKSequencer is Ownable {
    mapping(address => bool) public admins;
    mapping(address => int) public balances;
    uint256 public escrowBalance;

    event Deposited(address indexed cpAccount, uint256 amount);
    event Withdrawn(address indexed cpAccount, uint256 amount);
    event TransferredToEscrow(address indexed cpAccount, uint256 amount);
    event WithdrawnFromEscrow(uint256 amount);
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event OwnerChanged(address indexed previousOwner, address indexed newOwner);
    event BatchTransferredToEscrow(address indexed admin, address[] cpAccounts, uint256[] amounts);

    constructor() Ownable(msg.sender)  {
        transferOwnership(msg.sender);
        admins[msg.sender] = true;
    }

    modifier onlyAdminOrOwner() {
        require(admins[msg.sender] || owner() == msg.sender, "Not an admin or owner");
        _;
    }

    function addAdmin(address _admin) external onlyOwner {
        admins[_admin] = true;
        emit AdminAdded(_admin);
    }

    function removeAdmin(address _admin) external onlyOwner {
        admins[_admin] = false;
        emit AdminRemoved(_admin);
    }

    function deposit(address cpAccount) public payable {
        require(cpAccount != address(0), "Invalid account address");
        balances[cpAccount] += int(msg.value);
        emit Deposited(cpAccount, msg.value);
    }

    function withdraw(address cpAccount, uint256 amount) external {
        (bool success, bytes memory CPOwner) = cpAccount.call(abi.encodeWithSignature("getOwner()"));
        require(success, "Failed to call getOwner function of CPAccount");
        address cpOwner = abi.decode(CPOwner, (address));
        require(balances[cpAccount] >= int(amount), "Withdraw amount exceeds balance");
        require(msg.sender == cpOwner, "Only CP's owner can withdraw the collateral funds");
        balances[cpAccount] -= int(amount);
        payable(msg.sender).transfer(amount);
        emit Withdrawn(cpAccount, amount);
    }

    function transferToEscrow(address cpAccount, uint256 amount) external onlyAdminOrOwner {
        balances[cpAccount] -= int(amount);
        escrowBalance += amount;
        emit TransferredToEscrow(cpAccount, amount);
    }

   function getCPBalance(address cpAccount) external view returns (int) {
       return balances[cpAccount];
    }


    function batchTransferToEscrow(address[] calldata cpAccounts, uint256[] calldata amounts) external onlyAdminOrOwner {
        require(cpAccounts.length == amounts.length, "Arrays length mismatch");
        for (uint i = 0; i < cpAccounts.length; i++) {
            balances[cpAccounts[i]] -= int(amounts[i]);
            escrowBalance += amounts[i];
            emit TransferredToEscrow(cpAccounts[i], amounts[i]);
        }
        emit BatchTransferredToEscrow(msg.sender, cpAccounts, amounts);
    }

    function withdrawFromEscrow(uint256 amount) external onlyOwner {
        require(escrowBalance >= amount, "Insufficient escrow balance");
        escrowBalance -= amount;
        payable(owner()).transfer(amount);
        emit WithdrawnFromEscrow(amount);
    }

    function changeOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner address");
        address previousOwner = owner();
        transferOwnership(newOwner);
        emit OwnerChanged(previousOwner, newOwner);
    }

    receive() external payable {}
}
