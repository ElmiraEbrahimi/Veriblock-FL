import os
import pickle


class IPFSConnector:
    def __init__(self) -> None:
        self.data_file_path = "ipfs.pickle"
        # if file exists, delete it:
        if os.path.exists(self.data_file_path):
            os.remove(self.data_file_path)
        self.data: dict[str, str] = {}  # key -> value
        self.inner_counter = 0
        # initialize the data:
        self._refresh()

    def _refresh(self) -> bool:
        return self._refresh_from_file()

    def _refresh_from_file(self) -> bool:
        # check file exists, if not create one:
        if not os.path.exists(self.data_file_path):
            self._save_to_file()
        # load the data from file:
        with open(self.data_file_path, "rb") as handle:
            fetched_data = pickle.load(handle)
        self.data = fetched_data
        return True

    def _save(self) -> bool:
        return self._save_to_file()

    def _save_to_file(self) -> bool:
        with open(self.data_file_path, "wb") as handle:
            pickle.dump(self.data, handle, protocol=pickle.HIGHEST_PROTOCOL)
        self.inner_counter += 1
        return True

    # public methods:

    def save_value(self, key, value):
        self.data[key] = value
        self._save()

    def get_value(self, key: str) -> str:
        if key in self.data:
            return self.data[key]
        else:
            return None

    def save_global_weight(self, value: list[list[int]]) -> str:
        link = f"https://example.com/link-gw-{self.inner_counter}"
        self.save_value(key=link, value=value)
        return link

    def get_global_weight(self, link: str) -> list[list[int]]:
        return self.get_value(key=link)

    def save_global_bias(self, value: list[int]) -> str:
        link = f"https://example.com/link-gb-{self.inner_counter}"
        self.save_value(key=link, value=value)
        return link

    def get_global_bias(self, link: str) -> list[int]:
        return self.get_value(key=link)
