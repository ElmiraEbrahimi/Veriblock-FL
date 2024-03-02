# Advancing Blockchain-Based Federated Learning Through Verifiable Off Chain Computations

## Prerequisites

- [Python@3.9](https://www.python.org/downloads/)
- [Npm@20+](https://nodejs.org/en/download)
- [Docker](https://docs.docker.com/engine/install/)

## Install and Run

### Python Requirements

(Create & activate virtual env: `source .venv/bin/activate`)
Install python deps: `pip install requirements.txt`

### ZoKrates

Note: it must be version 0.7.8 (released Nov 24, 2021) since the last commit on the project was published on Dec 3, 2021, this is the specific version of zokrates the repo was run with.

#### Installer

Warning: this will install the latest zokrates version (version +0.8.0). Since version 0.8.0 the syntax for .zok files are changed. Which is incompatible with the old `root.zok` file (located in `Verification/ZoKrates/root.zok`) which was written possibly with version 0.7.8.

`curl -LSfs get.zokrat.es | sh`

#### Docker

- `docker run -v ./Verification:/home/zokrates/project -ti zokrates/zokrates /bin/bash`
- `cd project`
- `./generate_proof.sh` (if it generates error, make sure `chmod +x generate_proof.sh` is run)

#### Build

- Install [Rust](https://www.rust-lang.org/tools/install).
- `cd Verification/Source/ZoKrates-0.7.8`
- `export ZOKRATES_STDLIB=$PWD/zokrates_stdlib/stdlib`
- `cargo build -p zokrates_cli --release`
- `cd target/release`

#### Copy Solidity File

copy `verifier.sol` file into `Blockchain/Truffle/contracts/`.

### Ganache

`docker run -d -p 8545:8545 trufflesuite/ganache:v7.0.0 --miner.blockGasLimit=0x1fffffffffffff  --chain.allowUnlimitedContractSize=true --wallet.defaultBalance 1000000000`

### Truffle

#### Compile

##### via Npm

- make sure npm is installed.
- set `docker: false` in `Blockchain/Truffle/truffle-config.js` file.
- `npm install -g truffle@5.4.2`
- `cd Blockchain/Truffle/`
- `truffle compile`.

##### via Docker

- set `docker: true` in `Blockchain/Truffle/truffle-config.js` file.
- `cd Blockchain/Truffle/`
- `truffle compile`. (It will pull the required solc version from docker hub)

#### Migrate

- make sure ganache is running.
- `truffle migrate`
- copy contract addresses from the output for `FederatedModel` and `Verifier`, and paste them into `CONFIG.yaml` for `FLContractAddress` and `VerifierContractAddress` respectively.

### RabbitMQ

`docker run -d --name rabbitmq -p 5672:5672 -p 5673:5673 -p 15672:15672 rabbitmq:3-management`

(panel is available at 127.0.0.1:15672, user:pass -> `guest:guest`)

### Devices

- check `Devices/Edge_Device/data/iot_data` exists.
- run: `python Devices/Edge_Device/iot_data_merge_script.py`
- make sure these folders/file are generated in `Devices/Edge_Device/data/`:
      - `Device_{Number: 1-9}` folders
      - `train.txt`
      - `test.txt`
      - `test_file.txt`
      - `outfile_merged.txt`

## Run

Start devices: `python Devices/main.py`

## Off-chain

### Celo

<https://docs.celo.org/developer/>

#### CLI

`npm install -g @celo/celocli`

### Generate Proof (outer and nested)

See `./Verification/generate_proof.sh`.
