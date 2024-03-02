import json
import subprocess
from typing import Optional

import numpy as np

from MiddleWare.aggregator.hash import mimc_hash


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
        self.wb_hash = self.generate_wb_hash(w=self.weights, b=self.bias)

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

    def send_wb_hash_to_smart_contract(self) -> bool:
        thxHash = self.blockchain_connection.FLcontractDeployed.functions.setHashValue(
            self.address, self.wb_hash
        ).transact({"from": self.address})
        self.blockchain_connection.__await_Transaction(thxHash)

        return True


# endregion

# region off-chain aggregator:


class OffChainAggregator:

    def __init__(self, blockchain_connection: object, blockchain_account: str):
        self.blockchain_connection = blockchain_connection
        self.blockchain_account = blockchain_account
        self.round_number: int = 0
        self.historical_selected_device_count: dict[str, int] = {}
        # address: [wb_hash, w, b, mse_score]
        self.stored_device_data: dict[
            str,
            list[str, list[list[int]], list[int], float],
        ] = {}
        self.selected_device_data: dict[str, list[list[int], list[int], float]] = {}
        self.new_global_weights: list[list[int]] = []
        self.new_global_bias: list[int] = []
        self.new_generated_proof = ""

    # region smart contract functions

    def fetch_sc_round_number(self):
        round = self.blockchain_connection.FLcontractDeployed.functions.getRoundNumber().call(
            {"from": self.blockchain_account}
        )
        return int(round)

    def is_wb_hash_in_sc(self, wb_hash: str) -> bool:
        wb_hashes = self.blockchain_connection.FLcontractDeployed.functions.getAllHashKeys().call(
            {"from": self.blockchain_account}
        )
        return wb_hash in wb_hashes

    def set_new_wb_in_sc(self) -> bool:
        thxHash = self.blockchain_connection.FLcontractDeployed.functions.setTempGlobal(
            self.new_global_weights, self.new_global_bias
        ).transact({"from": self.blockchain_account})
        self.blockchain_connection.__await_Transaction(thxHash)

        return True

    # endregion

    def store_device_wb(
        self, device_id: str, w: list[list[list[int]]], b: list[int], mse_score: float
    ) -> bool:
        wb_hash = mimc_hash(w=w, b=b)
        if not self.is_wb_hash_in_sc(wb_hash):
            # hash not in the smart contract:
            return False
        # hash is in smart contract:
        self.stored_device_data[device_id] = [wb_hash, w, b, mse_score]
        return True

    def select_devices(self, epsilon=1, select_count=3) -> list[str]:

        inverse_mse_scores = {}
        for device_id in self.stored_device_data:
            # fetch mse score:
            mse_score = self.stored_device_data[device_id][3]
            # calculate inverse mse score:
            inverse_score = 1 / (mse_score + epsilon)
            # normalize the inverse score:
            historical_selection_count = self.historical_selected_device_count.get(
                device_id, 0
            )
            adjusted_score = inverse_score / (historical_selection_count + 1)
            # save the adjusted score:
            inverse_mse_scores[device_id] = adjusted_score

        # select the top devices:
        top_device_ids = sorted(
            inverse_mse_scores, key=inverse_mse_scores.get, reverse=True
        )[:select_count]

        selected_device_ids = top_device_ids

        # record in history the selected devices:
        for selected_device_id in selected_device_ids:
            if selected_device_id in self.historical_selected_device_count:
                self.historical_selected_device_count[selected_device_id] += 1
            else:
                self.historical_selected_device_count[selected_device_id] = 1

        return selected_device_ids

    def calculate_moving_average(self) -> tuple:
        selected_weights = [device[1] for device in self.selected_device_data.values()]
        selected_bias = [device[2] for device in self.selected_device_data.values()]
        new_w = moving_average_weights(
            selected_weights, len(selected_weights), self.new_global_weights
        )
        new_b = moving_average_bias(
            selected_bias, len(selected_bias), self.new_global_bias
        )
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
            self.config["DEFAULT"]["ZokratesBase"] + "aggregator/"
        )
        w, _ = convert_matrix(self.new_global_weights)
        b, _ = convert_matrix(self.new_global_bias)
        digest = mimc_hash(w=w, b=b)
        args = [
            w,
            b,
            digest,
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
            self.proof = json.load(f)

    def clear_round(self):
        self.stored_device_data = {}
        self.selected_device_data = {}
        self.new_global_weights = [[]]
        self.new_global_bias = []
        self.new_generated_proof = ""

    def start_round(self):
        # clear the parameters for the new round:
        self.clear_round()
        # fetch the round number from the smart contract:
        self.round_number = self.fetch_sc_round_number()

    def finish_round(self):
        # select devices:
        selected_device_ids = self.select_devices()
        for device_id in selected_device_ids:
            self.selected_device_data[device_id] = self.stored_device_data[device_id]
        # calculate moving average:
        self.new_global_weights, self.new_global_bias = self.calculate_moving_average()
        # generate the proof:
        # self.new_generated_proof = self.generate_proof()  # TODO
        # send the calculated global weights and bias to the smart contract:
        self.set_new_wb_in_sc()


# endregion

# moving average:


def moving_average_weights(
    new_weights: dict, participant_count: int, temp_global_weights: dict
) -> dict:
    k = participant_count
    if k > 0:
        if k == 1:
            for i in range(len(new_weights)):
                temp_global_weights[i] = new_weights[i]
        else:
            for i in range(len(new_weights)):
                res = [0] * len(new_weights[i])
                row_new = new_weights[i]
                row_old = temp_global_weights[i]

                for j in range(len(row_old)):
                    res[j] = row_old[j] + (row_new[j] - row_old[j]) / k

                temp_global_weights[i] = res

    return temp_global_weights


def moving_average_bias(
    new_bias: dict, participant_count: int, temp_global_bias: dict
) -> dict:
    k = participant_count
    if k > 0:
        if k == 1:
            for i in range(len(new_bias)):
                temp_global_bias[i] = new_bias[i]
        else:
            for i in range(len(new_bias)):
                old_bias_i = temp_global_bias[i]
                new_bias_i = new_bias[i]
                res = old_bias_i + (new_bias_i - old_bias_i) / k
                temp_global_bias[i] = res

    return temp_global_bias


def moving_average_all(
    new_weights: dict,
    new_bias: dict,
    participant_count: int,
    temp_global_weights: dict,
    temp_global_bias: dict,
) -> dict:
    # weights:
    temp_global_weights = moving_average_weights(
        new_weights, participant_count, temp_global_weights
    )
    # bias:
    temp_global_bias = moving_average_bias(
        new_bias, participant_count, temp_global_bias
    )
    # return new temp_global_weights and temp_global_bias
    return temp_global_weights, temp_global_bias