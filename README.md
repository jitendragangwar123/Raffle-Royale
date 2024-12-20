## Raffle Royale

#### Raffle-Royale is a decentralized game where players stake ETH to enter a raffle, with Chainlink VRF ensuring provably fair winner selection and Chainlink Automation managing seamless and efficient operations.

<img width="1422" alt="Screenshot 2024-12-20 at 9 14 13 AM" src="https://github.com/user-attachments/assets/14c72ffb-c30c-4f59-9c7c-a320321147c1" />
<img width="1425" alt="Screenshot 2024-12-20 at 9 14 37 AM" src="https://github.com/user-attachments/assets/cb78e754-aac4-4349-aa72-521ee6ac42c7" />


### Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [foundry](https://getfoundry.sh/)


### Quickstart

```
$ git clone https://github.com/jitendragangwar123/Raffle-Royale.git
$ cd Raffle-Royale
$ make install
$ forge build
```

### Start a local node

```
$ make anvil
```

### Library

If you're having a hard time installing the chainlink library, you can optionally run this command. 

```
$ forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit
```

### Deploy

This will default to your local node. You need to have it running in another terminal in order for it to deploy.

```
$ make deploy
```
### Testing

1. Unit
2. Integration
3. Forked
4. Staging

This repo we cover #1 and #3.

```
$ forge test
```

or

```
$ forge test --fork-url $SEPOLIA_RPC_URL
```

### Test Coverage

```
$ forge coverage
```

### Deployment to a testnet or mainnet

1. Setup environment variables

You'll want to set your `SEPOLIA_RPC_URL` and `PRIVATE_KEY` as environment variables. You can add them to a `.env` file.

Optionally, add your `ETHERSCAN_API_KEY` if you want to verify your contract on [Etherscan](https://etherscan.io/).

1. Get testnet ETH

Head over to [faucets.chain.link](https://faucets.chain.link/) and get some testnet ETH. You should see the ETH show up in your metamask.

2. Deploy

```
$ make deploy ARGS="--network sepolia"
```

This will setup a ChainlinkVRF Subscription for you. If you already have one, update it in the `scripts/HelperConfig.s.sol` file. It will also automatically add your contract as a consumer.

3. Register a Chainlink Automation Upkeep

[You can follow the documentation if you get lost.](https://docs.chain.link/chainlink-automation/compatible-contracts)

Go to [automation.chain.link](https://automation.chain.link/new) and register a new upkeep. Choose `Custom logic` as your trigger mechanism for automation.

### Scripts

After deploying to a testnet or local net, you can run the scripts.

Using cast deployed locally example:

```
$ cast send <RAFFLE_CONTRACT_ADDRESS> "enterRaffle()" --value 0.1ether --private-key <PRIVATE_KEY> --rpc-url $SEPOLIA_RPC_URL
```

or, to create a ChainlinkVRF Subscription:

```
$ make createSubscription ARGS="--network sepolia"
```

### Estimate gas

You can estimate how much gas things cost by running:

```
$ forge snapshot
```

And you'll see an output file called `.gas-snapshot`

### Formatting

To run code formatting:

```
$ forge fmt
```

### Front-End

1. Install the dependencies
```
$ npm i
```

2. Start the client
```
$ npm run dev
```
