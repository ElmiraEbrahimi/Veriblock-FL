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

# ToDo aggregator class
        