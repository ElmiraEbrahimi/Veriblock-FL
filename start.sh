# #!/bin/bash

# remove old docker containers
container_ids=$(sudo docker ps -q)
for container_id in $container_ids
do
    sudo docker rm -f $container_id
done

# restart docker containers
sudo docker run -d -p 8545:8545 trufflesuite/ganache:v7.0.0 --miner.blockGasLimit=0x1fffffffffffff  --chain.allowUnlimitedContractSize=true --wallet.defaultBalance 1000000000 --accounts 15
sudo docker run -d --name rabbitmq -p 5672:5672 -p 5673:5673 -p 15672:15672 rabbitmq:3-management

# recompile/remigrate smart contract files
cd blockchain/truffle/
sudo rm -rf build/contracts/*
truffle compile
truffle migrate
cd ./../..
echo "Current directory: $(pwd)"

# remove balance.csv:
balance_csv="balance.csv"
echo "Deleting $balance_csv ..."
if [ -f "$balance_csv" ]; then
    sudo rm "${balance_csv}"
    echo "Done"
else
    echo "$balance_csv was not found in directory."
fi

# remove gas_logs.log:
gas_logs="gas_logs.log"
echo "Deleting $gas_logs ..."
if [ -f "$gas_logs" ]; then
    sudo rm "${gas_logs}"
    echo "Done"
else
    echo "$gas_logs was not found in directory."
fi