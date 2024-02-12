from typing import Optional

import random


class Device:
    def __init__(
        self,
        address: str,
        weights: Optional[list[list[int]]],
        bias: Optional[list[int]],
    ):
        self.address = address
        self.weights = weights
        self.bias = bias
        self.wb_hash = None
        self._hash_approved: bool = False

    def __eq__(self, __value: object) -> bool:
        return self.address == __value.address

    def __hash__(self) -> int:
        return hash(self.address)

    def generate_and_store_wb_hash(self):
        self.wb_hash = None

    @property
    def hash_approved(self) -> bool:
        return self._hash_approved

    def set_hash_approved(self, value: bool):
        self._hash_approved = value


class OffChainAggregator:

    def __init__(self, blockchain_account: str):
        self.blockchain_account = blockchain_account
        self.round_number: int = 0
        self.devices: dict[Device] = {}
        self.calculated_global_weights: list[list[int]] = [[]]
        self.calculated_global_bias: list[int] = []
        self.generated_proof = None

    # region smart contract functions

    def fetch_sc_round_number(self):
        pass

    def fetch_sc_device_wb_hash(self, device: Device) -> str:
        pass

    def set_sc_global_params(self):
        pass

    # endregion

    def store_device_wb(self, new_device: Device):
        generated_hash = new_device.generate_wb_hash()
        fetched_hash = self.fetch_sc_device_wb_hash(new_device)
        if fetched_hash == generated_hash:  # if hashes match:
            new_device.set_hash_approved(value=True)
            self.devices[new_device] = new_device

    def run_client_selection(self) -> list[Device]:
        selected_devices = []
        for device in self.devices:
            if device.hash_approved:
                # random selection algorithm:
                result = random.choice([True, False])
                if result:
                    selected_devices.append(device)
        return selected_devices

    def calculate_moving_average(
        self, selected_devices: list[Device]
    ) -> tuple[list[list[int]], list[int]]:
        # TODO: algorithm to calculate ma for a list of devices and return w,b
        pass

    def generate_proof(self):  # for the calculated global weights and bias
        # TODO: generate
        pass

    def start_round(self):
        # fetch the round number from the smart contract:
        self.round_number = self.fetch_sc_round_number()
        # clear the parameters for the new round:
        self.devices = {}
        self.calculated_global_weights = []
        self.calculated_global_bias = []
        self.generated_proof = None

    def finish_round(self):
        # generate the proof:
        self.generate_proof()
        # save the calculated global weights and bias to the smart contract:
        self.set_sc_global_params()


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
