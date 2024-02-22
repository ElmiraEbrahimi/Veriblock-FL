from typing import Optional

from Devices.MiddleWare.aggregator.hash import mimc_hash


# region device (node-manager)


class Device:
    def __init__(
        self,
        address: str,
        weights: Optional[list[list[int]]],
        bias: Optional[list[int]],
        aggregator: Optional[object],
    ):
        self.address = address
        self.weights = weights
        self.bias = bias
        self.wb_hash = self.generate_wb_hash(w=self.weights, b=self.bias)
        self.aggregator = aggregator

    def __eq__(self, __value: object) -> bool:
        return self.address == __value.address

    def __hash__(self) -> int:
        return hash(self.address)

    def generate_wb_hash(self, w, b):
        hash = mimc_hash(w=w, b=b)
        return hash

    def send_wb_to_aggregator(self):
        self.aggregator.set_device_wb(
            device_id=self.address, w=self.weights, b=self.bias
        )

    def send_wb_hash_to_smart_contract(self):
        # cal


# endregion

# region off-chain aggregator:


class OffChainAggregator:

    def __init__(self, blockchain_account: str):
        self.blockchain_account = blockchain_account
        self.round_number: int = 0
        # address: [wb_hash, w, b]
        self.stored_device_data: dict[str, list[str, list[list[int]], list[int]]] = {}
        self.selected_device_data: dict[str, list[list[int], list[int]]] = {}
        self.new_global_weights: list[list[int]] = []
        self.new_global_bias: list[int] = []
        self.new_generated_proof = ""

    # region smart contract functions

    def fetch_sc_round_number(self):
        pass

    def is_wb_hash_in_sc(self, wb_hash: str) -> bool:
        pass

    def set_new_wb_in_sc(self):
        pass

    # endregion

    def store_device_wb(
        self, device_id: str, w: list[list[list[int]]], b: list[int]
    ) -> bool:
        wb_hash = mimc_hash(w=w, b=b)
        if not self.is_wb_hash_in_sc(wb_hash):
            # hash not in the smart contract:
            return False
        # hash is in smart contract:
        self.stored_device_data[device_id] = [wb_hash, w, b]
        return True

    def select_devices(self) -> dict[str, list[str, list[list[int]], list[int]]]:
        # TODO: select devices based on some criteria
        selected_devices = self.stored_device_data
        return selected_devices

    def calculate_moving_average(
        self, selected_devices: dict[str, list[list[int], list[int]]]
    ) -> list[list[list[int]], list[int]]:
        # TODO: algorithm to calculate ma for a list of devices and return w,b
        pass

    def generate_proof(self) -> str:  # for the calculated global weights and bias
        # TODO: call zokrates to generate aggregator proof
        pass

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
        self.selected_device_data = self.select_devices()
        # calculate moving average:
        self.new_global_weights, self.new_global_bias = self.calculate_moving_average(
            self.selected_device_data
        )
        # generate the proof:
        self.new_generated_proof = self.generate_proof()
        # send the calculated global weights and bias to the smart contract:
        self.set_sc_global_params()


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
