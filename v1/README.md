# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a Hardhat Ignition module that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.ts
```



# MerkleClaimERC20

ERC20 token claimable by members of a [Merkle tree](https://en.wikipedia.org/wiki/Merkle_tree). Useful for conducting Airdrops. Utilizes [Solmate ERC20](https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC20.sol) for modern ERC20 token implementation.

## Test

Tests use [Foundry: Forge](https://github.com/gakonst/foundry).

Install Foundry using the installation steps in the README of the linked repo.

### Run tests

```bash
# Go to contracts directory, if not already there
cd contracts/

# Get dependencies
forge update

# Run tests
forge test --root .
# Run tests with stack traces
forge test --root . -vvvv
```

## Deploy

Follow the `forge create` instructions ([CLI README](https://github.com/gakonst/foundry/blob/master/cli/README.md#build)) to deploy your contracts or use [Remix](https://remix.ethereum.org/).

You can specify the token `name`, `symbol`, `decimals`, and airdrop `merkleRoot` upon deploy.

## Credits

- [@brockelmore](https://github.com/Anish-Agnihotri/merkle-airdrop-starter/issues?q=is%3Apr+author%3Abrockelmore) for [#1](https://github.com/Anish-Agnihotri/merkle-airdrop-starter/pull/1)
- [@transmissions11](https://github.com/Anish-Agnihotri/merkle-airdrop-starter/issues?q=is%3Apr+author%3Atransmissions11) for [#2](https://github.com/Anish-Agnihotri/merkle-airdrop-starter/pull/2)
- [@devanonon](https://github.com/Anish-Agnihotri/merkle-airdrop-starter/issues?q=is%3Apr+author%3Adevanonon) for [#3](https://github.com/Anish-Agnihotri/merkle-airdrop-starter/pull/8)


# Merkle Airdrop Starter

Quickly bootstrap an ERC20 token airdrop to a Merkle tree of recipients.

Steps:

1. Generate Merkle tree of recipients by following README in [generator/](https://github.com/Anish-Agnihotri/merkle-airdrop-starter/tree/master/generator)
2. Setup and deploy MerkleClaimERC20 contracts by following README in [contracts/](https://github.com/Anish-Agnihotri/merkle-airdrop-starter/tree/master/contracts)
3. Setup and deploy front-end by following README in [frontend/](https://github.com/Anish-Agnihotri/merkle-airdrop-starter/tree/master/frontend)

## Similar work and credits

- [Astrodrop](https://astrodrop.xyz/)—Simpler way to spin up a airdrop with claim page, given existing token
- [Uniswap Merkle Distributor](https://github.com/Uniswap/merkle-distributor)—Uniswap's merkle distribution smart contracts

## License

[GNU Affero GPL v3.0](https://github.com/Anish-Agnihotri/merkle-airdrop-starter/blob/master/LICENSE)

## Disclaimer

_These smart contracts are being provided as is. No guarantee, representation or warranty is being made, express or implied, as to the safety or correctness of the user interface or the smart contracts. They have not been audited and as such there can be no assurance they will work as intended, and users may experience delays, failures, errors, omissions or loss of transmitted information. Anish Agnihotri is not liable for any of the foregoing. Users should proceed with caution and use at their own risk._
