import csv
import datetime
import logging

from web3 import Web3

logger = logging.getLogger("gas_logger")
logger.setLevel(logging.DEBUG)
file_handler = logging.FileHandler("gas_logs.log")
file_handler.setLevel(logging.DEBUG)
# console_handler = logging.StreamHandler()
# console_handler.setLevel(logging.DEBUG)
formatter = logging.Formatter("%(asctime)s - %(name)s - %(levelname)s - %(message)s")
file_handler.setFormatter(formatter)
# console_handler.setFormatter(formatter)
logger.addHandler(file_handler)
# logger.addHandler(console_handler)


def get_current_balance(
    web3: Web3,
    account_address: str,
    round: int,
    source: str,
    verbose: bool = False,
    csv_log: bool = True,
):
    balance = web3.eth.getBalance(account_address)
    used = 1000000000000000000000000000 - int(balance)
    used_eth = web3.fromWei(used, "ether")

    if verbose or csv_log:
        # dt, round, source, balance, used, used_eth, (used / 3,086,181,642),
        data = [
            datetime.datetime.now(),
            f"Round-{round}",
            source,
            balance,
            used,
            used_eth,
            used / 3_086_181_642,
        ]
        if verbose:
            print(f"datetime, source, gas used: {data}")
        if csv_log:
            csv_file = "balance.csv"
            with open(csv_file, mode="a", newline="") as file:
                writer = csv.writer(file)
                writer.writerow(data)

    return balance


def log_receipt(receipt: dict, account: int, desc: str):
    if not receipt:
        raise Exception("Empty receipt received")

    msg = f"account={str(account)}, desc={str(desc)}, receipt={str(receipt)}"
    logger.debug(msg)
