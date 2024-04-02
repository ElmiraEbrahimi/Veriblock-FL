import copy
import json
import subprocess
from typing import Optional

import numpy as np
from MiddleWare.hash import convert_matrix, mimc_hash
from utils.utils import get_project_root_from_env
from web3 import Web3

SNARK_SCALAR_FIELD = (
    21888242871839275222246405745257275088548364400416034343698204186575808495617
)


def moving_average_weights(
    local_weights: dict, participant_count: int, global_weights: dict
) -> dict:
    # Initialize new_weights with the same structure as global_weights
    new_weights = [
        [0 for _ in range(len(global_weights[0]))] for _ in range(len(global_weights))
    ]
    k = participant_count

    # Adjust weights based on the formula provided
    for client in range(len(local_weights)):
        for i in range(len(global_weights)):
            for j in range(len(global_weights[i])):
                tres = (local_weights[client][i][j] - global_weights[i][j]) / k
                new_weights[i][j] = (new_weights[i][j] + tres) 

    # Apply the average adjustments to the global weights
    for i in range(len(global_weights)):
        for j in range(len(global_weights[i])):
            new_weights[i][j] = (
                new_weights[i][j] + global_weights[i][j]
            ) 

    return new_weights


def moving_average_bias(
    local_bias: dict, participant_count: int, global_bias: dict
) -> dict:
    # Initialize new_bias with the same structure as global_bias
    new_bias = [0 for _ in range(len(global_bias))]
    k = participant_count

    # Adjust bias based on the formula provided
    for client in range(len(local_bias)):
        for i in range(len(global_bias)):
            tres = (local_bias[client][i] - global_bias[i]) / k
            new_bias[i] = (new_bias[i] + tres)

    # Apply the average adjustments to the global bias
    for i in range(len(global_bias)):
        new_bias[i] = (new_bias[i] + global_bias[i]) 

    return new_bias


    

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
        w_c, _ = convert_matrix(w)
        b_c, _ = convert_matrix(b)
        hash = mimc_hash(w=w_c, b=b_c)
        return hash

    def send_wb_to_aggregator(self):
        self.aggregator.store_device_wb(
            device_id=self.address,
            w=self.weights,
            b=self.bias,
            mse_score=self.mse_score,
        )


# endregion

# region off-chain aggregator:t


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
        self.precision = 10000  # Precision value for scaling

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
        print(f"Checking {wb_hash=} in wb_hashes...")
        return str(wb_hash) in wb_hashes

    # def get_all_hashes_as_integers_from_contract(self) -> list[int]:
    #     try:
    #         all_hashes_str = self.blockchain_connection.FLcontractDeployed.functions.getAllHashValues().call()
    #         all_hashes_int = [int(h) for h in all_hashes_str]  # Assuming the hashes are hexadecimal strings
    #         print("All hashes have been retrieved and converted to integers.")
    #         return all_hashes_int
    #     except Exception as e:
    #         print(f"Failed to retrieve or convert hashes: {e}")
    #         return []

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
                str(self.gdigest), gw_ipfs_link, gb_ipfs_link, a, b, c, inputs
            ).transact({"from": self.blockchain_account})
        )
        self.blockchain_connection.web3Connection.eth.wait_for_transaction_receipt(
            thxHash
        )

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
        w_c, _ = convert_matrix(w)
        b_c, _ = convert_matrix(b)
        wb_hash = str(mimc_hash(w=w_c, b=b_c))
        if not self.is_wb_hash_in_sc(wb_hash):
            # hash not in the smart contract:
            return False
        # hash is in smart contract:
        print(f"The hash {wb_hash} was found in the smart contract.")
        wb_hash_int = int(wb_hash)
        self.stored_device_data[device_id] = [wb_hash_int, w, b, mse_score]
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
        new_w = moving_average_weights(
            selected_weights, len(selected_weights), self.global_w
        )
        new_b = moving_average_bias(selected_bias, len(selected_bias), self.global_b)
        return copy.deepcopy(new_w), copy.deepcopy(new_b)

    # def generate_proof(self) -> str:
    #     def args_parser(args):
    #         res = ""
    #         for arg in range(len(args)):
    #             entry = args[arg]
    #             if isinstance(entry, (list, np.ndarray)):
    #                 for i in range(len(entry)):
    #                     row_i = entry[i]
    #                     if isinstance(row_i, (list, np.ndarray)):
    #                         for j in range(len(row_i)):
    #                             val = row_i[j]
    #                             res += str(val) + " "
    #                     else:
    #                         res += str(row_i) + " "
    #             else:
    #                 res += str(args[arg]) + " "
    #         res = res[:-1]
    #         return res

    def generate_proof(self) -> str:
        def args_parser(args):
            res = ""
            for arg in args:
                if isinstance(arg, (list, np.ndarray)):
                    flattened_arg = np.ravel(arg)  # Flatten the array
                    print(f"args_parser - Size of flattened_arg: {flattened_arg.size}")
                    for sub_arg in flattened_arg:  # Flatten the array
                        # Remove potential newline and carriage return characters
                        clean_sub_arg = (
                            str(sub_arg).strip().replace("\n", "").replace("\r", "")
                        )
                        # Debug print to check each argument
                        # print(f"Processed arg: {clean_sub_arg}")
                        res += clean_sub_arg + " "
                else:
                    clean_arg = str(arg).strip().replace("\n", "").replace("\r", "")
                    # Debug print to check each argument
                    print(f"Processed arg: {clean_arg}")
                    res += clean_arg + " "
            res = res.strip()
            # Final debug print to check the entire argument string
            print(f"Final argument string for ZoKrates: {res}")
            print(f"Length of the final argument string: {len(res)}")
            return res

        def convert_matrix(m):
            max_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617
            m = np.array(m)
            return np.where(m < 0, max_field + m, m), np.where(m > 0, 0, 1)

        def convert_matrix_and_scale(m):
            max_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617
            m = np.array(m) * self.precision  # Scale by precision
            m = m.astype(int)  # Convert to integer immediately
            m = np.where(m < 0, max_field + m, m)  # Adjust negative values
            sign_matrix = np.where(m > 0, 0, 1)  # Create a sign matrix
            return m, sign_matrix

        zokrates = "zokrates"
        aggregator_zokrates_base = (
            get_project_root_from_env()
            + self.blockchain_connection.config["DEFAULT"]["ZokratesBase"]
            + "aggregator/"
        )

        # convert local_w and local_b to a single list:
        local_w_list = []
        local_b_list = []
        for selected_device_id in self.selected_device_data:
            # weights:
            device_w = copy.deepcopy(self.selected_device_data[selected_device_id][1])
            local_w_list.append(device_w)
            # bias:
            device_b = copy.deepcopy(self.selected_device_data[selected_device_id][2])
            local_b_list.append(device_b)

        local_w, local_w_sign = convert_matrix(local_w_list)
        local_b, local_b_sign = convert_matrix(local_b_list)
        # convert global_w and global_b to a single list:
        global_w, global_w_sign = convert_matrix(self.global_w)
        global_b, global_b_sign = convert_matrix(self.global_b)
        # aggregator hash:

        sc_lhashes = []
        # sc_lhashes= self.get_all_hashes_as_integers_from_contract()
        for selected_device_id in self.selected_device_data:
            wb_hash = self.selected_device_data[selected_device_id][0]
            print(f"{wb_hash=}")
            # int_wb_hash = int(wb_hash)
            # sc_lhashes.append(int_wb_hash)
            sc_lhashes.append(wb_hash)
            # Print out the contents and types of sc_lhashes
            # print("Contents of sc_lhashes:", sc_lhashes)
            # print("Types of elements in sc_lhashes:", [type(h) for h in sc_lhashes])
        # sc_lhashes, _ = convert_matrix_and_scale(sc_lhashes)  # TODO ?  we shouldn't convert the hash. am I right?
        # I got the error: Too many values to unpack. so I removed the below line
        # sc_lhashes, _ = sc_lhashes  # TODO ? # what is this TODO for . we can remove this line

        # expected global weights and bias:
        expected_global_w, expected_global_w_sign = convert_matrix_and_scale(
            self.new_global_weights
        )
        expected_global_b, expected_global_b_sign = convert_matrix_and_scale(self.new_global_bias)
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
            expected_global_w_sign,
            expected_global_b,
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
        # print(f"{args=}")
        # print(f"{g.stdout=}")
        # print(f"{g.stderr=}")
        # g = subprocess.run(
        #     zokrates_compute_witness, stdout=subprocess.PIPE, stderr=subprocess.PIPE
        # )
        # print("STDOUT:", g.stdout.decode())
        # print("STDERR:", g.stderr.decode())
        # if g.returncode != 0:
        #     # Handle the error, e.g., by raising an exception or logging the error
        #     print("Error in running ZoKrates compute-witness.")
        #     raise Exception(f"ZoKrates compute-witness error: {g.stderr.decode()}")

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
        proof = None
        with open(proof_path, "r+") as f:
            proof = json.load(f)
        return proof

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
        print("Finishing aggregator round...")
        # select devices:
        selected_device_ids = self.select_devices()
        for device_id in selected_device_ids:
            self.selected_device_data[device_id] = self.stored_device_data[device_id]

        participant_count = len(self.selected_device_data)
        if participant_count >= 1:
            # calculate moving average:
            print("Calculating moving averages...")
            self.new_global_weights, self.new_global_bias = (
                self.calculate_moving_average()
            )
            # generate the proof:
            print("Generating aggregator proof...")
            self.new_generated_proof = self.generate_proof()
            # send the calculated global weights and bias to the smart contract:
            print("Sending aggregator wb links to contract...")
            self._send_aggregator_wb_link()
        else:
            print(
                "No participant found for aggregator to process. Skipping this round..."
            )

        # release lock:
        if self.is_round_ongoing:
            self.is_round_ongoing = False


# endregion
