# Blockchain-based Federated Learning Utilizing Zero-Knowledge Proofs for Verifiable Training Using On-chain Aggregator

## Prerequisites

- [Python@3.9](https://www.python.org/downloads/)
- [Npm@20+](https://nodejs.org/en/download)
- [Docker](https://docs.docker.com/engine/install/)

## Install and Run

### Python Requirements

(Create & activate virtual env: `source .venv/bin/activate`)
Install python deps: `pip install requirements.txt`

### zokrates

Note: it must be version 0.7.8 (released Nov 24, 2021) since the last commit on the project was published on Dec 3, 2021, this is the specific version of zokrates the repo was run with.

#### Installer

`curl -LSfs get.zokrat.es | sh`

#### Copy Solidity File

copy `verifier.sol` file into `blockchain/truffle/contracts/`.

### Ganache

`docker run -d -p 8545:8545 trufflesuite/ganache:v7.0.0 --miner.blockGasLimit=0x1fffffffffffff  --chain.allowUnlimitedContractSize=true --wallet.defaultBalance 1000000000`

### Truffle

#### Compile

##### via Npm

- make sure npm is installed.
- set `docker: false` in `blockchain/truffle/truffle-config.js` file.
- `npm install -g truffle@5.4.2`
- `cd blockchain/truffle/`
- `truffle compile`.

##### via Docker

- set `docker: true` in `blockchain/truffle/truffle-config.js` file.
- `cd blockchain/truffle/`
- `truffle compile`. (It will pull the required solc version from docker hub)

#### Migrate

- make sure ganache is running.
- `truffle migrate`
- copy contract addresses from the output for `FederatedModel` and `Verifier`, and paste them into `CONFIG.yaml` for `FLContractAddress` and `VerifierContractAddress` respectively.

### RabbitMQ

`docker run -d --name rabbitmq -p 5672:5672 -p 5673:5673 -p 15672:15672 rabbitmq:3-management`

(panel is available at 127.0.0.1:15672, user:pass -> `guest:guest`)

### Devices

- check `devices/edge_device/data/iot_data` exists.
- run: `python devices/edge_device/iot_data_merge_script.py`
- make sure these folders/file are generated in `devices/edge_device/data/`:
      - `Device_{Number: 1-9}` folders
      - `train.txt`
      - `test.txt`
      - `test_file.txt`
      - `outfile_merged.txt`

## Run

      cd devices/
      python main.py

## Full-Run Sequence

0. fix python path (run only one time):

      cd <PROJECT-ROOT>

      export PYTHONPATH="${PYTHONPATH}://<PATH-TO-DIR>/"

      source .venv/bin/activate

1. Change variables in `CONFIG.yml` and `root.zok` files.

2. Run

      cd verification/
      sudo ./x_remove_zokrates_files.sh

      zokrates compile -i zokrates/root.zok
      zokrates setup
      zokrates export-verifier

      cd ..

3. Copy `verifier.sol` file into `blockchain/truffle/contracts/`.
4. Edit `FederatedModel.sol` for correct input variables.

5. Start it all

      cd devices/

      sudo ./start.sh

6. Copy the contract address and paste into `CONFIG.yml`

7. Run

      python main.py