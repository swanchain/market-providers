# Computing Provider On Swan Network

**[Computing provider](https://docs.swanchain.io/orchestrator/as-a-computing-provider)**(CP) is an individual or organization that participates in the decentralized computing network by offering computational resources such as processing power (CPU and GPU), memory, storage, and bandwidth.

As a resource provider, you can run a ECP(Edge Computing Provider) and FCP(Fog Computing Provider) to contribute yourcomputing resource. More details can be found [here](https://github.com/swanchain/go-computing-provider)

## Computing Provider Account(cpAccount)
The computing provider has upgraded to V2, one CP will be a `cpAccount` contract on the Swan chain, And when a CP is initialized, the cpAccount will be registered to the `RegistryContract`. Any user can found the CP account informations by the `RegistryContract` from the Swan chain.  The related contract files can be found here:
 - [cpAccount.sol](account/cpAccount.sol)
 - [ContractRegistry.sol](account/ContractRegistry.sol)

## Latest Version


- **Proxima Testnet**
    - Registry contract Address:
