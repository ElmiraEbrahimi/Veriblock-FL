def moving_average_weights(new_weights: dict, participant_count: int, temp_global_weights: dict) -> dict:
    k = participant_count
    if k > 0:
        if k == 1:
            for i in range(len(new_weights)):
                temp_global_weights[i] = new_weights[i]
        else:
            for i in range(len(new_weights)):
                res = [0] * len(new_weights[i])
                row_new = new_weights[i]
                row_old = temp_global_weights[i]

                for j in range(len(row_old)):
                    res[j] = row_old[j] + (row_new[j] - row_old[j]) / k

                temp_global_weights[i] = res

    return temp_global_weights


def moving_average_bias(new_bias: dict, participant_count: int, temp_global_bias: dict) -> dict:
    k = participant_count
    if k > 0:
        if k == 1:
            for i in range(len(new_bias)):
                temp_global_bias[i] = new_bias[i]
        else:
            for i in range(len(new_bias)):
                old_bias_i = temp_global_bias[i]
                new_bias_i = new_bias[i]
                res = old_bias_i + (new_bias_i - old_bias_i) / k
                temp_global_bias[i] = res

    return temp_global_bias


def moving_average_all(new_weights: dict, new_bias: dict, participant_count: int, temp_global_weights: dict, temp_global_bias: dict) -> dict:
    # weights:
    temp_global_weights = moving_average_weights(new_weights, participant_count, temp_global_weights)
    # bias:
    temp_global_bias = moving_average_bias(new_bias, participant_count, temp_global_bias)
    # return new temp_global_weights and temp_global_bias
    return temp_global_weights, temp_global_bias
