import json
import subprocess
from typing import Optional
import copy

import numpy as np
from web3 import Web3

from MiddleWare.aggregator.hash import mimc_hash


def moving_average_weights(
    local_weights: dict, participant_count: int, expected_weights: dict
) -> dict:
    k = participant_count
    if k > 0:
        if k == 1:
            for i in range(len(local_weights)):
                expected_weights[i] = local_weights[i]
        else:
            for i in range(len(local_weights)):
                res = [[]]
                row_new = local_weights[i]
                row_old = expected_weights[i]

                for j in range(len(row_old)):
                    res[j] = row_old[j] + (row_new[j] - row_old[j]) / k

                expected_weights[i] = res

    return expected_weights


def moving_average_bias(  # FIXME
    local_bias: dict, participant_count: int, expected_bias: dict
) -> dict:
    k = participant_count
    if k > 0:
        if k == 1:
            for i in range(len(local_bias)):
                expected_bias[i] = local_bias[i]
        else:
            for i in range(len(local_bias)):
                old_bias_i = expected_bias[i]
                new_bias_i = local_bias[i]
                res = old_bias_i + (new_bias_i - old_bias_i) / k
                expected_bias[i] = res

    return expected_bias


# region device (node-manager)


class Device:
    def __init__(
        self,
        address: str,
        weights: Optional[list[list[int]]],
        bias: Optional[list[int]],
        mse_score: Optional[float],
        aggregator: Optional[object],
        blockchain_connection: object,
    ):
        self.blockchain_connection = blockchain_connection
        self.aggregator = aggregator
        self.address = address
        self.weights = weights
        self.bias = bias
        self.mse_score = mse_score
        self.wb_hash = str(self.generate_wb_hash(w=self.weights, b=self.bias))

    def __eq__(self, __value: object) -> bool:
        return self.address == __value.address

    def __hash__(self) -> int:
        return hash(self.address)

    def generate_wb_hash(self, w, b):
        hash = mimc_hash(w=w, b=b)
        return hash

    def send_wb_to_aggregator(self):
        self.aggregator.store_device_wb(
            device_id=self.address,
            w=self.weights,
            b=self.bias,
            mse_score=self.mse_score,
        )


# endregion

# region off-chain aggregator:


class OffChainAggregator:

    def __init__(
        self,
        blockchain_connection: object,
        blockchain_account: str,
        ipfs: object,
        global_w: list[list[int]],
        global_b: list[int],
    ):
        self.blockchain_connection = blockchain_connection
        self.blockchain_account = blockchain_account
        self.ipfs = ipfs
        self.round_number: int = 0
        self.is_round_ongoing = False
        self.historical_selected_device_count: dict[str, int] = {}
        # address: [wb_hash, w, b, mse_score]
        self.stored_device_data: dict[
            str,
            list[str, list[list[int]], list[int], float],
        ] = {}
        # last round parameters:
        self.global_w: list[list[int]] = global_w
        self.global_b: list[int] = global_b
        # current round:
        self.selected_device_data: dict[str, list[list[int], list[int], float]] = {}
        self.new_global_weights: list[list[int]] = self.global_w
        self.new_global_bias: list[int] = self.global_b
        self.new_generated_proof = ""
        self.gdigest = ""

    # region smart contract functions

    def get_sc_round_number(self):
        round = self.blockchain_connection.FLcontractDeployed.functions.getRoundNumber().call(
            {"from": self.blockchain_account}
        )
        return int(round)

    # def get_sc_global_weights(self) -> list[list[int]]:
    #     global_weights = self.blockchain_connection.get_globalWeights(
    #         self.blockchain_account
    #     )
    #     return global_weights

    # def _init_global_weights_sign(self, init_number: int = 0) -> list[list[int]]:
    #     global_weights = self.global_w
    #     signs: list[list[int]] = [[]]
    #     for gw_row in global_weights:
    #         row_sign = []
    #         for _ in range(len(gw_row)):
    #             row_sign.append(init_number)
    #         signs.append(row_sign)
    #     return signs

    # def _init_global_bias_sign(self, init_number: int = 0) -> list[int]:
    #     global_bias = self.global_b
    #     signs: list[int] = []
    #     for _ in global_bias:
    #         signs.append(init_number)
    #     return signs

    # def get_sc_global_bias(self) -> list[int]:
    #     global_bias = self.blockchain_connection.get_globalBias(self.blockchain_account)
    #     return global_bias

    def is_wb_hash_in_sc(self, wb_hash: str) -> bool:
        wb_hashes = self.blockchain_connection.FLcontractDeployed.functions.getAllHashValues().call(
            {"from": self.blockchain_account}
        )
        print(f"Checking {wb_hash=} in {wb_hashes=}")
        return str(wb_hash) in wb_hashes

    def _send_aggregator_wb_link(self) -> bool:
        print(
            f"calling function __check_ZKP_aggregator with arg {self.new_generated_proof=}"
        )
        a, b, c, inputs = self.__check_ZKP_aggregator(self.new_generated_proof)

        # save to ipfs:
        gw_ipfs_link = self._save_gw_to_ipfs(self.new_global_weights)
        gb_ipfs_link = self._save_gb_to_ipfs(self.new_global_bias)

        # send to smart contract:
        thxHash = (
            self.blockchain_connection.FLcontractDeployed.functions.send_aggregator_wb(
                self.gdigest, gw_ipfs_link, gb_ipfs_link, a, b, c, inputs
            ).transact({"from": self.blockchain_account})
        )
        self.blockchain_connection.__await_Transaction(thxHash)

        # save to Blockchain Client:
        self.blockchain_connection.weight_ipfs_link = gw_ipfs_link
        self.blockchain_connection.bias_ipfs_link = gb_ipfs_link

        print(f"Successfully sent: {gw_ipfs_link=}, {gb_ipfs_link=}")

        return True

    # endregion

    def _save_gw_to_ipfs(self, weights) -> str:
        link = self.ipfs.save_global_weight(weights)
        return link

    def _save_gb_to_ipfs(self, bias) -> str:
        link = self.ipfs.save_global_bias(bias)
        return link

    def __check_ZKP_aggregator(self, proof):
        a = proof["proof"]["a"]
        a = [Web3.toInt(hexstr=x) for x in a]
        b = proof["proof"]["b"]
        b = [[Web3.toInt(hexstr=x) for x in y] for y in b]
        c = proof["proof"]["c"]
        c = [Web3.toInt(hexstr=x) for x in c]
        inputs = proof["inputs"]
        inputs = [Web3.toInt(hexstr=x) for x in inputs]

        return a, b, c, inputs

    def store_device_wb(
        self, device_id: str, w: list[list[list[int]]], b: list[int], mse_score: float
    ) -> bool:
        wb_hash = str(mimc_hash(w=w, b=b))
        if not self.is_wb_hash_in_sc(wb_hash):
            # hash not in the smart contract:
            return False
        # hash is in smart contract:
        self.stored_device_data[device_id] = [wb_hash, w, b, mse_score]
        return True

    def select_devices(self, epsilon=1, select_count=3) -> list[str]:

        selected_device_ids = list(self.stored_device_data.keys())
        return selected_device_ids

        # inverse_mse_scores = {}
        # for device_id in self.stored_device_data:
        #     # fetch mse score:
        #     mse_score = self.stored_device_data[device_id][3]
        #     # calculate inverse mse score:
        #     inverse_score = 1 / (mse_score + epsilon)
        #     # normalize the inverse score:
        #     historical_selection_count = self.historical_selected_device_count.get(
        #         device_id, 0
        #     )
        #     adjusted_score = inverse_score / (historical_selection_count + 1)
        #     # save the adjusted score:
        #     inverse_mse_scores[device_id] = adjusted_score

        # # select the top devices:
        # top_device_ids = sorted(
        #     inverse_mse_scores, key=inverse_mse_scores.get, reverse=True
        # )[:select_count]

        # selected_device_ids = top_device_ids

        # # record in history the selected devices:
        # for selected_device_id in selected_device_ids:
        #     if selected_device_id in self.historical_selected_device_count:
        #         self.historical_selected_device_count[selected_device_id] += 1
        #     else:
        #         self.historical_selected_device_count[selected_device_id] = 1

        # return selected_device_ids

    def calculate_moving_average(self) -> tuple:
        selected_weights = [device[1] for device in self.selected_device_data.values()]
        selected_bias = [device[2] for device in self.selected_device_data.values()]
        print(
            f"Calling moving_average_weights: {len(selected_weights)=}, {self.global_w=}"
        )
        new_w = moving_average_weights(
            selected_weights, len(selected_weights), self.global_w
        )
        new_b = moving_average_bias(selected_bias, len(selected_bias), self.global_b)
        return new_w, new_b

    def generate_proof(self) -> str:
        def args_parser(args):
            res = ""
            for arg in range(len(args)):
                entry = args[arg]
                if isinstance(entry, (list, np.ndarray)):
                    for i in range(len(entry)):
                        row_i = entry[i]
                        if isinstance(row_i, (list, np.ndarray)):
                            for j in range(len(row_i)):
                                val = row_i[j]
                                res += str(val) + " "
                        else:
                            res += str(row_i) + " "
                else:
                    res += str(args[arg]) + " "
            res = res[:-1]
            return res

        def convert_matrix(m):
            max_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617
            m = np.array(m)
            return np.where(m < 0, max_field + m, m), np.where(m > 0, 0, 1)

        zokrates = "zokrates"
        aggregator_zokrates_base = (
            self.blockchain_connection.config["DEFAULT"]["ZokratesBase"] + "aggregator/"
        )

        # convert local_w and local_b to a single list:
        local_w_list = []
        local_b_list = []
        for selected_device_id in self.selected_device_data:
            # weights:
            device_w = self.selected_device_data[selected_device_id][1]
            local_w_list.append(device_w)
            # bias:
            device_b = self.selected_device_data[selected_device_id][2]
            local_b_list.append(device_b)
        local_w, local_w_sign = convert_matrix(local_w_list)
        local_b, local_b_sign = convert_matrix(local_b_list)
        # convert global_w and global_b to a single list:
        global_w, global_w_sign = convert_matrix(self.global_w)
        global_b, global_b_sign = convert_matrix(self.global_b)
        # aggregator hash:
        sc_lhashes = []
        for selected_device_id in self.selected_device_data:
            wb_hash = int(self.selected_device_data[selected_device_id][0])
            sc_lhashes.append(wb_hash)
        # expected global weights and bias:
        expected_global_w, expected_global_w_sign = convert_matrix(
            self.new_global_weights
        )
        expected_global_b, expected_global_b_sign = convert_matrix(
            self.new_global_weights
        )
        # set gdigest:
        self.gdigest = mimc_hash(w=expected_global_w, b=expected_global_b)

        args = [
            local_w,
            local_w_sign,
            local_b,
            local_b_sign,
            global_w,
            global_w_sign,
            global_b,
            global_b_sign,
            sc_lhashes,
            expected_global_w,
            expected_global_b,
            expected_global_w_sign,
            expected_global_b_sign,
            self.gdigest,
        ]
        out_path = aggregator_zokrates_base + "out"
        abi_path = aggregator_zokrates_base + "abi.json"
        witness_path = aggregator_zokrates_base + "witness_aggregator"
        zokrates_compute_witness = [
            zokrates,
            "compute-witness",
            "-o",
            witness_path,
            "-i",
            out_path,
            "-s",
            abi_path,
            "-a",
        ]
        zokrates_compute_witness.extend(args_parser(args).split(" "))
        g = subprocess.run(zokrates_compute_witness, capture_output=True)
        proof_path = aggregator_zokrates_base + "proof_aggregator"
        proving_key_path = aggregator_zokrates_base + "proving.key"
        zokrates_generate_proof = [
            zokrates,
            "generate-proof",
            "-w",
            witness_path,
            "-p",
            proving_key_path,
            "-i",
            out_path,
            "-j",
            proof_path,
        ]
        g = subprocess.run(zokrates_generate_proof, capture_output=True)
        with open(proof_path, "r+") as f:
            self.new_generated_proof = json.load(f)

    def clear_round(self):
        self.stored_device_data = {}
        self.selected_device_data = {}
        self.new_global_weights = [[]]
        self.new_global_bias = []
        self.new_generated_proof = ""
        self.gdigest = ""

    def start_round(self):
        if self.is_round_ongoing:
            return
        else:
            print("Aggreagtor round now ongoing...")
            self.is_round_ongoing = True
        # set global weights and bias:
        if self.new_global_weights:
            self.global_w = copy.deepcopy(self.new_global_weights)
        if self.new_global_bias:
            self.global_b = copy.deepcopy(self.new_global_bias)
        # clear the parameters for the new round:
        self.clear_round()
        # fetch the round number from the smart contract:
        self.round_number = self.get_sc_round_number()

    def finish_round(self):
        if self.is_round_ongoing:
            self.is_round_ongoing = False
        print("Finishing aggregator round...")
        # select devices:
        selected_device_ids = self.select_devices()
        for device_id in selected_device_ids:
            self.selected_device_data[device_id] = self.stored_device_data[device_id]
        # calculate moving average:
        print("Calculating moving averages...")
        self.new_global_weights, self.new_global_bias = self.calculate_moving_average()
        # generate the proof:
        print("Generating aggregator proof...")
        self.new_generated_proof = self.generate_proof()
        # send the calculated global weights and bias to the smart contract:
        print("Sending aggregator wb links to contract...")
        self._send_aggregator_wb_link()


# endregion