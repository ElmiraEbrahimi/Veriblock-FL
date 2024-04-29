import threading
import time

from utils.utils import get_config_file_path, read_yaml

from devices.edge_device.edge_device import EdgeDevice
from devices.middleware.blockchain_client import BlockChainConnection
from devices.middleware.middleware import MiddleWare


def start_Device(deviceName, accountNr, blockchain_connection, config_file):
    edgeDevice = EdgeDevice(deviceName, config_file=config_file)
    thread = threading.Thread(target=edgeDevice.start_EdgeDevice)
    thread.start()
    middleware = MiddleWare(
        blockchain_connection=blockchain_connection,
        deviceName=deviceName,
        accountNR=accountNr,
        configFile=config_file,
    )
    middleware.start_Middleware()


if __name__ == "__main__":
    _config_file_path = get_config_file_path()
    config_file = read_yaml(_config_file_path)
    blockchain_connection = BlockChainConnection(config_file=config_file)
    blockchain_connection.connect()
    for i in range(config_file["DEFAULT"]["NumberOfParticipants"]):
        thread = threading.Thread(
            target=start_Device,
            args=["Device_" + str(i + 1), i, blockchain_connection, config_file],
        )
        thread.start()
        time.sleep(1)
