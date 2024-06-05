// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
contract ContractRegistry {
    struct CPContractInfo {
        address owner;
        address cpAccountContract;
    }

    mapping(address => CPContractInfo) public cpContracts;

    event CPContractRegistered(address indexed cpContract, address indexed owner);
    event CPAddressChanged(address indexed cp, address newCP);

    function registerCPContract(address cpContract, address owner) external {
        require(cpContract != address(0), "Invalid CP contract address");
        require(owner != address(0), "Invalid owner address");
        require(cpContracts[cpContract].cpAccountContract == address(0), "CP contract already registered");

        cpContracts[cpContract] = CPContractInfo({
            owner: owner,
            cpAccountContract: cpContract
        });

        emit CPContractRegistered(cpContract, owner);
    }

    function changeOwner(address cpContract, address newOwner) external {
        require(newOwner != address(0), "Invalid owner address");
        require(msg.sender == cpContract, "Only the CP contract can change its owner");
        cpContracts[cpContract].owner = newOwner;

        emit CPAddressChanged(cpContract, newOwner);
    }
}
