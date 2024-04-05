# #!/bin/bash

# export NODE_OPTIONS=--max-old-space-size=20480
# ganache-cli --gasLimit=0x1fffffffffffff  --allowUnlimitedContractSize -e 1000000000


container_ids=$(sudo docker ps -q)
for container_id in $container_ids
do
    sudo docker rm -f $container_id
done
sudo docker run -d -p 8545:8545 trufflesuite/ganache:v7.0.0 --miner.blockGasLimit=0x1fffffffffffff  --chain.allowUnlimitedContractSize=true --wallet.defaultBalance 1000000000
sudo docker run -d --name rabbitmq -p 5672:5672 -p 5673:5673 -p 15672:15672 rabbitmq:3-management

cd blockchain/Truffle/
sudo rm -rf build/contracts/*
sudo truffle compile
sudo truffle migrate
cd ...