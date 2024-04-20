// SPDX-License-Identifier: MIT
// This file is MIT Licensed.
//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
pragma solidity ^0.8.0;
library PairingAggregator {
    struct G1PointAggregator {
        uint X;
        uint Y;
    }
    // Encoding of field elements is: X[0] * z + X[1]
    struct G2PointAggregator {
        uint[2] X;
        uint[2] Y;
    }
    /// @return the generator of G1
    function P1() pure internal returns (G1PointAggregator memory) {
        return G1PointAggregator(1, 2);
    }
    /// @return the generator of G2
    function P2() pure internal returns (G2PointAggregator memory) {
        return G2PointAggregator(
            [10857046999023057135944570762232829481370756359578518086990519993285655852781,
             11559732032986387107991004021392285783925812861821192530917403151452391805634],
            [8495653923123431417604973247489272438418190587263600148770280649306958101930,
             4082367875863433681332203403145435568316851327593401208105741076214120093531]
        );
    }
    /// @return the negation of p, i.e. p.addition(p.negate()) should be zero.
    function negate(G1PointAggregator memory p) pure internal returns (G1PointAggregator memory) {
        // The prime q in the base field F_q for G1
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p.X == 0 && p.Y == 0)
            return G1PointAggregator(0, 0);
        return G1PointAggregator(p.X, q - (p.Y % q));
    }
    /// @return r the sum of two points of G1
    function addition(G1PointAggregator memory p1, G1PointAggregator memory p2) internal view returns (G1PointAggregator memory r) {
        uint[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success);
    }


    /// @return r the product of a point on G1 and a scalar, i.e.
    /// p == p.scalar_mul(1) and p.addition(p) == p.scalar_mul(2) for all points p.
    function scalar_mul(G1PointAggregator memory p, uint s) internal view returns (G1PointAggregator memory r) {
        uint[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require (success);
    }
    /// @return the result of computing the pairing check
    /// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    /// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
    /// return true.
    function pairing(G1PointAggregator[] memory p1, G2PointAggregator[] memory p2) internal view returns (bool) {
        require(p1.length == p2.length);
        uint elements = p1.length;
        uint inputSize = elements * 6;
        uint[] memory input = new uint[](inputSize);
        for (uint i = 0; i < elements; i++)
        {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[1];
            input[i * 6 + 3] = p2[i].X[0];
            input[i * 6 + 4] = p2[i].Y[1];
            input[i * 6 + 5] = p2[i].Y[0];
        }
        uint[1] memory out;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success);
        return out[0] != 0;
    }
    /// Convenience method for a pairing check for two pairs.
    function pairingProd2(G1PointAggregator memory a1, G2PointAggregator memory a2, G1PointAggregator memory b1, G2PointAggregator memory b2) internal view returns (bool) {
        G1PointAggregator[] memory p1 = new G1PointAggregator[](2);
        G2PointAggregator[] memory p2 = new G2PointAggregator[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for three pairs.
    function pairingProd3(
            G1PointAggregator memory a1, G2PointAggregator memory a2,
            G1PointAggregator memory b1, G2PointAggregator memory b2,
            G1PointAggregator memory c1, G2PointAggregator memory c2
    ) internal view returns (bool) {
        G1PointAggregator[] memory p1 = new G1PointAggregator[](3);
        G2PointAggregator[] memory p2 = new G2PointAggregator[](3);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for four pairs.
    function pairingProd4(
            G1PointAggregator memory a1, G2PointAggregator memory a2,
            G1PointAggregator memory b1, G2PointAggregator memory b2,
            G1PointAggregator memory c1, G2PointAggregator memory c2,
            G1PointAggregator memory d1, G2PointAggregator memory d2
    ) internal view returns (bool) {
        G1PointAggregator[] memory p1 = new G1PointAggregator[](4);
        G2PointAggregator[] memory p2 = new G2PointAggregator[](4);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p1[3] = d1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        p2[3] = d2;
        return pairing(p1, p2);
    }
}

contract VerifierAggregator {
    using PairingAggregator for *;
    struct VerifyingKeyAggregator {
        PairingAggregator.G1PointAggregator alpha;
        PairingAggregator.G2PointAggregator beta;
        PairingAggregator.G2PointAggregator gamma;
        PairingAggregator.G2PointAggregator delta;
        PairingAggregator.G1PointAggregator[] gamma_abc;
    }
    struct ProofAggregator {
        PairingAggregator.G1PointAggregator a;
        PairingAggregator.G2PointAggregator b;
        PairingAggregator.G1PointAggregator c;
    }
    function verifyingKey() pure internal returns (VerifyingKeyAggregator memory vk) {
        vk.alpha = PairingAggregator.G1PointAggregator(uint256(0x14ba839015d0254779a17e4b31d43bec622bbf594d4cac14585715d55d6a4c8e), uint256(0x294b54e64debe1bca3b1a7a14881319cf0e319a92fef302ba7f4048246626a15));
        vk.beta = PairingAggregator.G2PointAggregator([uint256(0x1115149c587db435ccdd82c974a39cdb99f1b64dd83d62abb16c45992db43b0a), uint256(0x1b2571ca0c8b2f17fc4e6860def788b1bc8bbe12b52d9aba52275206802eff37)], [uint256(0x209f3eb0a8bf16b06a561fc7aa1c725edcb776627e3b982551b6200d26868742), uint256(0x2b31427dd19d87020886659f32503b727fcfec8690b6f930fcb28ebda36d75a7)]);
        vk.gamma = PairingAggregator.G2PointAggregator([uint256(0x04bdf789ae3e7d880d574254992256ce853937f12c5d988a2175c695df9f5f9a), uint256(0x11409280d46a357a33fdeb531a254093585e7b0167e7fb7a8f8d9605a36222c5)], [uint256(0x0f6f3d190e624a283213ac96920a4ec3c9516b28abe576ee7fca9ced41bb1f14), uint256(0x0f36063ef13c52475f64215dd264762396dc42ba91c12e7a3c0d18e3b8bc7367)]);
        vk.delta = PairingAggregator.G2PointAggregator([uint256(0x25e115b5c595197eadc77bca524c8fc04d9c3c30fba5892b29429ace78356078), uint256(0x2900965457bb4416f59a8894b0ee054290b956fd5f7f45a351cea3941c473ec2)], [uint256(0x0a956e8f045d4437aa4535c51ff37076f64edddab1615ce5f48b321ddddf438e), uint256(0x0345d26e2890008875fb72a612b6a2baef309d4d5314fd79f5f41a1ab4f9a5d4)]);
        vk.gamma_abc = new PairingAggregator.G1PointAggregator[](11);
        vk.gamma_abc[0] = PairingAggregator.G1PointAggregator(uint256(0x1d1089fdf088b1cbfd7f4b42de8fcd7d6239fb2af1d00e59cf5e643717c51d02), uint256(0x04a261f15b04d3a7cfcb2b4ad86c67d44ea64a172456f6945358781d77e5a6f8));
        vk.gamma_abc[1] = PairingAggregator.G1PointAggregator(uint256(0x02210ba2dec8e3f3a3bdd757ffe7ab12fbf0272841e62a7cb9030dbdaa05cec7), uint256(0x195d457641ea7a84267d3389d4911aa04e821f5f38622873bfec815dd65dc692));
        vk.gamma_abc[2] = PairingAggregator.G1PointAggregator(uint256(0x01e7a4950d9921904c2efa3c646a0d5a3240b9875f1edf69e155515351ddaa5c), uint256(0x2c607591fb01b7ec80a7e2a159dd3fe98e47f9b43d4debbf52189d5bd8b64837));
        vk.gamma_abc[3] = PairingAggregator.G1PointAggregator(uint256(0x03da4ad9369c1bfe177e59c99f6845228d0bc02de8b7ea63b6a7d7d0d791f393), uint256(0x012d8c096f1f1cb3618abdec15da295ab584e670b2f5e02fc84b80dfd730f837));
        vk.gamma_abc[4] = PairingAggregator.G1PointAggregator(uint256(0x1157c23c170a47119c6dadcfa1b3115c2d76938e056082bfde6ecf13f3354ac9), uint256(0x088648d03f5c47d9c5cb04093ada8e2a341f66e77e3368e687099a7326be5909));
        vk.gamma_abc[5] = PairingAggregator.G1PointAggregator(uint256(0x1eac23a797e381d85e0608c81600bd70aa4ff2090625e29d01a3b6b38184248c), uint256(0x2465e5eda205dc727902ffd552acb952a22a12e5ac535029d02538c9fec6d479));
        vk.gamma_abc[6] = PairingAggregator.G1PointAggregator(uint256(0x23524b3941cf03c534322b1d16d5fcff616d58562d15bc57cd9bb545ba45e049), uint256(0x21c9843dddbee281bfe299924818845b802b1fa4a3331eeac9cabc427ea06422));
        vk.gamma_abc[7] = PairingAggregator.G1PointAggregator(uint256(0x24c253899a02faf8583d2d2cd41a4ae1eaa1f4bde18cde39df750ee7cb85a1c5), uint256(0x1705443ba057a2346e35e9a22db58e38a06e9e66a25f281af19bf9f5db26c404));
        vk.gamma_abc[8] = PairingAggregator.G1PointAggregator(uint256(0x0db567b2a3d37c269eb75a9147e1c7ef72d5254f1ee2f131688d209143dae184), uint256(0x07bc3557f2bc77a7603c63ca57b8b79139bed5ba35277783189f87c5b4e37f39));
        vk.gamma_abc[9] = PairingAggregator.G1PointAggregator(uint256(0x1f89abd6e5f19cdfc2f51e33127a37b6805d3e4c51ab6adbc1a58f5a1b67ff31), uint256(0x1f34c1d60483f5ab22de65ce9d1d2190114ca63b4bb3354b8593f0fc984f2d6d));
        vk.gamma_abc[10] = PairingAggregator.G1PointAggregator(uint256(0x14f354a64e896d8316c6330382542150d97fb511a5d2453e96b440498a3e2bc3), uint256(0x00df0c688bf29ab23843186bdb5b2495543832a2c653365e4a4764bc1a9fc519));
    }
    function verify(uint[] memory input, ProofAggregator memory proof) internal view returns (uint) {
        uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        VerifyingKeyAggregator memory vk = verifyingKey();
        require(input.length + 1 == vk.gamma_abc.length);
        // Compute the linear combination vk_x
        PairingAggregator.G1PointAggregator memory vk_x = PairingAggregator.G1PointAggregator(0, 0);
        for (uint i = 0; i < input.length; i++) {
            require(input[i] < snark_scalar_field);
            vk_x = PairingAggregator.addition(vk_x, PairingAggregator.scalar_mul(vk.gamma_abc[i + 1], input[i]));
        }
        vk_x = PairingAggregator.addition(vk_x, vk.gamma_abc[0]);
        if(!PairingAggregator.pairingProd4(
             proof.a, proof.b,
             PairingAggregator.negate(vk_x), vk.gamma,
             PairingAggregator.negate(proof.c), vk.delta,
             PairingAggregator.negate(vk.alpha), vk.beta)) return 1;
        return 0;
    }
    function verifyTx(
            ProofAggregator memory proof, uint[10] memory input
        ) public view returns (bool r) {
        uint[] memory inputValues = new uint[](10);
        
        for(uint i = 0; i < input.length; i++){
            inputValues[i] = input[i];
        }
        if (verify(inputValues, proof) == 0) {
            return true;
        } else {
            return false;
        }
    }
}