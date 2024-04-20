import copy
import json
import subprocess

import numpy as np
from middleware.hash import convert_matrix, mimc_hash
from utils.gas import get_current_balance
from utils.utils import (
    get_project_root_from_env,
    wait_for_file_creation,
)
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
                new_weights[i][j] = new_weights[i][j] + tres

    # Apply the average adjustments to the global weights
    for i in range(len(global_weights)):
        for j in range(len(global_weights[i])):
            new_weights[i][j] = new_weights[i][j] + global_weights[i][j]

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
            new_bias[i] = new_bias[i] + tres

    # Apply the average adjustments to the global bias
    for i in range(len(global_bias)):
        new_bias[i] = new_bias[i] + global_bias[i]

    return new_bias


# region off-chain aggregator:t


class OffChainAggregator:
    def __init__(
        self,
        name: str,
        connection_manager: object,
        blockchain_account: str,
        ipfs: object,
        global_w: list[list[int]],
        global_b: list[int],
        is_no_proof: bool,
    ):
        self.name = name
        self.connection_manager = connection_manager
        self.blockchain_account = blockchain_account
        self.ipfs = ipfs
        self.round_number: int = 0
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
        self.is_no_proof = is_no_proof

    # region smart contract functions

    def _get_sc_round_number(self):
        round = (
            self.connection_manager.FLcontractDeployed.functions.getRoundNumber().call(
                {"from": self.blockchain_account}
            )
        )
        return int(round)

    def _is_wb_hash_in_sc(self, wb_hash: str) -> bool:
        wb_hashes = self.connection_manager.FLcontractDeployed.functions.getAllHashValues().call(
            {"from": self.blockchain_account}
        )
        # print(f"Checking {wb_hash=} in wb_hashes...")
        return str(wb_hash) in wb_hashes

    def _send_aggregator_wb_link(self) -> bool:
        print(f"{self.name} calling function _send_aggregator_wb_link...")
        # print(
        #     f"Calling function __check_ZKP_aggregator with arg {self.new_generated_proof=}"
        # )
        a, b, c, inputs = self._check_ZKP_aggregator(self.new_generated_proof)

        # save to ipfs:
        gw_ipfs_link = self._save_gw_to_ipfs(self.new_global_weights)
        gb_ipfs_link = self._save_gb_to_ipfs(self.new_global_bias)

        # send to smart contract:
        thxHash = (
            self.connection_manager.FLcontractDeployed.functions.send_aggregator_wb(
                str(self.gdigest),
                gw_ipfs_link,
                gb_ipfs_link,
                a,
                b,
                c,
                inputs,
            ).transact({"from": self.blockchain_account})
        )
        self.connection_manager._await_Transaction(thxHash, accountNr=self.name)

        # save to Blockchain Client:
        self.connection_manager.weight_ipfs_link = gw_ipfs_link
        self.connection_manager.bias_ipfs_link = gb_ipfs_link

        print(f"Successfully {self.name} aggregator saved new ipfs links")

        return True

    # endregion

    def _save_gw_to_ipfs(self, weights) -> str:
        weights = [[int(x) for x in y] for y in weights]
        link = self.ipfs.save_global_weight(weights)
        return link

    def _save_gb_to_ipfs(self, bias) -> str:
        bias = [int(x) for x in bias]
        link = self.ipfs.save_global_bias(bias)
        return link

    def _check_ZKP_aggregator(self, proof):
        if self.is_no_proof:
            a_size = 2
            input_size = 10
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

        return a, b, c, inputs

    def store_device_wb(
        self,
        device_id: str,
        w: list[list[list[int]]],
        b: list[int],
        mse_score: float,
    ) -> bool:
        w_c, _ = convert_matrix(w)
        b_c, _ = convert_matrix(b)
        wb_hash = str(mimc_hash(w=w_c, b=b_c))
        if not self._is_wb_hash_in_sc(wb_hash):
            # hash not in the smart contract:
            return False
        # hash is in smart contract:
        print(f"The hash {wb_hash} was found in the smart contract.")
        wb_hash_int = int(wb_hash)
        self.stored_device_data[device_id] = [wb_hash_int, w, b, mse_score]
        return True

    def _select_devices(self, epsilon=1, select_count=3) -> list[str]:
        selected_device_ids = list(self.stored_device_data.keys())
        return selected_device_ids

    def _calculate_moving_average(self) -> tuple:
        selected_weights = [device[1] for device in self.selected_device_data.values()]
        selected_bias = [device[2] for device in self.selected_device_data.values()]
        new_w = moving_average_weights(
            selected_weights, len(selected_weights), self.global_w
        )
        new_b = moving_average_bias(selected_bias, len(selected_bias), self.global_b)

        # convert to int:
        new_w = [[int(x) for x in y] for y in new_w]
        new_b = [int(x) for x in new_b]

        return new_w, new_b

    def _generate_proof(self) -> str:
        def args_parser(args):
            res = ""
            for arg in args:
                if isinstance(arg, (list, np.ndarray)):
                    flattened_arg = np.ravel(arg)  # Flatten the array
                    # print(f"args_parser - Size of flattened_arg: {flattened_arg.size}")
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
                    # print(f"Processed arg: {clean_arg}")
                    res += clean_arg + " "
            res = res.strip()
            # Final debug print to check the entire argument string
            # print(f"Final argument string for ZoKrates: {res}")
            # print(f"Length of the final argument string: {len(res)}")
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

        self.global_w = [[int(x) for x in y] for y in self.global_w]
        self.global_b = [int(x) for x in self.global_b]
        self.new_global_weights = [[int(x) for x in y] for y in self.new_global_weights]
        self.new_global_bias = [int(x) for x in self.new_global_bias]

        zokrates = "zokrates"
        aggregator_zokrates_base = (
            get_project_root_from_env()
            + self.connection_manager.config["DEFAULT"]["ZokratesBase"]
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
            # print(f"{wb_hash=}")
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
        expected_global_b, expected_global_b_sign = convert_matrix_and_scale(
            self.new_global_bias
        )

        # print(
        #     f"Expected global w and b before calculating mimc_hash:\n    Expected global w: {expected_global_w}\n    Expected global b: {expected_global_b}"
        # )

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

        # print("local_w", len(local_w), len(local_w[0]))
        # print("local_w_sign", len(local_w_sign))
        # print("local_b", len(local_b))
        # print("local_b_sign", len(local_b_sign))
        # print("global_w", len(global_w), len(global_w[0]))
        # print("global_w_sign", len(global_w_sign))
        # print("global_b", len(global_b))
        # print("global_b_sign", len(global_b_sign))
        # print("sc_lhashes", len(sc_lhashes))
        # print("expected_global_w", len(expected_global_w), len(expected_global_w[0]))
        # print("expected_global_w_sign", len(expected_global_w_sign))
        # print("expected_global_b", len(expected_global_b))
        # print("expected_global_b_sign", len(expected_global_b_sign))
        # print("self.gdigest", 1)

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
        if g.returncode != 0:
            print(
                f"Error: aggregator returned non-zero. {g.stderr.decode()=}, {g.stdout.decode()=}",
            )
        print("aggregator output:", g.stdout.decode())

        # check file is created:
        wait_for_file_creation(file_path=witness_path)

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
        # wait_for_process(g)
        if g.returncode != 0:
            print(
                f"Error: aggregator returned non-zero. {g.stderr.decode()=}, {g.stdout.decode()=}",
            )
        print("aggregator output:", g.stdout.decode())

        # check file is created:
        wait_for_file_creation(file_path=proof_path)

        proof = None
        with open(proof_path, "r+") as f:
            proof = json.load(f)
        return proof

    def _clear_round(self):
        self.stored_device_data = {}
        self.selected_device_data = {}
        self.new_global_weights = []
        self.new_global_bias = []
        self.new_generated_proof = ""
        self.gdigest = ""

    def start_round(self):
        print(f"{self.name} round is ongoing now...")
        # gas usage:
        get_current_balance(
            web3=self.connection_manager.web3Connection,
            account_address=self.blockchain_account,
            round=self.round_number,
            source=f"{self.name} (Start) ",
        )
        # set global weights and bias:
        if self.new_global_weights:
            self.global_w = copy.deepcopy(self.new_global_weights)
        if self.new_global_bias:
            self.global_b = copy.deepcopy(self.new_global_bias)
        # clear the parameters for the new round:
        self._clear_round()
        # fetch the round number from the smart contract:
        self.round_number = self._get_sc_round_number()

    def finish_round(self):
        # select devices:
        selected_device_ids = self._select_devices()
        for device_id in selected_device_ids:
            self.selected_device_data[device_id] = self.stored_device_data[device_id]

        participant_count = len(self.selected_device_data)
        if participant_count == self.connection_manager.participant_count:
            print(f"Finishing {self.name} round now...")

            # calculate moving average:
            print(f"{self.name} calculating moving averages...")
            self.new_global_weights, self.new_global_bias = (
                self._calculate_moving_average()
            )

            if self.new_global_weights and self.new_global_bias:
                if not self.is_no_proof:
                    # generate the proof:
                    print(f"Generating {self.name} proof...")
                    self.new_generated_proof = self._generate_proof()
                else:
                    print(f"Skipping the generation of {self.name} proof...")

                # send the calculated global weights and bias to the smart contract:
                print(f"Sending {self.name} wb links to contract...")
                self._send_aggregator_wb_link()
                # gas usage:
                get_current_balance(
                    web3=self.connection_manager.web3Connection,
                    account_address=self.blockchain_account,
                    round=self.round_number,
                    source=f"{self.name} (Finish)",
                )
            else:
                print(
                    f"{self.name} has empty new global weights or bias. Skipping saving to ipfs..."
                )
        else:
            print(
                f"Skipping to finish off {self.name}  aggregator: Not enough participants ({participant_count=}, expected={self.connection_manager.participant_count})."
            )


# endregion
