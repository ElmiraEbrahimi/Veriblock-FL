# Advancing Blockchain-Based Federated Learning Through Verifiable Off Chain Computations

## Prerequisites

- [Python@3.11](https://www.python.org/downloads/)
- [Npm@20+](https://nodejs.org/en/download)
- [Docker](https://docs.docker.com/engine/install/)

## Install and Run

### Python Requirements

Activate virtual env (`source .venv/bin/activate`)
Install python deps: `pip install requirements.txt`

### Ganache

`docker run -d -p 8545:8545 trufflesuite/ganache:latest --gasLimit=0x1fffffffffffff  --allowUnlimitedContractSize -e 1000000000`
(Alternatively, install Ganache CLI via npm: `npm install -g ganache`)

### Solidity Compiler

`npm install -g solc`

### Truffle

`npm install -g truffle`

#### Migration

`cd Blockchain/Truffle/`
`truffle migrate`

### RabbitMQ

`docker run -d --name some-rabbit -p 5672:5672 -p 5673:5673 -p 15672:15672 rabbitmq:3-management`

(user:pass -> `guest:guest`)

### ZoKrates

Note: it must be version 0.7.8 (released Nov 24, 2021) since the last commit on the project was published on Dec 3, 2021, this is the specific version of zokrates the repo was run with.

`docker run -v ./Verification:/home/zokrates/project -ti zokrates/zokrates:0.7.8 /bin/bash`
`cd project`
`./generate_proof.sh` (if it generates error, make sure `chmod +x generate_proof.sh` is run)

## Run

Change absolute path:
    - "/home/nikolas/MEGA/Workplace/Informatik/Masterarbeit/Implementation/PythonProject/MasterThesis_SoftwareEngineering/"
    - "/home/nikolas/PycharmProjects/MasterThesis_SoftwareEngineering/"
to your native absolute path.

Suggested runtime order:

0. python requirements, solidity compiler, and truffle
1. ganache
2. rabbitmq
...
