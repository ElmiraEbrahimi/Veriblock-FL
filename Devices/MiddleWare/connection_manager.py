import copy
import json
import threading
import time
import traceback

import numpy as np
from middleware.aggregator import OffChainAggregator
from middleware.aggregator_selection import AggregatorSelector
from middleware.hash import convert_matrix, mimc_hash
from middleware.ipfs import IPFSConnector
from utils.gas import log_receipt
from web3 import Web3


class ConnectionManager:
    def __init__(self, config_file, participant_count: int, barrier: threading.Barrier):
        self.config = config_file
        self.web3Connection = None
        self.FLcontractABI = None
        self.FLcontractDeployed = None
        self.FLcontractAddress = self.config["DEFAULT"]["FLContractAddress"]
        self.lock_newRound = threading.Lock()
        self.precision = None
        self.participant_count = participant_count
        self.barrier = barrier

        self.aggregator_selector = None
        self.init_w = None
        self.init_b = None
        self.ipfs = IPFSConnector()
        self.weight_ipfs_link = ""
        self.bias_ipfs_link = ""

    def connect(self):
        self.web3Connection = Web3(
            Web3.HTTPProvider(
                self.config["DEFAULT"]["EtheriumRPCServer"],
                request_kwargs={"timeout": 60 * 10},
            )
        )
        with open(self.config["DEFAULT"]["FLContractABIPAth"]) as f:
            self.FLcontractABI = json.load(f)["abi"]
        self.FLcontractDeployed = self.web3Connection.eth.contract(
            address=self.FLcontractAddress, abi=self.FLcontractABI
        )

    def init_contract(self, accountNR):
        if self.is_connected() and accountNR == 0:
            np.random.seed(4)
            weights = (
                np.random.randn(
                    self.config["DEFAULT"]["OutputDimension"],
                    self.config["DEFAULT"]["InputDimension"],
                )
                * self.config["DEFAULT"]["Precision"]
                / 5
            )
            bias = (
                np.random.randn(
                    self.config["DEFAULT"]["OutputDimension"],
                )
                * self.config["DEFAULT"]["Precision"]
                / 5
            )
            weights = [[int(x) for x in y] for y in weights]
            bias = [int(x) for x in bias]

            self.init_w = copy.deepcopy(weights)
            self.init_b = copy.deepcopy(bias)
            self.weight_ipfs_link = self.ipfs.save_global_weight(weights)
            self.bias_ipfs_link = self.ipfs.save_global_bias(bias)

            # generate proof?
            is_no_proof = not bool(self.config["DEFAULT"]["PerformProof"])

            thxHash = self.FLcontractDeployed.functions.initModel(
                weights, bias, is_no_proof
            ).transact({"from": self.web3Connection.eth.accounts[accountNR]})
            self._await_transaction(thxHash, accountNr=accountNR)
            thxHash = self.FLcontractDeployed.functions.updateVerifier(
                self.config["DEFAULT"]["VerifierContractAddress"],
                self.config["DEFAULT"]["VerifierAggregatorContractAddress"],
            ).transact({"from": self.web3Connection.eth.accounts[0]})
            self._await_transaction(thxHash, accountNr=accountNR)

            # init aggregator:
            first_aggregator_account_num = 12
            second_aggregator_account_num = 13
            aggregator_selector_account_num = 14

            print("Initializing aggregators...")
            aggregators: list[OffChainAggregator] = [
                OffChainAggregator(
                    name=f"FirstAgg({first_aggregator_account_num})",
                    connection_manager=self,
                    blockchain_account=self.web3Connection.eth.accounts[
                        first_aggregator_account_num
                    ],
                    ipfs=self.ipfs,
                    global_w=self.init_w,
                    global_b=self.init_b,
                    is_no_proof=is_no_proof,
                ),
                OffChainAggregator(
                    name=f"SecondAgg({second_aggregator_account_num})",
                    connection_manager=self,
                    blockchain_account=self.web3Connection.eth.accounts[
                        second_aggregator_account_num
                    ],
                    ipfs=self.ipfs,
                    global_w=self.init_w,
                    global_b=self.init_b,
                    is_no_proof=is_no_proof,
                ),
            ]
            print("Initializing aggregator selector...")
            self.aggregator_selector = AggregatorSelector(
                connection_manager=self,
                aggregators=aggregators,
                account_number=aggregator_selector_account_num,
            )

    def __check_ZKP(self, is_no_proof, proof, accountNR):
        if is_no_proof:
            a_size = 2
            input_size = 5
            a = ["1"] * a_size
            b = [["1"] * a_size] * a_size
            c = ["1"] * a_size
            inputs = ["1"] * input_size
            proof = {
                "proof": {
                    "a": a,
                    "b": b,
                    "c": c,
                },
                "inputs": inputs,
            }

        a = proof["proof"]["a"]
        a = [Web3.toInt(hexstr=x) for x in a]
        b = proof["proof"]["b"]
        b = [[Web3.toInt(hexstr=x) for x in y] for y in b]
        c = proof["proof"]["c"]
        c = [Web3.toInt(hexstr=x) for x in c]
        inputs = proof["inputs"]
        inputs = [Web3.toInt(hexstr=x) for x in inputs]
        # istrue= self.FLcontractDeployed.functions.checkZKP(a,b,c, inputs).call({"from": self.web3Connection.eth.accounts[accountNR]})
        # print(f"AccountNr = {accountNR}: ZKP went through",istrue)

        return a, b, c, inputs

    def _await_transaction(self, thxHash, accountNr):
        receipt = self.web3Connection.eth.wait_for_transaction_receipt(thxHash)
        log_receipt(receipt=receipt, account=accountNr)

    def is_connected(self):
        return self.web3Connection.isConnected()

    def get_LearningRate(self, accountNR):
        self.precision = self.__get_Precision(accountNR)
        lr = self.FLcontractDeployed.functions.getLearningRate().call(
            {"from": self.web3Connection.eth.accounts[accountNR]}
        )
        return lr

    def __get_Precision(self, accountNR):
        return self.FLcontractDeployed.functions.getPrecision().call(
            {"from": self.web3Connection.eth.accounts[accountNR]}
        )

    def get_InputDimension(self, accountNR):
        return self.FLcontractDeployed.functions.getInputDimension().call(
            {"from": self.web3Connection.eth.accounts[accountNR]}
        )

    def get_Epochs(self, accountNR):
        return self.config["DEFAULT"]["Epochs"]

    def get_OutputDimension(self, accountNR):
        return self.FLcontractDeployed.functions.getOutputDimension().call(
            {"from": self.web3Connection.eth.accounts[accountNR]}
        )

    def get_globalWeights(self, accountNR):
        # we = self.FLcontractDeployed.functions.get_global_weights().call(
        #     {"from": self.web3Connection.eth.accounts[accountNR]}
        # )
        # return we
        # print(f"Fetching global weight from IPFS... {self.weight_ipfs_link=}")
        gw = self.ipfs.get_global_weight(self.weight_ipfs_link)
        # print(f"IPFS global weight = {gw}")
        return gw

    def get_globalBias(self, accountNR):
        # bias = self.FLcontractDeployed.functions.get_global_bias().call(
        #     {"from": self.web3Connection.eth.accounts[accountNR]}
        # )
        # return bias
        # print(f"Fetching global bias from IPFS... {self.bias_ipfs_link=}")
        gb = self.ipfs.get_global_bias(self.bias_ipfs_link)
        # print(f"IPFS global bias = {gb}")
        return gb

    def get_account_balance(self, accountNR):
        return self.web3Connection.fromWei(
            self.web3Connection.eth.getBalance(
                self.web3Connection.eth.accounts[accountNR]
            ),
            "ether",
        )

    def roundUpdateOutstanding(self, accountNR):
        self.lock_newRound.acquire()
        newround = self.FLcontractDeployed.functions.roundUpdateOutstanding().call(
            {"from": self.web3Connection.eth.accounts[accountNR]}
        )
        if not newround:
            try:
                txhash = self.FLcontractDeployed.functions.end_update_round().transact(
                    {"from": self.web3Connection.eth.accounts[accountNR]}
                )
                self._await_transaction(txhash, accountNr=accountNR)

            except Exception:
                print(f"AccountNr = {accountNR}: Update Ending Reverted")
                print(f"AccountNr = {accountNR}: Trying end Again")
                try:
                    # , a, b, c, inputs
                    txhash = (
                        self.FLcontractDeployed.functions.end_update_round().transact(
                            {"from": self.web3Connection.eth.accounts[accountNR]}
                        )
                    )
                    self._await_transaction(txhash, accountNr=accountNR)
                except Exception as intx:
                    print(f"AccountNr = {accountNR}: Update Ending Reverted")
                    print(intx)

        newround_refreshed = (
            self.FLcontractDeployed.functions.roundUpdateOutstanding().call(
                {"from": self.web3Connection.eth.accounts[accountNR]}
            )
        )
        if newround_refreshed and (not newround):
            print(f"AccountNr = {accountNR}: Round is finished starting new round =>")
            self.lock_newRound.release()
            return newround_refreshed
        else:
            self.lock_newRound.release()
            return newround

    def __send_wb_hash(self, weights, bias, mse_score, accountNR, proof=None):
        is_no_proof = True if proof is None else False
        temp_weights = [[int(x) for x in y] for y in weights]
        temp_bias = [int(x) for x in bias]

        # generate hash of local weight and local bias:
        w_c, _ = convert_matrix(temp_weights)
        b_c, _ = convert_matrix(temp_bias)
        wb_hash = str(mimc_hash(w_c, b_c))

        # generate proof for the hash:
        a, b, c, inputs = self.__check_ZKP(is_no_proof, proof, accountNR)

        # send to smart contract:
        thxHash = self.FLcontractDeployed.functions.send_wb_hash(
            wb_hash, a, b, c, inputs
        ).transact({"from": self.web3Connection.eth.accounts[accountNR]})
        self._await_transaction(thxHash, accountNr=accountNR)

        # if tx_receipt.status == 0:
        #     # Get the revert reason from the transaction receipt
        #     revert_reason = self..toText(tx_receipt["returnData"])
        #     print(f"Transaction reverted with reason: {revert_reason}")
        # else:
        #     print("Transaction successful")

        # send w,b to aggregator:
        self.aggregator_selector.store_device_wb(
            device_id=self.web3Connection.eth.accounts[accountNR],
            w=temp_weights,
            b=temp_bias,
            mse_score=mse_score,
        )
        print(f"AccountNr = {accountNR}: SUCCESSFULLY SENT TO AGGREGATOR")

    def update(self, weights, bias, mse_score, accountNR, proof=None):
        if self.config["DEFAULT"]["PerformProof"]:
            tries = 5
            while tries > 0:
                try:
                    self.__send_wb_hash(weights, bias, mse_score, accountNR, proof)
                    tries = -1
                except Exception as err:
                    time.sleep(self.config["DEFAULT"]["WaitingTime"])
                    if tries == 1:
                        traceback_info = traceback.format_exc()
                        print(
                            f"AccountNr = {accountNR}: Update Failed: {str(err)=}\nTraceback:\n{traceback_info}"
                        )

                    tries -= 1
        else:
            tries = 5
            while tries > 0:
                try:
                    self.__send_wb_hash(weights, bias, mse_score, accountNR, proof=None)
                    tries = -1
                except Exception as err:
                    time.sleep(self.config["DEFAULT"]["WaitingTime"])
                    if tries == 1:
                        traceback_info = traceback.format_exc()
                        print(
                            f"AccountNr = {accountNR}: Update Failed: {str(err)=}\nTraceback:\n{traceback_info}"
                        )
                    tries -= 1

    def get_BatchSize(self, accountNR):
        return self.FLcontractDeployed.functions.getBatchSize().call(
            {"from": self.web3Connection.eth.accounts[accountNR]}
        )

    def get_RoundNumber(self, accountNR):
        return self.FLcontractDeployed.functions.getRoundNumber().call(
            {"from": self.web3Connection.eth.accounts[accountNR]}
        )

    def get_Precision(self, accountNR):
        self.precision = self.__get_Precision(accountNR)
        return self.precision
