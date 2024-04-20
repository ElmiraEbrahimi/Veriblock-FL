// This file is MIT Licensed.
// SPDX-License-Identifier: MIT
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
pragma solidity ^0.8.0;
library Pairing {
    struct G1Point {
        uint X;
        uint Y;
    }
    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint[2] X;
        uint[2] Y;
    }
    /// @return the generator of G1
    function P1() pure internal returns (G1Point memory) {
        return G1Point(1, 2);
    }
    /// @return the generator of G2
    function P2() pure internal returns (G2Point memory) {
        return G2Point(
            [10857046999023057135944570762232829481370756359578518086990519993285655852781,
             11559732032986387107991004021392285783925812861821192530917403151452391805634],
            [8495653923123431417604973247489272438418190587263600148770280649306958101930,
             4082367875863433681332203403145435568316851327593401208105741076214120093531]
        );
    }
    /// @return the negation of p, i.e. p.addition(p.negate()) should be zero.
    function negate(G1Point memory p) pure internal returns (G1Point memory) {
        // The prime q in the base field F_q for G1
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p.X == 0 && p.Y == 0)
            return G1Point(0, 0);
        return G1Point(p.X, q - (p.Y % q));
    }
    /// @return r the sum of two points of G1
    function addition(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
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
    function scalar_mul(G1Point memory p, uint s) internal view returns (G1Point memory r) {
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
    function pairing(G1Point[] memory p1, G2Point[] memory p2) internal view returns (bool) {
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
    function pairingProd2(G1Point memory a1, G2Point memory a2, G1Point memory b1, G2Point memory b2) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for three pairs.
    function pairingProd3(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](3);
        G2Point[] memory p2 = new G2Point[](3);
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
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2,
            G1Point memory d1, G2Point memory d2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](4);
        G2Point[] memory p2 = new G2Point[](4);
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

contract Verifier {
    using Pairing for *;
    struct VerifyingKey {
        Pairing.G1Point alpha;
        Pairing.G2Point beta;
        Pairing.G2Point gamma;
        Pairing.G2Point delta;
        Pairing.G1Point[] gamma_abc;
    }
    struct Proof {
        Pairing.G1Point a;
        Pairing.G2Point b;
        Pairing.G1Point c;
    }
    function verifyingKey() pure internal returns (VerifyingKey memory vk) {
        vk.alpha = Pairing.G1Point(uint256(0x0d2fd4a4cb6e376e92d2db70b80470c7ce709274a7b9e501d4a6b173a636972a), uint256(0x11d9f11eeff68362f32991f6a0ad5099bcaeb179cc728d2da5187d855298f83b));
        vk.beta = Pairing.G2Point([uint256(0x220d4494c1b03145bdcbb110a035d739b04875496ae7fbd7796765355eebdd68), uint256(0x28ae72592996158d44f84eed256065586369a5e1cf9982f8b5fd9917b8060635)], [uint256(0x22fceb71ae4e3a11e53911f4b6c3eac005a375fa6111d4bc45db973e5226c5b8), uint256(0x2aea00f579919706c10f07d5553d3792b1aadcfcfdf028bf42f1def6b013bbd5)]);
        vk.gamma = Pairing.G2Point([uint256(0x132ffb55b3fd5a6353c77d7bf8178fc0c55fa45a9c62e8e9f17a78e0169d0b10), uint256(0x19d9125e01e4c668cd5a4638365e3446c1aa5faf0467b184ff2515ead92864de)], [uint256(0x2ec65bb492b0b336c85ade005406a4649ecd18d3d9facc5aa7e074838f0721d2), uint256(0x2244f41a90c23d167a137c49ba466743c18d2dc210e36b2bb8511897aef01a67)]);
        vk.delta = Pairing.G2Point([uint256(0x152f8b17375d49c42cd40cca13494d972d0fb502804289e9171a45247bcc1fba), uint256(0x1f5b81afbdb6f34876aa60c375f66c44eba7c20a68b4bff201ed58c7cb7ce49b)], [uint256(0x2bc2727a6c67e8777607e852d2023d37ac5227dc0ef91a9e1822f800030d3b10), uint256(0x0b9d0fc03801a52896396e98480cc71833cc3f99dde4a32938198918fec3ff0e)]);
        vk.gamma_abc = new Pairing.G1Point[](6);
        vk.gamma_abc[0] = Pairing.G1Point(uint256(0x123eb2a4c08d62f1aceaf9b33806d7f57ba85da971488d33a5acb511f4e250b7), uint256(0x0587713a4f4534da652396748b2bfc45cfaad13c07c47997ab5297dac89d2945));
        vk.gamma_abc[1] = Pairing.G1Point(uint256(0x2324f6185bf77fa8822d7c64630f3333ac843b2fb548807d8056a2f3d527466e), uint256(0x07430748746eb9840d979843ea87987e12243b07b97b213d8330558b539f4467));
        vk.gamma_abc[2] = Pairing.G1Point(uint256(0x13cfc22b19e584db2010dfe49e97b5ec0bdec9d383b9047f2df5d933fbeb3385), uint256(0x0ef49d34c488fbd23c7747b663d38c4c822029020ca0693fa4d4bd6f584a0ef5));
        vk.gamma_abc[3] = Pairing.G1Point(uint256(0x08ce156e0e15e08075cdf52f95f90d47b5f5017477be02a65d0b4b636f58837a), uint256(0x2b43fa6a5b810b900b096684d6df0013292565a3da53796ea6a0a73a15089d27));
        vk.gamma_abc[4] = Pairing.G1Point(uint256(0x2f22da58d23be49956236de97dcedba3cd140283281062b96bae73ebc8e9210d), uint256(0x2f710599544a78c130146c61a7b1247a32fd122a8248a69c8c8ca9a81d902ce3));
        vk.gamma_abc[5] = Pairing.G1Point(uint256(0x124fd48dc8437eb84b2023d7df2b13c682284bd6bf6f7b9ef3650f78468b7229), uint256(0x3041d28635d39946de38c219dba600635be4947754d5e90386bc5b225e5c3921));
    }
    function verify(uint[] memory input, Proof memory proof) internal view returns (uint) {
        uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        VerifyingKey memory vk = verifyingKey();
        require(input.length + 1 == vk.gamma_abc.length);
        // Compute the linear combination vk_x
        Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);
        for (uint i = 0; i < input.length; i++) {
            require(input[i] < snark_scalar_field);
            vk_x = Pairing.addition(vk_x, Pairing.scalar_mul(vk.gamma_abc[i + 1], input[i]));
        }
        vk_x = Pairing.addition(vk_x, vk.gamma_abc[0]);
        if(!Pairing.pairingProd4(
             proof.a, proof.b,
             Pairing.negate(vk_x), vk.gamma,
             Pairing.negate(proof.c), vk.delta,
             Pairing.negate(vk.alpha), vk.beta)) return 1;
        return 0;
    }
    function verifyTx(
            Proof memory proof, uint[5] memory input
        ) public view returns (bool r) {
        uint[] memory inputValues = new uint[](5);
        
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