import numpy as np

ROUND_CONSTANTS = [
    42,
    43,
    170,
    2209,
    16426,
    78087,
    279978,
    823517,
    2097194,
    4782931,
    10000042,
    19487209,
    35831850,
    62748495,
    105413546,
    170859333,
    268435498,
    410338651,
    612220074,
    893871697,
    1280000042,
    1801088567,
    2494357930,
    3404825421,
    4586471466,
    6103515587,
    8031810218,
    10460353177,
    13492928554,
    17249876351,
    21870000042,
    27512614133,
    34359738410,
    42618442955,
    52523350186,
    64339296833,
    78364164138,
    94931877159,
    114415582634,
    137231006717,
    163840000042,
    194754273907,
    230539333290,
    271818611081,
    319277809706,
    373669453167,
    435817657258,
    506623120485,
    587068342314,
    678223072891,
    781250000042,
    897410677873,
    1028071702570,
    1174711139799,
    1338925210026,
    1522435234413,
    1727094849578,
    1954897493219,
    2207984167594,
    2488651484857,
    2799360000042,
    3142742835999,
    3521614606250,
    3938980639125,
]

SNARK_SCALAR_FIELD = (
    21888242871839275222246405745257275088548364400416034343698204186575808495617
)


def convert_matrix(m):
    m = np.array(m)  # suitable data type for large numbers
    # ensure values are within the field range
    # adjusted_values = np.mod(m, SNARK_SCALAR_FIELD)
    adjusted_values = np.where(m < 0, SNARK_SCALAR_FIELD + m, m)
    sign_mask = np.where(m > 0, 0, 1)  # This remains unchanged
    return adjusted_values, sign_mask


#     # adjusted_values = []
#     # sign_mask = []
#     # for row in m:
#     #     # Ensure row is iterable
#     #     if isinstance(row, int):
#     #         row = row % SNARK_SCALAR_FIELD
#     #         if row < 0:
#     #             row += SNARK_SCALAR_FIELD
#     #         adjusted_values.append(row)
#     #         sign_mask.append(0 if row > 0 else 1)
#     #     else:
#     #         adjusted_row = []
#     #         sign_row = []
#     #         for value in row:
#     #             adjusted_value = value % SNARK_SCALAR_FIELD
#     #             if value < 0:
#     #                 adjusted_value += SNARK_SCALAR_FIELD
#     #             adjusted_row.append(adjusted_value)
#     #             sign_row.append(0 if value > 0 else 1)
#     #         adjusted_values.append(adjusted_row)
#     #         sign_mask.append(sign_row)
#     # return adjusted_values, sign_mask


def mimc(x, k, e=7, R=64):
    for i in range(R):
        c_i = ROUND_CONSTANTS[i]
        a = (
            x + k + c_i
        ) % SNARK_SCALAR_FIELD  # Ensure intermediate result is within the field
        x = pow(int(a), e, SNARK_SCALAR_FIELD)
    return (x + k) % SNARK_SCALAR_FIELD


# def modular_pow(base, exponent, modulus):
#     result = 1
#     base = base % modulus
#     while exponent > 0:
#         if exponent % 2 == 1:
#             result = (result * base) % modulus
#         exponent = exponent // 2
#         base = (base * base) % modulus
#     return result


def mimc_hash(w: np.ndarray, b: np.ndarray, k=0, e=7, R=64):
    for i in range(len(w)):
        for j in range(len(w[i])):
            k = mimc(w[i][j], k, e, R)
        k = mimc(b[i], k, e, R)

    return k


if __name__ == "__main__":
    w = [[1, -2], [3, -4]]
    b = [1, 2]

    # Adjust inputs to numpy arrays for processing
    w_np = np.array(w)
    b_np = np.array(b)

    # Compute the hash considering the adjusted values
    hash_result = mimc_hash(w_np, b_np)
    print(f"MiMC hash result: {hash_result}")
