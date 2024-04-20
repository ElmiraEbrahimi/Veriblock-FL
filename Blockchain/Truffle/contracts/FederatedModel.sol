// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./verifier.sol";
import "./verifier_aggregator.sol";

pragma experimental ABIEncoderV2;

contract FederatedModel {
    address public administrator;

    //  int256[] private global_weights;
    //  int256 private global_bias;
    //    int256 private precision=10000;
    //   int256 learning_rate;
    //  uint256 private dimension;
    //    bool public isTraining=true;
    //   address[] private participating_devices;
    //  mapping(address => int256[]) private localWeightsMappings;
    //    mapping(address => int256) private localBiasMappings;

    int256 private precision;
    uint256 private round_Number;
    int256 private learning_rate;
    uint256 private outputDimension;
    uint256 private inputDimension;
    bool private isTraining = true;
    address[] private participating_devices;
    uint256 private intervalEnd;
    uint256 private updateInterval;
    uint256 private batchSize;
    Verifier private verifier;
    VerifierAggregator private verifier_aggregator;
    bool private initialized = false;
    string public global_weights_ipfs_link = "";
    string public global_bias_ipfs_link = "";
    string public weight_bias_hash = "";
    bool is_no_proof;
    uint256 public constant numberOfBlocksAgg = 2; // Number of blocks each aggregator handles
    uint256 public constant totalAgg = 2; // Total number of aggregators

    constructor(
        uint256 id,
        uint256 od,
        int256 learning_rate_,
        int256 precision_,
        uint256 batchSize_,
        uint256 updateInterval_
    ) public {
        learning_rate = learning_rate_;
        administrator = tx.origin;
        outputDimension = od;
        inputDimension = id;
        batchSize = batchSize_;
        precision = precision_;
        intervalEnd = block.timestamp + updateInterval_;
        updateInterval = updateInterval_;
        round_Number = 1;
    }

    function updateVerifier(
        address verifier_address,
        address verifier_aggregator_address
    ) external {
        verifier = Verifier(verifier_address);
        verifier_aggregator = VerifierAggregator(verifier_aggregator_address);
    }

    function initModel(
        int256[][] calldata local_weights,
        int256[] calldata local_bias,
        bool IsNoProof
    ) external {
        initialized = true;
        is_no_proof = IsNoProof;
    }

    function time_until_next_update_round() external returns (int256) {
        return int(intervalEnd) - int(block.timestamp);
    }

    //
    function end_update_round() external {
        if (block.timestamp >= intervalEnd) {
            // for (uint256 i = 0; i < temp_global_weights.length; i++) {
            //     int256[] memory temp = new int256[](
            //         temp_global_weights[i].length
            //     );
            //     temp = temp_global_weights[i];
            //     global_weights[i] = temp;
            // }
            // for (uint256 i = 0; i < temp_global_bias.length; i++) {
            //     int256 temp = temp_global_bias[i];
            //     global_bias[i] = temp;
            // }
            intervalEnd = block.timestamp + updateInterval;
            delete participating_devices;
            round_Number = round_Number + 1;

            // delete all the hashes:
            deleteAllHashValues();
        }
    }

    function is_Training() external returns (bool) {
        return isTraining;
    }

    function roundUpdateOutstanding() external returns (bool) {
        if (initialized) {
            address user = tx.origin;
            bool new_user = true;
            for (uint256 i = 0; i < this.participantsCount(); i++) {
                if (user == participating_devices[i]) {
                    new_user = false;
                }
            }
            return new_user;
        } else {
            return false;
        }
    }

    //
    //
    //
    //
    //
    //
    //
    //
    //
    //
    //
    //

    // region hash mapping
    mapping(address => string) public hashDynamicMapping;
    address[] public hashKeys;

    function setHashValue(address sender, string memory _value) internal {
        // if the hash value is already set, ignore it:
        if (bytes(hashDynamicMapping[sender]).length != 0) {
            return;
        }
        hashDynamicMapping[sender] = _value;
        hashKeys.push(sender);
    }

    function getHashValue(address sender) public view returns (string memory) {
        return hashDynamicMapping[sender];
    }

    function getAllHashKeys() public view returns (address[] memory) {
        return hashKeys;
    }

    function getAllHashValues() public view returns (string[] memory) {
        uint size = hashKeys.length;
        string[] memory ret = new string[](size);
        for (uint i = 0; i < size; i++) {
            address sender_hash = hashKeys[i];
            ret[i] = getHashValue(sender_hash);
        }
        return ret;
    }

    function deleteAllHashValues() internal {
        for (uint i = 0; i < hashKeys.length; i++) {
            address key = hashKeys[i];
            hashDynamicMapping[key] = "";
        }
        delete hashKeys;
    }
    // endregion

    function send_wb_hash(
        string memory wb_hash,
        uint[2] calldata a,
        uint[2][2] calldata b,
        uint[2] calldata c,
        uint[5] calldata input
    ) external TrainingMode {
        require(this.checkWBHashZKP(a, b, c, input), "check wb hash failed");
        bool newUser = true;
        //bool firstUser = true;
        address user = tx.origin;
        if (this.participantsCount() == 0) {
            participating_devices.push(user);
            setHashValue(user, wb_hash);
        } else {
            for (uint256 i = 0; i < this.participantsCount(); i++) {
                if (user == participating_devices[i]) {
                    newUser = false;
                }
            }
            if (newUser) {
                participating_devices.push(user);
                setHashValue(user, wb_hash);
            }
        }
    }

    function send_aggregator_wb(
        string memory wb_hash,
        string memory gw_ipfs_link,
        string memory gb_ipfs_link,
        uint[2] calldata a,
        uint[2][2] calldata b,
        uint[2] calldata c,
        uint[10] calldata input
    ) external TrainingMode {
        require(
            this.checkAggregatorZKP(a, b, c, input),
            "check aggregator zkp failed"
        );
        weight_bias_hash = wb_hash;
        global_weights_ipfs_link = gw_ipfs_link;
        global_bias_ipfs_link = gb_ipfs_link;
    }

    function get_global_weights_ipfs_link()
        external
        view
        returns (string memory)
    {
        return global_weights_ipfs_link;
    }

    function get_weight_bias_hash() external view returns (string memory) {
        return weight_bias_hash;
    }

    function participantsCount() external view returns (uint) {
        uint x = participating_devices.length;
        return x;
    }

    //
    //
    function changeLearningRate(int256 newLearnignRate) external onlyAdmin {
        learning_rate = newLearnignRate;
    }

    function getLearningRate() external returns (int256) {
        return learning_rate;
    }

    function getBatchSize() external returns (uint256) {
        return batchSize;
    }

    function getRoundNumber() external view returns (uint256) {
        return round_Number;
    }

    function getInputDimension() external returns (uint256) {
        return inputDimension;
    }

    function getOutputDimension() external returns (uint256) {
        return outputDimension;
    }

    function getPrecision() external returns (int256) {
        return precision;
    }

    function changePrecision(int256 newPrecision) external onlyAdmin {
        precision = newPrecision;
    }

    function checkWBHashZKP(
        uint[2] memory a,
        uint[2][2] memory b,
        uint[2] memory c,
        uint[5] memory input
    ) public returns (bool) {
        if (is_no_proof == true) {
            return true;
        }
        Verifier.Proof memory proof = Verifier.Proof(
            Pairing.G1Point(a[0], a[1]),
            Pairing.G2Point(b[0], b[1]),
            Pairing.G1Point(c[0], c[1])
        );
        return verifier.verifyTx(proof, input);
    }

    function checkAggregatorZKP(
        uint[2] memory a,
        uint[2][2] memory b,
        uint[2] memory c,
        uint[10] memory input
    ) public returns (bool) {
        if (is_no_proof == true) {
            return true;
        }
        VerifierAggregator.ProofAggregator memory proof = VerifierAggregator
            .ProofAggregator(
                PairingAggregator.G1PointAggregator(a[0], a[1]),
                PairingAggregator.G2PointAggregator(b[0], b[1]),
                PairingAggregator.G1PointAggregator(c[0], c[1])
            );
        return verifier_aggregator.verifyTx(proof, input);
    }

    function stopTraining() external onlyAdmin {
        isTraining = false;
    }

    function startTraining() external onlyAdmin {
        isTraining = true;
    }

    //
    function random(uint256 seed) private view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(block.difficulty, block.timestamp, seed)
                )
            );
    }

    //
    modifier onlyAdmin() {
        require(tx.origin == administrator);
        _;
    }

    modifier TrainingMode() {
        require(isTraining);
        _;
    }
    modifier RoundFinished() {
        require(int(intervalEnd) - int(block.timestamp) <= 0);
        _;
    }

    // Returns the index of the current aggregator based on the current block number
    function getSelectedAggregatorIndex() public view returns (uint256) {
        uint256 currentBlock = block.number;
        uint256 cycleLength = numberOfBlocksAgg * totalAgg; // Total number of blocks in a full cycle
        uint256 cyclePosition = currentBlock % cycleLength; // Position in the current cycle
        return (cyclePosition / numberOfBlocksAgg) % totalAgg; // The index of the current aggregator
    }
}