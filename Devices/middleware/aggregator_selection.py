from typing import Optional

from middleware.aggregator import OffChainAggregator


class AggregatorSelector:
    def __init__(
        self,
        connection_manager,
        aggregators: list[OffChainAggregator],
        account_number: int,
        is_perform_proof_on: bool,
    ) -> None:
        self.connection_manager = connection_manager
        self.aggregators = aggregators
        self.account_number = account_number
        self._selected_aggregator: OffChainAggregator = None
        self.is_initialized = False
        self.is_perform_proof_on = is_perform_proof_on
        # set initial selected aggregator:
        self.stake_amount_wei: int = 500_000
        self.stake_gas: int = 21_000
        self.select()

    def _stake_agg(self, receiver_aggregator: OffChainAggregator):
        # get the receiver
        receiver_address = receiver_aggregator.blockchain_account
        # transfer:
        print(f"Staking {receiver_aggregator.name}...")
        tx_hash = self.connection_manager.web3Connection.eth.sendTransaction(
            {
                "from": self.connection_manager.web3Connection.eth.accounts[
                    self.account_number
                ],
                "to": receiver_address,
                "value": self.stake_amount_wei,
                "gas": self.stake_gas,
                "gasPrice": self.connection_manager.web3Connection.toWei("50", "gwei"),
            }
        )
        self.connection_manager._await_transaction(
            tx_hash, self.account_number, desc="eth.sendTransaction (stake aggregator)"
        )

    def _stake_clients(self, clients_addr: list[str]):
        # transfer:
        for c_addr in clients_addr:
            print(f"Staking client address = {c_addr}...")
            tx_hash = self.connection_manager.web3Connection.eth.sendTransaction(
                {
                    "from": self.connection_manager.web3Connection.eth.accounts[
                        self.account_number
                    ],
                    "to": c_addr,
                    "value": self.stake_amount_wei,
                    "gas": self.stake_gas,
                    "gasPrice": self.connection_manager.web3Connection.toWei(
                        "50", "gwei"
                    ),
                }
            )
            self.connection_manager._await_transaction(
                tx_hash, self.account_number, desc="eth.sendTransaction (stake client)"
            )

    def select(self) -> None:
        # select the new one:
        winner_agg_addr, winner_clients_addr, next_round_agg_idx = (
            self.connection_manager.FLcontractDeployed.functions.getStakeWinnersAndSelectedAggregatorIndex().call({"from": self.connection_manager.web3Connection.eth.accounts[self.account_number]})
        )
        print(f"Next round's selected aggregator index = {next_round_agg_idx}")
        self._selected_aggregator = self.aggregators[next_round_agg_idx]

        if self.is_initialized and self.is_perform_proof_on:
            # clear the stake winners from blockchain:
            txhash = self.connection_manager.FLcontractDeployed.functions.clearStakeWinners().transact(
                {
                    "from": self.connection_manager.web3Connection.eth.accounts[
                        self.account_number
                    ]
                }
            )
            self.connection_manager._await_transaction(
                txhash,
                accountNr=self.account_number,
                desc="functions.clearStakeWinners",
            )

            # stake aggregator:
            if winner_agg_addr:
                agg_obj = self.get_agg_obj_from_address(addr=winner_agg_addr)
                if not agg_obj:
                    raise Exception(
                        f"Error Staking Aggregator: Address was not found in the defined aggregator addresses! ({agg_obj=}, {winner_agg_addr=})"
                    )
                print(f"Aggregator to be staked = {agg_obj.name}")
                self._stake_agg(agg_obj)
            # stake clients:
            if not winner_clients_addr or not isinstance(winner_clients_addr, list):
                raise Exception(
                    f"Error Staking Clients: Invalid client list ({winner_clients_addr=})"
                )
            self._stake_clients(winner_clients_addr)
        self.is_initialized = True

    def store_device_wb(self, *args, **kwargs):
        return self._selected_aggregator.store_device_wb(*args, **kwargs)

    def start_round(self, *args, **kwargs):
        return self._selected_aggregator.start_round(*args, **kwargs)

    def finish_round(self, *args, **kwargs):
        res = self._selected_aggregator.finish_round(*args, **kwargs)
        self.select()
        return res

    def get_agg_obj_from_address(self, addr: str) -> Optional[OffChainAggregator]:
        for agg in self.aggregators:
            if agg.blockchain_account == addr:
                return agg
        return None
