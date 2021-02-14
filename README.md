# RevPop ICO smart contracts

## How to setup

1. ```sudo make start```
2. ```sudo make npm-init```
3. ```sudo make truffle COMMAND="compile"```

## Usage of development env

This env uses ganache-cli as blockchain.

1. ```sudo make truffle COMMAND="migrate"```
2. Development RPC will be available on http://blockchain:8545

## Usage of Ethereym Ropsten env

1. Create .env file and set your mnemonic phrase and Infura project ID.
2. ```sudo make truffle COMMAND="migrate --network ropsten"```
3. Save contract addresses and use them for interaction.

## Flatten all smart contracts into a single file

```bash
make flatten
```

This command will save a file ./flattened.sol (git ignored).

## Run unit tests

```bash
sudo make truffle COMMAND="test"
```
