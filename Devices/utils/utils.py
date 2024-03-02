# import json
# import os
# import yaml
# import dotenv

# def get_project_root_from_env():
#     dotenv.load_dotenv()
#     return os.getenv("ProjectRoot")

# def get_config_file_path():
#     project_root = get_project_root_from_env()
#     if project_root is None:
#         raise ValueError("ProjectRoot environment variable is not set.")
#     # Correctly use os.path.join to ensure the path is correctly formatted for the OS
#     return os.path.join(project_root, "CONFIG.yaml")

# def fix_config_yaml_project_root_path():
#     project_root = get_project_root_from_env()
#     yaml_file_path = get_config_file_path()
#     with open(yaml_file_path, "r") as file:
#         config = yaml.safe_load(file)
#     config["DEFAULT"]["ProjectRoot"] = project_root
#     with open(yaml_file_path, "w") as file:
#         yaml.dump(config, file)

# def read_json(file_path):
#     with open(file_path, "r") as f:
#         return json.load(f)

# def read_yaml(file_path):
#     with open(file_path, "r") as f:
#         return yaml.safe_load(f)

import json
import yaml

def read_json(file_path):
    with open(file_path, "r") as f:
        return json.load(f)

def read_yaml(file_path):
    with open(file_path, "r") as f:
        return yaml.safe_load(f)