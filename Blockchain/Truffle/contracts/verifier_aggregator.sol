// SPDX-License-Identifier: MIT
//
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
        vk.alpha = PairingAggregator.G1PointAggregator(uint256(0x07afbc75d74a53ce71cf5b93b8a9bd2a20cdfe2592283526db50a419fee2fe34), uint256(0x0b4051853e157db7402cd2de583d70c60da5713ca81c98eee45295ec4f09f5a2));
        vk.beta = PairingAggregator.G2PointAggregator([uint256(0x289a16fa63ba103340cd319c72184d19dfbd8ef47719c51abb25e23a660b72d4), uint256(0x1e2c275b2bb1683a1ae5286c5c18771d5bbadbf43e9b87c05889691db02d2efa)], [uint256(0x1cb765c23dc5f1ce116f018bdc7b3761f69240c7449e2ba2e8975f3ae71ccd3a), uint256(0x27af9a7a0081bf054dd4c3988476cdd0a31b41845e9b4bf448963b4d11a34481)]);
        vk.gamma = PairingAggregator.G2PointAggregator([uint256(0x05d42845c192c12a2b738c5e7e185d6cf49befd6167ee0c47f10d36659c7cb80), uint256(0x1e379f3ff723d04dd69f7e865a4684bf194eee97536cac88ceaa9f7d17e30855)], [uint256(0x2440f1bf0142a8083ca6667aa51027897fa0971df938ea040c8ac0efe3d0381a), uint256(0x0162a28ef87b9f1b243c999e0021e924d42bb09df673dfb1cbaf6ca151f1aded)]);
        vk.delta = PairingAggregator.G2PointAggregator([uint256(0x018ad7c05b104be76d31ae9af0dcc3a364d19bf3e8511eaac80902eb1d551ee9), uint256(0x2993251202d3f1046815f3817198eebca8c6c35fe45ce3d2248d56e2b38ad453)], [uint256(0x01944d619f4ba010948984906af17f4e28ec7c23092b7e64c809579100773816), uint256(0x28c9e24f49aaa170fd3014f7737c226fe658c85c86dbc277c03c2e00db51c7a2)]);
        vk.gamma_abc = new PairingAggregator.G1PointAggregator[](9);
        vk.gamma_abc[0] = PairingAggregator.G1PointAggregator(uint256(0x10cc9ee6859fd1faab622bd45caacb5a46b9af7a46856d3e80eb36767068b230), uint256(0x2812169943dd6efe59d8196327d7830e0478f76fd30547467d89f6087a30017a));
        vk.gamma_abc[1] = PairingAggregator.G1PointAggregator(uint256(0x15acf8636d57f57b83c081d19480e60c72a04540f9c1d4b9f0316b9bf652acdb), uint256(0x01eb2595d5e9e085d8571fcb9dcd7b05da3165324984c289fe42f9515b030a7c));
        vk.gamma_abc[2] = PairingAggregator.G1PointAggregator(uint256(0x0c7419e18745ad4d6fd56e2464f9a318288499fea485d54637621591568416d0), uint256(0x2a9ec00c2d59b2285ba88a887ae92eff3944fbc909417a26bd9d82b3d429970d));
        vk.gamma_abc[3] = PairingAggregator.G1PointAggregator(uint256(0x2dd1c4b0a75da30a404c35e6f2bec5cdba2fc955ba3c4836119ccd06ef376a64), uint256(0x0aa8a67062ca444ed4c65ae574daa1e6d092bad31dd26880ecb7563085654459));
        vk.gamma_abc[4] = PairingAggregator.G1PointAggregator(uint256(0x0422900fc4af9f130d38d1a8d7059660782a3eebb852f03ebcefc41a5f97df76), uint256(0x2daab50f312c4e16e4f2e495f78b5e3edba0aab3a5dff93cd613c63066758712));
        vk.gamma_abc[5] = PairingAggregator.G1PointAggregator(uint256(0x17fd38c3e09b9b48986ac1495f684eff77a0ace29db825f0533865a69b4f42df), uint256(0x236b72d7343c2a81113705c25d776d7bdd34d188d60e64bd4844007757890d67));
        vk.gamma_abc[6] = PairingAggregator.G1PointAggregator(uint256(0x14fd4418d0c6106e48410ca0915b292e69c76ab38fe18b807f01c857106ea55b), uint256(0x2639ae16e6742f46ae066a93b5431f740a65e77a7ec69cdfa9b26383725a9784));
        vk.gamma_abc[7] = PairingAggregator.G1PointAggregator(uint256(0x0d71ce12a66762ba0e91ed2dd5b7d29acf8281688eaf2335ace5a323a4494c93), uint256(0x0a39abd6eba8af3cb35bdfeafbc6f9bfdcac580de2063c21eff78759ed652bae));
        vk.gamma_abc[8] = PairingAggregator.G1PointAggregator(uint256(0x269dcf414d8353b7105d485d0bc7ac99710003daf5cadfa5cfcb60da5fbb5982), uint256(0x0167ee467b7fd6cd81b8d6a789cdce8f1201d41101de403f2eea6a7c7846dbe1));
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
            ProofAggregator memory proof, uint[8] memory input
        ) public view returns (bool r) {
        uint[] memory inputValues = new uint[](8);
        
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