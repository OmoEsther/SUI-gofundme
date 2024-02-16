# SUI goFundMe Dapp

This Dapp enables users to create crowdfunding campaigns where other users can donate their SUI tokens. Key features include:

  - **Campaign Management**: Users can create campaigns with specified funding targets.
  - **Donation Handling**: Donors can contribute to campaigns until the target is reached.
  - **Receipt NFTs**: Donors receive a unique NFT as a receipt for their contributions.
  - **Secure Withdrawals**: Only the campaign creator can withdraw funds upon reaching the target.

## Installation

To deploy and use the smart contract, follow these steps:

1. **Move Compiler Installation:**
   Ensure you have the Move compiler installed. You can find the Move compiler and instructions on how to install it at [Sui Docs](https://docs.sui.io/).

2. **Compile the Smart Contract:**
   For this contract to compile successfully, please ensure you switch the dependencies to whichever you installed. 
`framework/devnet` for Devnet, `framework/testnet` for Testnet

```bash
   Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/devnet" }
```

then build the contract by running

```
sui move build
```

3. **Deployment:**
   Deploy the compiled smart contract to your blockchain platform of choice.

```
sui client publish --gas-budget 100000000 --json
```

4. **Testing**

```bash
sui move test
```
