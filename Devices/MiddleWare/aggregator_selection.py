from middleware.aggregator import OffChainAggregator


class AggregatorSelector:
    def __init__(
        self,
        connection_manager,
        aggregators: list[OffChainAggregator],
        account_number: int,
    ) -> None:
        self.connection_manager = connection_manager
        self.aggregators = aggregators
        self.account_number = account_number
        self._selected_aggregator: OffChainAggregator = None
        # set initial selected aggregator:
        self.stake_amount_wei: int = 1000
        self.select()

    def _stake(self, receiver_aggregator: OffChainAggregator):
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
                "gas": 21000,
                "gasPrice": self.connection_manager.web3Connection.toWei("50", "gwei"),
            }
        )
        self.connection_manager._await_transaction(tx_hash, self.account_number)

    def select(self) -> None:
        # stake the past aggregator:
        previously_selected_agg = self._selected_aggregator
        if previously_selected_agg:
            self._stake(previously_selected_agg)

        # select the new one:
        selected_agg_index = self.connection_manager.FLcontractDeployed.functions.getSelectedAggregatorIndex().call(
            {
                "from": self.connection_manager.web3Connection.eth.accounts[
                    self.account_number
                ]
            }
        )
        print(f"Selected aggregator index = {selected_agg_index}")
        self._selected_aggregator = self.aggregators[selected_agg_index]

    def store_device_wb(self, *args, **kwargs):
        return self._selected_aggregator.store_device_wb(*args, **kwargs)

    def start_round(self, *args, **kwargs):
        return self._selected_aggregator.start_round(*args, **kwargs)

    def finish_round(self, *args, **kwargs):
        res = self._selected_aggregator.finish_round(*args, **kwargs)
        self.select()
        return res
