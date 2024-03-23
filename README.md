# Advancing Blockchain-Based Federated Learning Through Verifiable Off Chain Computations

## Prerequisites

- [Python@3.9](https://www.python.org/downloads/)
- [Node@20+](https://nodejs.org/en/download)
- [Docker](https://docs.docker.com/engine/install/)

## Install and Run

### Python Requirements

Create & activate virtual env:

`python3 -m venv venv && source venv/bin/activate`

Install python deps: `pip install -r requirements.txt`

### ZoKrates

#### Installer

The old zokrates files are converted into the new syntax. We are able to run the files with the latest version of zokrates.
Install the latest version:

`curl -LSfs get.zokrat.es | sh`

If this is the first time you're installing ZoKrates run the following:

`export PATH=$PATH:/home/toor/.zokrates/bin`

#### Run Zokrates

##### Client Verifier

`cd Verification/`

      zokrates compile -i ZoKrates/root.zok
      zokrates setup
      zokrates export-verifier

##### Aggregator Verifiers

`cd Verification/ZoKrates/aggregator`

      zokrates compile -i aggregator.zok
      zokrates setup
      zokrates export-verifier

#### Copy Solidity File

copy `Verification/verifier.sol` file into `Blockchain/Truffle/contracts/verifier.sol`.
copy `Verification/ZoKrates/aggregator/verifier.sol` file into `Blockchain/Truffle/contracts/verifier_aggregator.sol` AND add `Aggregator` suffix to the end of the structs. (So it will be distinguishable from the first verifier's structs)

### Ganache

      sudo docker run -d -p 8545:8545 trufflesuite/ganache:v7.0.0 --miner.blockGasLimit=0x1fffffffffffff  --chain.allowUnlimitedContractSize=true --wallet.defaultBalance 1000000000

### Truffle

#### Install

<https://archive.trufflesuite.com/docs/truffle/how-to/install/>

#### Compile

##### via Docker

- set `docker: true` in `Blockchain/Truffle/truffle-config.js` file.
- `cd Blockchain/Truffle/`
- `truffle compile`. (It will pull the required solc version from docker hub)

#### Migrate

- make sure ganache is running.
- `cd Blockchain/Truffle/`
- `truffle migrate`
- copy contract addresses from the output for `FederatedModel` and `Verifier`, and paste them into `CONFIG.yaml` for `FLContractAddress` and `VerifierContractAddress` respectively.

### RabbitMQ

      sudo docker run -d --name rabbitmq -p 5672:5672 -p 5673:5673 -p 15672:15672 rabbitmq:3-management

(panel is available at 127.0.0.1:15672, user:pass -> `guest:guest`)

### Devices

- download data (Daily and Sports Activities) from: <https://archive.ics.uci.edu/dataset/256/daily+and+sports+activities>
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