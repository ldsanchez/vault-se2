# Solidity Yearn V3 Vaults 🏗 Scaffold-ETH 2 - Foundry

Solidity implementation of ERC4626 compliant [Yearn V3 Vaults](https://github.com/yearn/yearn-vaults-v3/tree/master) Contracts (Including Vault Factory)

## Notes

- NOT TESTED - NOT AUDITED
- No maximum strategies

## To-Do

- Write Tests
- Vault Manager UI using Scaffold-ETH2
- Strategy Contracts / Mockups

## Requirements

Before you begin, you need to install the following tools:

- [Node (v18 LTS)](https://nodejs.org/en/download/)
- Yarn ([v1](https://classic.yarnpkg.com/en/docs/install/) or [v2+](https://yarnpkg.com/getting-started/install))
- [Git](https://git-scm.com/downloads)
- [Foundryup](https://book.getfoundry.sh/getting-started/installation)

## Quickstart

To get started, follow the steps below:

1. Clone this repo & install dependencies

```
git clone https://github.com/ldsanchez/vault-se2.git
cd vault-se2
yarn install
foundryup
```

2. Create your `.env` file inside `packages/foundry`:

```
(echo "DEPLOYER_PRIVATE_KEY=";  echo "ALCHEMY_API_KEY=oKxs-03sij-U_N0iOlrSsZFr29-IqbuF"; echo "ETHERSCAN_API_KEY=DNXJA8RX2Q3VZ4URQIWP7Z68CJXQZSC6AW") >> packages/foundry/.env
```

3. Run a local network in the first terminal:

```
yarn chain
```

This command starts a local Ethereum network using Anvil in Foundry. The network runs on your local machine and can be used for testing and development. You can customize the network configuration in `foundry.toml`

4. On a second terminal, deploy the test contract:

```
yarn deploy
```

This command deploys a test smart contract to the local network. The contract is located in `packages/foundry/src` and can be modified to suit your needs. The `yarn deploy` command uses the deploy script located in `packages/foundry/script/Deploy.s.sol` to deploy the contract to the network. You can also customize the deploy script.

5. On a third terminal, start your NextJS app:

```
yarn start
```

Visit your app on: `http://localhost:3000`. You can interact with your smart contract using the contract component or the example ui in the frontend. You can tweak the app config in `packages/nextjs/scaffold.config.ts`

## Contributing to Scaffold-ETH 2

We welcome contributions to Scaffold-ETH 2!

Please see [CONTRIBUTING.MD](https://github.com/scaffold-eth/scaffold-eth-2/blob/main/CONTRIBUTING.md) for more information and guidelines for contributing to Scaffold-ETH 2.
