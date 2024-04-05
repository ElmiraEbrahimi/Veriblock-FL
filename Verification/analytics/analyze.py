import datetime
import os
import subprocess
import time

import numpy as np
import pandas as pd
import psutil
from hash import mimc_hash


def mse_prime(y_true, y_pred):
    return 2 * (y_pred - y_true) / y_true.size


def convert_matrix(m):
    max_field = (
        21888242871839275222246405745257275088548364400416034343698204186575808495617
    )
    return np.where(m < 0, max_field + m, m), np.where(m > 0, 0, 1)


def process_memory_usage(process) -> list:
    p = psutil.Process(process.pid)
    SLICE_IN_SECONDS = 0.05
    res = []
    while process.poll() is None:
        try:
            res.append(p.memory_info().rss / (1024 * 1024))
        except psutil.NoSuchProcess:
            pass
        time.sleep(SLICE_IN_SECONDS)
    return res, max(res)


def run_process(args: list, mem_profile=True):
    if mem_profile:
        p = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        all_mem, max_mem = process_memory_usage(p)
        return p, all_mem, max_mem
    else:
        p = subprocess.run(args, capture_output=True)
        return p, None, None


def args_parser(args):
    res = ""
    for arg in args:
        if isinstance(arg, (list, np.ndarray)):
            flattened_arg = np.ravel(arg)
            for sub_arg in flattened_arg:
                clean_sub_arg = str(sub_arg).strip().replace("\n", "").replace("\r", "")
                res += clean_sub_arg + " "
        else:
            clean_arg = str(arg).strip().replace("\n", "").replace("\r", "")
            res += clean_arg + " "
    res = res.strip()
    return res


def compile():
    t1 = time.time()
    zokrates_compile = [
        zokrates,
        "compile",
        "-i",
        "./../zokrates/root.zok",
    ]
    p, all_mem, max_mem = run_process(zokrates_compile)
    if p.returncode != 0:
        raise Exception(f"{p.stderr.decode()=}\n{p.stdout.decode()=}")
    t2 = time.time()
    diff = t2 - t1
    print(f"Compilation for {batchsize} samples took {diff} seconds")
    return diff, all_mem, max_mem


def setup():
    zokrates_setup = [
        zokrates,
        "setup",
    ]

    t1 = time.time()
    p, all_mem, max_mem = run_process(zokrates_setup)
    if p.returncode != 0:
        raise Exception(f"{p.stderr.decode()=}\n{p.stdout.decode()=}")
    t2 = time.time()
    diff = t2 - t1
    print(f"Setup for {batchsize} samples took {diff} seconds")
    return diff, all_mem, max_mem


def compute_witness():
    np.random.seed(0)
    precision = 1000
    ac = 6
    fe = 9
    bias = (
        np.random.randn(
            ac,
        )
        * precision
    )
    weights = np.random.randn(ac, fe) * precision
    weights = np.array([[int(x) for x in y] for y in weights])
    bias = np.array([int(x) for x in bias])
    w = weights
    weights, weights_sign = convert_matrix(weights)
    b = bias
    bias, bias_sign = convert_matrix(bias)
    x_train = np.random.randn(batchsize, fe) * precision
    x_train = np.array([[int(x) for x in y] for y in x_train])
    x = x_train
    x_train, x_train_sign = convert_matrix(x_train)
    learning_rate = 10
    Y = []
    out = None
    for X in x:
        rand_int = np.random.randint(1, ac)
        y_true = np.zeros(shape=(ac,))
        y_true[rand_int - 1] = precision
        Y.append(rand_int)
        out_layer = (np.dot(w, X) / precision).astype(int)
        out_layer = np.add(out_layer, b)
        error = mse_prime(y_true, out_layer).astype(int)
        w = w - (np.outer(error, X) / precision / learning_rate).astype(int)
        b = b - (error / learning_rate).astype(int)
    # ,bias,bias_sign,x,x_sign,1,learning_rate,precision

    new_bias = (
        np.random.randn(
            ac,
        )
        * precision
    )
    new_weights = np.random.randn(ac, fe) * precision
    new_weights = np.array([[int(x) for x in y] for y in new_weights])
    new_bias = np.array([int(x) for x in new_bias])
    new_weights, _ = convert_matrix(new_weights)
    new_bias, _ = convert_matrix(new_bias)

    ldigest = mimc_hash(new_weights, new_bias)
    sc_global_model_hash = mimc_hash(weights, bias)

    out = out_layer
    args = [
        weights,
        weights_sign,
        bias,
        bias_sign,
        x_train,
        x_train_sign,
        Y,
        learning_rate,
        precision,
        new_weights,
        new_bias,
        ldigest,
        sc_global_model_hash,
    ]
    zokrates_compute_witness = [
        zokrates,
        "compute-witness",
        "-a",
    ]
    zokrates_compute_witness.extend(args_parser(args).split(" "))

    t1 = time.time()
    p, all_mem, max_mem = run_process(zokrates_compute_witness)
    if p.returncode != 0:
        raise Exception(f"{p.stderr.decode()=}\n{p.stdout.decode()=}")
    t2 = time.time()
    diff = t2 - t1
    print(f"Computing witness for {batchsize} samples took {diff} seconds")
    return diff, all_mem, max_mem


def generate_proof():
    zokrates_generate_proof = [
        zokrates,
        "generate-proof",
    ]
    t1 = time.time()
    p, all_mem, max_mem = run_process(zokrates_generate_proof)
    if p.returncode != 0:
        raise Exception(f"{p.stderr.decode()=}\n{p.stdout.decode()=}")
    t2 = time.time()
    diff = t2 - t1
    print(f"Generating proof for {batchsize} samples took {diff} seconds")
    return diff, all_mem, max_mem


def export_verifier():
    zokrates_export_verifier = [
        zokrates,
        "export-verifier",
    ]
    t1 = time.time()
    p, all_mem, max_mem = run_process(zokrates_export_verifier)
    if p.returncode != 0:
        raise Exception(f"{p.stderr.decode()=}\n{p.stdout.decode()=}")
    t2 = time.time()
    diff = t2 - t1
    print(f"Exporting Verifier for {batchsize} samples took {diff} seconds")
    return diff, all_mem, max_mem


def get_batchsize(zok_filepath):
    with open(zok_filepath, "r") as f:
        for line in f.readlines():
            if "const u32  bs =" in line:
                return int(line.split("const u32  bs =")[1].strip().split(";")[0])


def calculate_average(analytics_filepath):
    analytics_df = pd.read_csv(analytics_filepath)
    grouped_df = analytics_df.groupby("batchsize")
    average_df = grouped_df.mean().round(2)
    average_df = average_df.rename(columns=lambda x: f"{x}_avg")
    average_df.reset_index(inplace=True)
    std_df = grouped_df.std().round(2)
    std_df = std_df.rename(columns=lambda x: f"{x}_std")
    std_df.reset_index(inplace=True)
    combined_df = pd.concat([average_df, std_df], axis=1)
    sorted_df = combined_df.sort_index(axis=1)
    final_filepath = "final_analytics.csv"
    sorted_df.to_csv(final_filepath, index=False)

    return average_df


zokrates = "zokrates"
result_df = pd.DataFrame(
    columns=[
        "datetime",
        "batchsize",
        "t_compile",
        "t_setup",
        "t_compute_witness",
        "t_generate_proof",
        "t_export_verifier",
        "max_mem_compile",
        "max_mem_setup",
        "max_mem_compute_witness",
        "max_mem_generate_proof",
        "max_mem_export_verifier",
    ]
)
memory_usage_df = pd.DataFrame(
    columns=[
        "datetime",
        "batchsize",
        "all_mem_compile",
        "all_mem_setup",
        "all_mem_compute_witness",
        "all_mem_generate_proof",
        "all_mem_export_verifier",
    ]
)

repeat = 3
for i in range(repeat):
    print(f"Analyzing zokrates files - Round {i+1}")
    dt = datetime.datetime.now()
    batchsize = get_batchsize(zok_filepath="./../zokrates/root.zok")
    print(f"Detected batchsize: {batchsize}")

    t_compile, all_mem_compile, max_mem_compile = compile()
    t_setup, all_mem_setup, max_mem_setup = setup()
    t_compute_witness, all_mem_compute_witness, max_mem_compute_witness = (
        compute_witness()
    )
    t_generate_proof, all_mem_generate_proof, max_mem_generate_proof = generate_proof()
    t_export_verifier, all_mem_export_verifier, max_mem_export_verifier = (
        export_verifier()
    )

    result_df = result_df.append(
        {
            "datetime": dt,
            "batchsize": batchsize,
            "t_compile": t_compile,
            "t_setup": t_setup,
            "t_compute_witness": t_compute_witness,
            "t_generate_proof": t_generate_proof,
            "t_export_verifier": t_export_verifier,
            "max_mem_compile": max_mem_compile,
            "max_mem_setup": max_mem_setup,
            "max_mem_compute_witness": max_mem_compute_witness,
            "max_mem_generate_proof": max_mem_generate_proof,
            "max_mem_export_verifier": max_mem_export_verifier,
        },
        ignore_index=True,
    )
    if i == 0:
        memory_usage_df = memory_usage_df.append(
            {
                "datetime": dt,
                "batchsize": batchsize,
                "all_mem_compile": all_mem_compile,
                "all_mem_setup": all_mem_setup,
                "all_mem_compute_witness": all_mem_compute_witness,
                "all_mem_generate_proof": all_mem_generate_proof,
                "all_mem_export_verifier": all_mem_export_verifier,
            },
            ignore_index=True,
        )

# analytics:
analytics_filepath = "analytics.csv"
if os.path.isfile(analytics_filepath):
    result_df.to_csv(analytics_filepath, mode="a", header=False, index=False)
else:
    result_df.to_csv(analytics_filepath, index=False)
# memory usage:
memory_usage_filepath = "analytics_memory.csv"
if os.path.isfile(memory_usage_filepath):
    memory_usage_df.to_csv(memory_usage_filepath, mode="a", header=False, index=False)
else:
    memory_usage_df.to_csv(memory_usage_filepath, index=False)
memory_usage_df.to_csv(memory_usage_filepath, index=False)

# calculate average:
average_df = calculate_average(analytics_filepath=analytics_filepath)
print(average_df)
