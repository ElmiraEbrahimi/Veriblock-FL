#!/bin/bash

# check tools exists:
zokrates --version
jq --version
echo "Successfully checked tools exist. Continuing..."

# outer:
zokrates compile -i Zokrates/root.zok -o root --curve bls12_377
zokrates setup --proving-scheme gm17 --backend ark -i root
# generate proof:
‍‍zokrates compute-witness --abi -i root --stdin < root_inputs.json
zokrates generate-proof --proving-scheme gm17 --backend ark -i root
# nested:
cd zokrates/nested/
zokrates compile --curve bw6_761 -i nested.zok
zokrates setup --proving-scheme gm17 --backend ark
# gm17:
echo "[\n$(cat proof.json | jq '{proof, inputs}'), $(cat verification.key | jq 'del(.scheme,.curve)')\n]" > gm17.json
zokrates compute-witness --abi --stdin < gm17.json
zokrates generate-proof --proving-scheme gm17 --backend ark

# export a solidity verifier
zokrates export-verifier
# or verify natively
zokrates verify

# array_one=("1" "1")
# array_two=("array two part one" "array two part two")
# # compile
# zokrates compile -i zokrates/root.zok
# # perform the setup phase
# zokrates setup
# # execute the program
# zokrates compute-witness -a 1 1 1 1 1
# # generate a proof of computation
# zokrates generate-proof
# # export a solidity verifier
# zokrates export-verifier
# # or verify natively
# zokrates verify
