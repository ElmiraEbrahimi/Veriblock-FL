# Adjusted MiMC implementation to match the ZoKrates example

# Define the round constants as per the ZoKrates code
ROUND_CONSTANTS = [
    42, 43, 170, 2209, 16426, 78087, 279978, 823517, 2097194, 4782931,
    10000042, 19487209, 35831850, 62748495, 105413546, 170859333,
    268435498, 410338651, 612220074, 893871697, 1280000042, 1801088567,
    2494357930, 3404825421, 4586471466, 6103515587, 8031810218, 10460353177,
    13492928554, 17249876351, 21870000042, 27512614133, 34359738410,
    42618442955, 52523350186, 64339296833, 78364164138, 94931877159,
    114415582634, 137231006717, 163840000042, 194754273907, 230539333290,
    271818611081, 319277809706, 373669453167, 435817657258, 506623120485,
    587068342314, 678223072891, 781250000042, 897410677873, 1028071702570,
    1174711139799, 1338925210026, 1522435234413, 1727094849578,
    1954897493219, 2207984167594, 2488651484857, 2799360000042,
    3142742835999, 3521614606250, 3938980639125
]

# SNARK_SCALAR_FIELD is not explicitly defined in your code snippet,
# assuming it's a placeholder for a prime field order used in SNARKs
SNARK_SCALAR_FIELD = 21888242871839275222246405745257275088548364400416034343698204186575808495617

def mimc(x, k, e=7, R=64):
    """
    Adjusted MiMC encryption function to match the ZoKrates implementation.
    """
    for i in range(R):
        c_i = ROUND_CONSTANTS[i]
        a = (x + k + c_i) % SNARK_SCALAR_FIELD
        x = pow(a, e, SNARK_SCALAR_FIELD)
    return (x + k) % SNARK_SCALAR_FIELD

def mimc_hash(inputs, k=0, e=7, R=64):
    """
    Hash function using the adjusted MiMC encryption to process inputs.
    """
    for input in inputs:
        k = mimc(input, k, e, R)
    return k

# Example usage:
if __name__ == "__main__":
    # Input similar to ZoKrates preimage
    inputs = [1, 2]  # Example input

    # Compute the hash
    hash_result = mimc_hash(inputs)
    print(f"MiMC hash result: {hash_result}")
