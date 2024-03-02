import threading
import time

import numpy as np
from web3 import Web3
import json
#from Devices.MiddleWare.Aggregator import moving_average_all

from MiddleWare.aggregator.aggregator import OffChainAggregator
from MiddleWare.aggregator.aggregator import Device


class BlockChainConnection:
    def __init__(self, config_file, participant_count: int):
        self.config = config_file
        self.web3Connection = None
        self.FLcontractABI = None
        self.FLcontractDeployed = None
        self.FLcontractAddress = self.config["DEFAULT"]["FLContractAddress"]
        self.lock_newRound = threading.Lock()
        self.precision = None
        self.participant_count = participant_count
        self.aggregator = None

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

        # init aggregator:
        self.aggregator = OffChainAggregator(
            blockchain_connection=self,
            blockchain_account=self.web3Connection.eth.accounts[self.participant_count],
        )
        # aggregator start round:
        self.aggregator.start_round()
        ######

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
            thxHash = self.FLcontractDeployed.functions.initModel(
                weights, bias
            ).transact({"from": self.web3Connection.eth.accounts[accountNR]})
            self.__await_Transaction(thxHash)
            thxHash = self.FLcontractDeployed.functions.map_temp_to_global().transact(
                {"from": self.web3Connection.eth.accounts[accountNR]}
            )
            self.__await_Transaction(thxHash)
            thxHash = self.FLcontractDeployed.functions.updateVerifier(
                self.config["DEFAULT"]["VerifierContractAddress"]
            ).transact({"from": self.web3Connection.eth.accounts[0]})
            self.__await_Transaction(thxHash)

    def __check_ZKP(self, proof, accountNR):
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

    def __await_Transaction(self, thxHash):
        self.web3Connection.eth.wait_for_transaction_receipt(thxHash)

    def is_connected(self):
        return self.web3Connection.is_connected()

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
        we = self.FLcontractDeployed.functions.get_global_weights().call(
            {"from": self.web3Connection.eth.accounts[accountNR]}
        )
        return we

    def get_globalBias(self, accountNR):
        bias = self.FLcontractDeployed.functions.get_global_bias().call(
            {"from": self.web3Connection.eth.accounts[accountNR]}
        )
        return bias

    def get_account_balance(self, accountNR):
        return self.web3Connection.from_wei(
            self.web3Connection.eth.get_balance(
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
                self.__await_Transaction(txhash)
            except Exception as intx:
                print(f"AccountNr = {accountNR}: Update Ending Reverted")
                print(f"AccountNr = {accountNR}: Trying end Again")
                try:
                    # , a, b, c, inputs
                    txhash = (
                        self.FLcontractDeployed.functions.end_update_round().transact(
                            {"from": self.web3Connection.eth.accounts[accountNR]}
                        )
                    )
                    self.__await_Transaction(txhash)
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
            # aggregator finish round:
            self.aggregator.finish_round()
            self.aggregator.start_round()
            ######
            self.lock_newRound.release()
            return newround_refreshed
        else:
            self.lock_newRound.release()
            return newround

    def __send_wb_hash(self, weights, bias, accountNR, proof):
        weights = [[int(x) for x in y] for y in weights]
        bias = [int(x) for x in bias]
        device = Device(
            blockchain_connection=self,
            aggregator=self.aggregator,
            address=self.web3Connection.eth.accounts[accountNR],
            weights=weights,
            bias=bias,
        )

        # # generate hash of local weight and local bias:
        # wb_hash = self.generate_hash(weights, bias, accountNR)
        # generate proof for the hash:
        a, b, c, inputs = self.__check_ZKP(proof, accountNR)
        # send to smart contract:
        thxHash = self.FLcontractDeployed.functions.send_wb_hash(
            a, b, c, inputs
        ).transact({"from": self.web3Connection.eth.accounts[accountNR]})
        self.web3Connection.eth.waitForTransactionReceipt(thxHash)
        # send w,b to aggregator:
        device.send_wb_to_aggregator()

    def __update_without_proof(self, weights, bias, accountNR):
        weights = [[int(x) for x in y] for y in weights]
        bias = [int(x) for x in bias]
        thxHash = self.FLcontractDeployed.functions.update_without_proof(
            weights, bias
        ).transact({"from": self.web3Connection.eth.accounts[accountNR]})
        self.web3Connection.eth.waitForTransactionReceipt(thxHash)
        events = self.FLcontractDeployed.events.RunMovingAverage().getLogs()
        for event in events:
            if str(event["args"].get("result")) == "100":  # run moving average:
                # get current new temp_global_weights and temp_global_bias:
                temp_global_weights, temp_global_bias, participating_devices = (
                    self.FLcontractDeployed.functions.getTempGlobalAndParticipants().call()
                )
                # get new temp_global_weights and temp_global_bias:
                # new_temp_global_weights, new_temp_global_bias = moving_average_all(
                #     new_weights=weights,
                #     new_bias=bias,
                #     participant_count=participating_devices,
                #     temp_global_weights=temp_global_weights,
                #     temp_global_bias=temp_global_bias,
                # )
                # set new temp_global_weights and temp_global_bias:
                thxHash = self.FLcontractDeployed.functions.setTempGlobal(
                    new_temp_global_weights, new_temp_global_bias
                ).transact({"from": self.web3Connection.eth.accounts[accountNR]})
                self.__await_Transaction(thxHash)
                print(f"AccountNr = {accountNR}: UPDATE SUCCESSFUL")
                return
        print(f"AccountNr = {accountNR}: UPDATE FAILED. Trx: {str(thxHash)}")

    def update(self, weights, bias, accountNR, proof=None):
        if self.config["DEFAULT"]["PerformProof"]:
            tries = 5
            while tries > 0:
                try:
                    self.__send_wb_hash(weights, bias, accountNR, proof)
                    tries = -1
                except:
                    time.sleep(self.config["DEFAULT"]["WaitingTime"])
                    if tries == 1:
                        print(f"AccountNr = {accountNR}: Update Failed")
                    tries -= 1
        else:
            tries = 5
            while tries > 0:
                try:
                    self.__update_without_proof(weights, bias, accountNR)
                    tries = -1
                except:
                    time.sleep(self.config["DEFAULT"]["WaitingTime"])
                    if tries == 1:
                        print(f"AccountNr = {accountNR}: Update Failed")
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