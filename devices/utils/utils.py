import json
import os
import time

import yaml
from dotenv import load_dotenv


def get_project_root_from_env():
    load_dotenv(override=True)
    return os.getenv("ProjectRoot")


def get_config_file_path():
    return get_project_root_from_env() + "/CONFIG.yaml"


def fix_config_yaml_project_root_path():
    project_root = get_project_root_from_env()
    yaml_file_path = get_config_file_path()

    with open(yaml_file_path, "r") as file:
        config = yaml.safe_load(file)
    config["DEFAULT"]["ProjectRoot"] = project_root
    with open(yaml_file_path, "w") as file:
        yaml.dump(config, file)


def read_json(file_path):
    with open(file_path, "r") as f:
        return json.load(f)


def read_yaml(file_path):
    with open(file_path, "r") as f:
        return yaml.safe_load(f)


def wait_for_process(process, sleep_time: float = 0.2):
    # check process is done + write to disk delay window
    # while process.poll() is None:
    time.sleep(sleep_time)


def wait_for_file_creation(file_path: str, sleep_time: float = 0.5):
    is_file_found = os.path.exists(file_path)
    while not is_file_found:
        print(f"Waiting for file creation... ({file_path})")
        time.sleep(sleep_time)
        is_file_found = os.path.exists(file_path)
