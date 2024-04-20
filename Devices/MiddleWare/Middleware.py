import functools
import io
import json
import subprocess
import threading
import time

import numpy as np
import pandas as pd
from analytics.analytics import Analytics
from message_broker.consumer import Consumer
from middleware.hash import mimc_hash
from middleware.neuralnet import FCLayer, Network, mse, mse_prime
from sklearn.metrics import accuracy_score, classification_report
from sklearn.preprocessing import StandardScaler
from utils.gas import get_current_balance
from utils.utils import wait_for_file_creation


def print_report(device, model, X_test, y_test):
    print(
        f"{device}",
        classification_report(y_test, model.predict(X_test), zero_division=0),
    )


class FederatedLearningModel:
    def __init__(self, config_file, deviceName):
        self.deviceName = deviceName
        self.config = config_file
        self.consumer = Consumer()
        self.scaler = StandardScaler()
        self.net = Network(
            self.config["DEFAULT"]["OutputDimension"],
            self.config["DEFAULT"]["InputDimension"],
            self.config["DEFAULT"]["Precision"],
        )
        self.net.add(
            FCLayer(
                self.config["DEFAULT"]["InputDimension"],
                self.config["DEFAULT"]["OutputDimension"],
            )
        )
        self.epochs = self.config["DEFAULT"]["Epochs"]
        self.net.use(mse, mse_prime)
        self.learning_rate = None
        self.curr_batch = None
        self.batchSize = None
        self.x_train = None
        self.y_train = None
        datasource = self.config["DEFAULT"]["TestFilePath"]
        testdata = pd.read_csv(
            datasource,
            names=[
                "T_xacc",
                "T_yacc",
                "T_zacc",
                "T_xgyro",
                "T_ygyro",
                "T_zgyro",
                "T_xmag",
                "T_ymag",
                "T_zmag",
                "RA_xacc",
                "RA_yacc",
                "RA_zacc",
                "RA_xgyro",
                "RA_ygyro",
                "RA_zgyro",
                "RA_xmag",
                "RA_ymag",
                "RA_zmag",
                "LA_xacc",
                "LA_yacc",
                "LA_zacc",
                "LA_xgyro",
                "LA_ygyro",
                "LA_zgyro",
                "LA_xmag",
                "LA_ymag",
                "LA_zmag",
                "RL_xacc",
                "RL_yacc",
                "RL_zacc",
                "RL_xgyro",
                "RL_ygyro",
                "RL_zgyro",
                "RL_xmag",
                "RL_ymag",
                "RL_zmag",
                "LL_xacc",
                "LL_yacc",
                "LL_zacc",
                "LL_xgyro",
                "LL_ygyro",
                "LL_zgyro",
                "LL_xmag",
                "LL_ymag",
                "LL_zmag",
                "Activity",
            ],
        )
        testdata.fillna(inplace=True, method="backfill")
        testdata.dropna(inplace=True)
        testdata.drop(
            columns=[
                "T_xacc",
                "T_yacc",
                "T_zacc",
                "T_xgyro",
                "T_ygyro",
                "T_zgyro",
                "T_xmag",
                "T_ymag",
                "T_zmag",
                "RA_xacc",
                "RA_yacc",
                "RA_zacc",
                "RA_xgyro",
                "RA_ygyro",
                "RA_zgyro",
                "RA_xmag",
                "RA_ymag",
                "RA_zmag",
                "RL_xacc",
                "RL_yacc",
                "RL_zacc",
                "RL_xgyro",
                "RL_ygyro",
                "RL_zgyro",
                "RL_xmag",
                "RL_ymag",
                "RL_zmag",
                "LL_xacc",
                "LL_yacc",
                "LL_zacc",
                "LL_xgyro",
                "LL_ygyro",
                "LL_zgyro",
                "LL_xmag",
                "LL_ymag",
                "LL_zmag",
            ],
            inplace=True,
        )
        activity_mapping = self.config["DEFAULT"]["ActivityMappings"]
        filtered_activities = self.config["DEFAULT"]["Activities"]
        activity_encoding = self.config["DEFAULT"]["ActivityEncoding"]
        for key in activity_mapping.keys():
            testdata.loc[testdata["Activity"] == key, "Activity"] = activity_mapping[
                key
            ]
        testdata = testdata[testdata["Activity"].isin(filtered_activities)]
        for key in activity_encoding.keys():
            testdata.loc[testdata["Activity"] == key, "Activity"] = activity_encoding[
                key
            ]
        self.x_test = testdata.drop(columns="Activity")
        self.y_test = testdata["Activity"]

    def test_model(self):
        x_test = self.scaler.transform(self.x_test.to_numpy())
        pred = self.net.predict(x_test)
        return accuracy_score(self.y_test, self.net.predict(x_test))

    def get_classification_report(self):
        x_test = self.scaler.transform(self.x_test.to_numpy())
        return classification_report(
            self.y_test, self.net.predict(x_test), zero_division=0, output_dict=True
        )

    def process_Batch(self):
        self.curr_batch.dropna(inplace=True)
        batch = self.curr_batch.sample(self.batchSize)
        self.x_train = batch.drop(columns=self.config["DEFAULT"]["ResponseVariable"])
        self.y_train = batch[self.config["DEFAULT"]["ResponseVariable"]]
        self.x_train = self.x_train.to_numpy()
        self.y_train = self.y_train.to_numpy()
        self.scaler.fit(self.x_test.to_numpy())
        self.x_train = self.scaler.transform(self.x_train)
        self.net.fit(
            self.x_train,
            self.y_train,
            epochs=self.epochs,
            learning_rate=self.learning_rate,
        )
        score = self.test_model()
        print(f"{self.deviceName}: Score:", score)

    def reset_batch(self):
        self.curr_batch = None
        self.x_train = None
        self.y_train = None

    def get_weights(self):
        return self.net.get_weights()

    def get_bias(self):
        return self.net.get_bias()

    def set_learning_rate(self, rate):
        self.learning_rate = rate

    def set_weights(self, weights):
        self.net.set_weights(weights)

    def set_bias(self, bias):
        self.net.set_bias(bias)

    def set_batchSize(self, batchSize):
        self.batchSize = batchSize

    def set_precision(self, precision):
        self.net.set_precision(precision)

    def add_data_to_current_batch(self, data):
        if self.curr_batch is None:
            self.curr_batch = data
        else:
            self.curr_batch = pd.concat([self.curr_batch, data])


class MiddleWare:
    def __init__(self, connection_manager, deviceName, accountNR, configFile):
        self.accountNR = accountNR
        self.consumer_thread = None
        self.analytics = Analytics(deviceName=deviceName, config_file=configFile)
        self.connection_manager = connection_manager
        self.deviceName = deviceName
        self.model = FederatedLearningModel(
            config_file=configFile, deviceName=self.deviceName
        )
        self.config = configFile
        self.consumer = Consumer()
        self.__init_Consumer(deviceName, callback)
        self.proof = None
        self.precision = None
        self.batchSize = None
        self.round = 0

    def __generate_Proof(self, w, b, w_new, b_new, x_train, y_train, learning_rate):
        x_train = x_train * self.precision
        b_new = b_new.reshape(
            self.config["DEFAULT"]["OutputDimension"],
        )
        x_train = x_train.astype(int)

        def args_parser(args):
            res = ""
            for arg in range(len(args)):
                entry = args[arg]
                if isinstance(entry, (list, np.ndarray)):
                    for i in range(len(entry)):
                        row_i = entry[i]
                        if isinstance(row_i, (list, np.ndarray)):
                            for j in range(len(row_i)):
                                val = row_i[j]
                                res += str(val) + " "
                        else:
                            res += str(row_i) + " "
                else:
                    res += str(args[arg]) + " "
            res = res[:-1]
            return res

        def convert_matrix(m):
            max_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617
            m = np.array(m)
            return np.where(m < 0, max_field + m, m), np.where(m > 0, 0, 1)

        zokrates = "zokrates"
        verification_base = self.config["DEFAULT"]["VerificationBase"]
        global_weights, global_weights_sign = convert_matrix(w)
        global_bias, global_bias_sign = convert_matrix(b)
        weights_new, _ = convert_matrix(w_new)
        bias_new, _ = convert_matrix(b_new)
        x, x_sign = convert_matrix(x_train)
        ldigest = mimc_hash(weights_new, bias_new)
        sc_global_model_hash = mimc_hash(global_weights, global_bias)
        args = [
            global_weights,
            global_weights_sign,
            global_bias,
            global_bias_sign,
            x,
            x_sign,
            y_train,
            learning_rate,
            self.precision,
            weights_new,
            bias_new,
            ldigest,
            sc_global_model_hash,
        ]
        out_path = verification_base + "out"
        abi_path = verification_base + "abi.json"
        witness_path = verification_base + "witness_" + self.deviceName
        zokrates_compute_witness = [
            zokrates,
            "compute-witness",
            "-o",
            witness_path,
            "-i",
            out_path,
            "-s",
            abi_path,
            "-a",
        ]
        zokrates_compute_witness.extend(args_parser(args).split(" "))
        g = subprocess.run(zokrates_compute_witness, capture_output=True)
        # wait_for_process(g)

        if g.returncode != 0:
            print("Error: {self.deviceName} returned non-zero:")
            print(f"{g.stderr.decode()=}")
            print(f"{g.stdout.decode()=}")
            print(f"{g.returncode=}")

        # check file is created:
        wait_for_file_creation(file_path=witness_path)

        print(f"{self.deviceName} output:", g.stdout.decode())

        # print(f"{self.deviceName} output:", g.stdout.decode())
        # errors = g.stderr.decode()
        # if errors:
        #     print(f"{self.deviceName} error:", errors)

        # raise Exception(f'{ g.stderr.decode()} {g.stdout.decode()}')

        proof_path = verification_base + "proof_" + self.deviceName
        proving_key_path = verification_base + "proving.key"
        zokrates_generate_proof = [
            zokrates,
            "generate-proof",
            "-w",
            witness_path,
            "-p",
            proving_key_path,
            "-i",
            out_path,
            "-j",
            proof_path,
        ]
        g = subprocess.run(zokrates_generate_proof, capture_output=True)
        # wait_for_process(g)

        if g.returncode != 0:
            print(
                f"Error: {self.deviceName} returned non-zero. {g.stderr.decode()=}, {g.stdout.decode()=}",
            )

        # check file is created:
        wait_for_file_creation(file_path=proof_path)

        print(f"{self.deviceName} output:", g.stdout.decode())
        # errors = g.stderr.decode()
        # if errors:
        #     print(f"{self.deviceName} error:", errors)
        # print(f"{self.deviceName} output:", g.stdout.decode())

        with open(proof_path, "r") as f:
            self.proof = json.load(f)

    def __init_Consumer(self, DeviceName, callBackFunction):
        queueName = self.config["DEFAULT"]["QueueBase"] + DeviceName
        on_message_callback = functools.partial(callBackFunction, args=(self.model))
        self.consumer.declare_queue(queueName)
        self.consumer.consume_data(queueName, on_message_callback)

    def __start_Consuming(self):
        self.consumer_thread = threading.Thread(target=self.consumer.start_consuming)
        self.consumer_thread.start()

    def update(self, w, b, mse_score, p, r, balance):
        # barrier:
        print(f"Barrier waiting before aggregator start... ({self.accountNR=})")
        start_thread_num = self.connection_manager.barrier.wait()

        ##### aggregator:
        if start_thread_num == 0:
            self.connection_manager.aggregator_selector.start_round()
        #####
        tu = time.time()
        self.connection_manager.update(w, b, mse_score, self.accountNR, p)
        self.analytics.add_round_update_blockchain_time(r, time.time() - tu)
        self.analytics.add_round_gas(
            self.round,
            balance - self.connection_manager.get_account_balance(self.accountNR),
        )

        # gas usage:
        get_current_balance(
            web3=self.connection_manager.web3Connection,
            account_address=self.connection_manager.web3Connection.eth.accounts[
                self.accountNR
            ],
            round=self.round,
            source=f"Account-{self.accountNR}",
        )

        # barrier:
        print(f"Barrier waiting to finish aggregator... ({self.accountNR=})")
        end_thread_num = self.connection_manager.barrier.wait()

        ###### aggregator:
        if end_thread_num == self.connection_manager.participant_count - 1:
            self.connection_manager.aggregator_selector.finish_round()
        ######

    def start_Middleware(self):
        self.__start_Consuming()
        self.connection_manager.init_contract(self.accountNR)
        self.round = self.connection_manager.get_RoundNumber(self.accountNR)
        while self.config["DEFAULT"]["Rounds"] > self.round:
            outstanding_update = self.connection_manager.roundUpdateOutstanding(
                self.accountNR
            )
            self.round = self.connection_manager.get_RoundNumber(self.accountNR)
            print(
                f"{self.deviceName}: Round {self.round} Has update outstanding: ",
                outstanding_update,
            )
            if outstanding_update:
                t = time.time()
                # get from blockchain:
                balance = self.connection_manager.get_account_balance(self.accountNR)
                retrieved_weights = self.connection_manager.get_globalWeights(
                    self.accountNR
                )
                if retrieved_weights:
                    global_weights = retrieved_weights
                retrieved_bias = self.connection_manager.get_globalBias(self.accountNR)
                if retrieved_bias:
                    global_bias = retrieved_bias
                lr = self.connection_manager.get_LearningRate(self.accountNR)
                self.precision = self.connection_manager.get_Precision(self.accountNR)
                # init blockchain vars to model:
                self.model.set_precision(precision=self.precision)
                self.model.set_learning_rate(lr)
                self.model.set_weights(global_weights)
                self.model.set_bias(global_bias)
                self.batchSize = self.connection_manager.get_BatchSize(self.accountNR)
                while self.model.curr_batch is None:
                    pass
                while self.model.curr_batch.size < self.batchSize:
                    pass
                self.model.set_batchSize(self.batchSize)
                tt = time.time()
                self.model.process_Batch()
                self.analytics.add_round_training_local_time(
                    self.round, time.time() - tt
                )
                self.analytics.add_round_score(self.round, self.model.test_model())
                self.analytics.add_round_classification_report(
                    self.round, self.model.get_classification_report()
                )
                w = self.model.get_weights()
                b = self.model.get_bias()
                mse_score = self.model.net.mse_average
                if self.config["DEFAULT"]["PerformProof"]:
                    tp = time.time()
                    self.__generate_Proof(
                        global_weights,
                        global_bias,
                        w,
                        b,
                        self.model.x_train,
                        self.model.y_train,
                        lr,
                    )
                    self.analytics.add_round_proof_times(self.round, time.time() - tp)
                self.model.reset_batch()
                thread = threading.Thread(
                    target=self.update,
                    args=[w, b, mse_score, self.proof, self.round, balance],
                )
                thread.start()
                # TODO: will fix?
                thread.join()

                print(
                    f"{self.deviceName}: Round {self.round} update took {time.time()-t} seconds"
                )
                self.round += 1
                self.analytics.add_round_time(self.round, time.time() - t)
            time.sleep(self.config["DEFAULT"]["WaitingTime"])
            # self.__sleep_call(10)
        self.analytics.write_data()
        print("Done.")


def callback(ch, method, properties, body, args):
    model = args
    if isinstance(model, FederatedLearningModel):
        batch = pd.read_csv(io.BytesIO(body), header=0, index_col=0)
        model.add_data_to_current_batch(batch)
