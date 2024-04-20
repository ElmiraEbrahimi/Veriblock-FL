# Advancing Blockchain-Based Federated Learning Through Verifiable Off Chain Computations

## Prerequisites

- [Python@3.9](https://www.python.org/downloads/)
- [Node@20+](https://nodejs.org/en/download)
- [Docker](https://docs.docker.com/engine/install/)

## Install and Run

### Python Requirements

Create & activate virtual env:

      python3 -m venv venv 
      source venv/bin/activate

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

      cd verification/
      sudo ./x_remove_zokrates_files.sh
      sudo ./x_remove_devices_witness_proof.sh

      zokrates compile -i zokrates/root.zok
      zokrates setup
      zokrates export-verifier

##### Aggregator Verifiers

      cd zokrates/aggregator

      zokrates compile -i root.zok
      zokrates setup
      zokrates export-verifier

#### Copy Solidity File

copy `verification/verifier.sol` file into `blockchain/Truffle/contracts/verifier.sol`.
copy `verification/zokrates/aggregator/verifier.sol` file into `blockchain/Truffle/contracts/verifier_aggregator.sol` AND add `Aggregator` suffix to the end of the structs. (So it will be distinguishable from the first verifier's structs)

### Ganache

      sudo docker run -d -p 8545:8545 trufflesuite/ganache:v7.0.0 --miner.blockGasLimit=0x1fffffffffffff  --chain.allowUnlimitedContractSize=true --wallet.defaultBalance 1000000000 --accounts 15

### Truffle

#### Install

<https://archive.trufflesuite.com/docs/truffle/how-to/install/>

Run:

`npm install -g solc`

#### Compile

##### via Docker

- set `docker: true` in `blockchain/Truffle/truffle-config.js` file.
- pull the required solc version from docker hub and compile:

      cd blockchain/Truffle/
      sudo rm -rf build/contracts/*
      sudo truffle compile

#### Migrate

- make sure ganache is running and run (in blockchain/Truffle/):

      sudo truffle migrate
      cd ...

- copy contract addresses from the output for `FederatedModel` and `Verifier`, and paste them into `CONFIG.yaml` for `FLContractAddress` and `VerifierContractAddress` respectively.

### RabbitMQ

      sudo docker run -d --name rabbitmq -p 5672:5672 -p 5673:5673 -p 15672:15672 rabbitmq:3-management

(panel is available at 127.0.0.1:15672, user:pass -> `guest:guest`)

### Devices

<!-- - download data (Daily and Sports Activities) from: <https://archive.ics.uci.edu/dataset/256/daily+and+sports+activities> -->
- check `devices/edge_device/data/iot_data` exists.
- run: `python devices/edge_device/iot_data_merge_script.py`
- make sure these folders/file are generated in `devices/edge_device/data/`:
      - `Device_{Number: 1-9}` folders
      - `train.txt`
      - `test.txt`
      - `test_file.txt`
      - `outfile_merged.txt`

## Run

Start devices:

      python devices/main.py

## Analyze Zokrates

      cd verification/time_memory_analytics

Change the `repeat` in analyze.py and `bs` (batchsize) in root.zok.

      python analyze.py

It will generate two csv files named: `analytics.csv` and `analytics_memory.csv`.

### ChartMart

python calculate_analytics_avg.py

pip install notebook

## "Old" and "New" code

### Browse files on GitHub

- old code (modified to be runnable) files:

GITHUB-REPO-URL/tree/old

- new code (including aggregator) files:
  
GITHUB-REPO-URL/tree/main

### Run old ode (on server - via SSH)

1. SSH into server (via vscode)
2. Run:
`cd ~/Original/`
3. Check `CONFIG.yaml` and `Verification/ZoKrates/root.zok` files to include the desired variables.
4. If the environment variable is not already activated, run:
`source ./.venv/bin/activate`
5. Run:
`./start.sh`
(you will be asked to type password)
6. Copy the contract addresses and paste into `CONFIG.yaml`
7. Run:
`export PYTHONPATH='.'`
8. Run:
`python Devices/main.py`

### New code (on server - via SSH)

1. SSH into server (via vscode)
2. Run:
`cd ~/Abbfltvocc/`
3. Check `CONFIG.yaml`, `verification/zokrates/root.zok` and `verification/zokrates/aggregator/root.zok` files to include the desired variables.
4. If the environment variable is not already activated, run:
`source ./venv/bin/activate`
5. Run:
`./start.sh`
(you will be asked to type password)
6. Copy the contract addresses and paste into `CONFIG.yaml`
7. Run:
`python devices/main.py`

## Full-Run Sequence

1. Change variables in `CONFIG.yml` and `root.zok` files.

2. Run

cd verification/
sudo ./x_remove_devices_witness_proof.sh
sudo ./x_remove_zokrates_files.sh

zokrates compile -i zokrates/root.zok
zokrates setup
zokrates export-verifier

cd zokrates/aggregator
zokrates compile -i root.zok
zokrates setup
zokrates export-verifier
cd ./../../../

3. Copy `verifier.sol` files into `blockchain/Truffle/contracts/`. (Note that `verifier_aggregator.sol` is created based on `aggregator/root.zok` file)
31. Edit `FederatedModel.sol` for correct input variables.

4. Start it all

./start.sh

5. Copy the contract address and paste into `CONFIG.yml`

6. Run

python devices/main.py