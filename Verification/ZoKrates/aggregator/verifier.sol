// SPDX-License-Identifier: MIT
//
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
        vk.alpha = Pairing.G1Point(uint256(0x0ff88f662ba22dbcd1c329b55c7121b160136764f170e117ee0aad6130d193ae), uint256(0x20ec12207f5a68d6b2ec915dd265a949243c4711dde6916b65b5bff5b7e62f15));
        vk.beta = Pairing.G2Point([uint256(0x0d1522cd03b759f8289e71fe9e507877b8a4fac4accad224d212022a7a11d7a9), uint256(0x08a8b4944a7e37dcbe4021329aac01c01e0e66b9d4f419bab7555c9eeeb4b867)], [uint256(0x20390f33118481c64c78884e7952e56a5b7b2930cefe7d56b723f076bf9a8d20), uint256(0x06d031f8a1d540eb6142871cbbd29da3de510172485f8345d11a34c1192c8c1c)]);
        vk.gamma = Pairing.G2Point([uint256(0x18adeda78039e7498779c4d6343012c18f4406a5ff06198866a8c5b63c92d87d), uint256(0x0c5af27c8001547b353a80454df7b995e93420dee274cad24d0897befe9d09e4)], [uint256(0x117aaa06ddb2848286a8649aad0f0f7bdcb64a0ac94a94235c6b1f5cd30528ca), uint256(0x2ff5c909c358c79b52d4572e24291ddc11fe2b5fcefdbb8e707d6b7ad98e83e8)]);
        vk.delta = Pairing.G2Point([uint256(0x07dbc0c9890d8043023d5175f0c7e7551a3eda50bd97d0a2dbb0baa7e2c7adeb), uint256(0x1ed3b719329421f8cb3ec624a4ba250019a3d4658e767d733128029df6136f0a)], [uint256(0x2535a2e05ddb8170160dc9af53bc02a8c14eb154440360f3ddffa37f99549ea4), uint256(0x2e643c6509ec1226aa80e59085c5d9c9c5ac36159e0b75fe80833b02bb6fbe1b)]);
        vk.gamma_abc = new Pairing.G1Point[](9);
        vk.gamma_abc[0] = Pairing.G1Point(uint256(0x05f9ff07fe54c12dd804aae14957dc057d117830c91bde16c9af074c2b45ce23), uint256(0x2a9f258b0849f5261ec111800aeabaa7cd7dd2f5c9b20f0858350ebc289ff93d));
        vk.gamma_abc[1] = Pairing.G1Point(uint256(0x01678067d2434364cdb703962c79a915356cce66c6746d497e419b8da6a4fddc), uint256(0x2d78bddba245622f0f7bf6fb01b38f45505d4b9f6d19661b334f3c4682ad5941));
        vk.gamma_abc[2] = Pairing.G1Point(uint256(0x07711c052dcb28861e5b7eb00f69799eda5ca068f49ea85121f6144da74da362), uint256(0x077d4b09037b8b1c96fd8347cc6eb35dae9f386b834184d44eaec5ee77fa34b3));
        vk.gamma_abc[3] = Pairing.G1Point(uint256(0x1b24549341577200dfaf09c6671524ab7a8f32945d75bfb397f88a23f089ca67), uint256(0x1c10be97afb7f83557e0ce35d33272b44b90b10cad854d61cd9c5fc987110b7a));
        vk.gamma_abc[4] = Pairing.G1Point(uint256(0x2c87803140e01247013f7e9a4142497ee58e7dc49c1e5a2b3d6823a242b301d4), uint256(0x0a5323c337bd1f5a697cad1817e52e06a4c412cbfa0fc587136e54ef160fdd52));
        vk.gamma_abc[5] = Pairing.G1Point(uint256(0x033f177ff06087491f9408d4c581192b2a5bf29649f065223d7de3d07d5cd24d), uint256(0x129f0d89c1ee5dd0517df9a45c6135d0eb746d094eb14d9d2e94f882db96ace4));
        vk.gamma_abc[6] = Pairing.G1Point(uint256(0x050c28ccdb16cd931528d079060b3cab57a691a2e55b4e4cda5b7b8760d72f10), uint256(0x158f120e4374db1f1a8882f50a75959a3baf26694e2846a1f4a3138f387ca446));
        vk.gamma_abc[7] = Pairing.G1Point(uint256(0x2d0aca047a0b4cf15d155acbdb47e59d71edd07920bebe382a6992f7afa183a9), uint256(0x07296e5db09ddf8824e1ccac422e3a1111c873105cd6f23671271b0bc75b64bd));
        vk.gamma_abc[8] = Pairing.G1Point(uint256(0x004944ceb8155ff0697a96b99355557a3b148e4279df33db0686babb98e4eacc), uint256(0x01023ec8de6e9abe873af3901ea60a07936da699dcffa570e58f5f7a0d0f5fdf));
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
            Proof memory proof, uint[8] memory input
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