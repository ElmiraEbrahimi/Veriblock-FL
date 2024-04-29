import threading
import time

from edge_device.edge_device import EdgeDevice
from middleware.connection_manager import ConnectionManager
from middleware.middleware import MiddleWare
from utils.utils import get_config_file_path, read_yaml


def start_Device(deviceName, accountNr, blockchain_connection, config_file):
    edgeDevice = EdgeDevice(deviceName, config_file=config_file)
    thread = threading.Thread(target=edgeDevice.start_EdgeDevice)
    thread.start()
    middleware = MiddleWare(
        connection_manager=blockchain_connection,
        deviceName=deviceName,
        accountNR=accountNr,
        configFile=config_file,
    )
    middleware.start_Middleware()


if __name__ == "__main__":
    _config_file_path = get_config_file_path()
    config_file = read_yaml(_config_file_path)
    participant_count = config_file["DEFAULT"]["NumberOfParticipants"]

    barrier = threading.Barrier(participant_count)

    blockchain_connection = ConnectionManager(
        config_file=config_file, participant_count=participant_count, barrier=barrier
    )
    blockchain_connection.connect()
    for i in range(participant_count):
        thread = threading.Thread(
            target=start_Device,
            args=["Device_" + str(i + 1), i, blockchain_connection, config_file],
        )
        thread.start()
        time.sleep(1)
