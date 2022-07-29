# NFT Lending Contracts
Cairo and Solidity contracts for NFT Lending dApp.

---

NFT P2P Lending is a dApp that allows users to get loans using their NFTs as collateral.
 - Supports the zkSync (https://zksync.io/) and StarkNet (https://starknet.io/) networks.
 - Borrowers can specify the loan terms and lock NFTs as collateral.
 - Lenders can accept loans and redeem locked NFTs in case of default. 
 - Loan and collateral management is performed by smart contracts.
 
 ---
 

## Cairo

### Install dependencies

Refer to https://starknet.io/docs/quickstart.html#quickstart

### Compile contracts


```shell
cd cairo
chmod +x compile_cairo_contracts.sh
./compile_cairo_contracts.sh
```

### Deploy on the StarkNet network

```shell
cd cairo
chmod +x deploy_cairo_contracts.sh
./deploy_cairo_contracts.sh
```

## Solidity

### Install dependencies

```shell
yarn install
```

### Compile contracts

```shell
yarn hardhat compile
```

### Deploy on the zkSync network

1. Set the deployer private wallet in the *solidity/keys.json* file:
```json
{  "zkSyncDeployerWallet": "<YOUR_WALLET_PRIVATE_KEY" }
```

2. Deploy:
```shell
yarn hardhat deploy-zksync
```
