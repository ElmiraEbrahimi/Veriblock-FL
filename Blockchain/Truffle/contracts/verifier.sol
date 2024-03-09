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
        vk.alpha = Pairing.G1Point(uint256(0x0c9046c053a76daa01ac8a1f94e50a665e7a3f2fe92c057d906811f7ab318a0d), uint256(0x1f0f8a16cdbe8e6405f14c475e16ada259e574707e0efac8603c5db11ddec10a));
        vk.beta = Pairing.G2Point([uint256(0x227264715f1c27bc1e3b343c5054e7a6aa6c27597db0397cbd3681cf2b3014a5), uint256(0x1e1acb80f52e5b3c7bf46b0254e67daba21526a54c8ca1ae24a75d4617a0bc84)], [uint256(0x21479dcaad0ca2181cddbf01e0d010b5cb891242ed05f661dca1afba63811ed3), uint256(0x0e3090c5952d3d2ae3984be4d7ae59c3394c694ea0fcacee24893f861650f9ca)]);
        vk.gamma = Pairing.G2Point([uint256(0x1358fdaad649278021a9c42b259b88ec658a8bde951730727c7b6aece7fc3a77), uint256(0x28df4319270da5cc910cb6884958ce7e2168ce146708573a8c7d591b02935862)], [uint256(0x0bddf6f11599c6bca17abaa189ce84f86ef82eda189d5ad542ccff7e89f63561), uint256(0x00830ed15e4d98f3c9af794f44c15212a2d02c5cda49f810159d87d85ced5e27)]);
        vk.delta = Pairing.G2Point([uint256(0x1640c4eb53ccc4d1e775dd8cffa4a6ef798415c4de47e7914710424c0e7a159a), uint256(0x14b229e91ff789dc56dcfc13ba8df33aed4e946a5df83fd046cdab24fc9baca6)], [uint256(0x0596f138a647c44e9c35b0cdfadfafdcc69f63113cd4d019acc1eb460fd858a5), uint256(0x02c2914f42ea4793ad32810b5cbcf1e116b7a58a8c4b0e54a3f319d000903345)]);
        vk.gamma_abc = new Pairing.G1Point[](6);
        vk.gamma_abc[0] = Pairing.G1Point(uint256(0x0454bd2857e164664554c6ad39688f0779927dba1b88a1e5ebf31690f1fc5f2c), uint256(0x066ccba050f7437ca5d0596e236afdc04ea9f7f4548f5b3db527334983752078));
        vk.gamma_abc[1] = Pairing.G1Point(uint256(0x0399539a3a0b4a5bf8b53b1426ac9ce2118e1eb06eaef4336ff3b5f81783fb1f), uint256(0x26f29932e99845076b8e8988a445ca2c268837b06baeb85a628425d52fa71aea));
        vk.gamma_abc[2] = Pairing.G1Point(uint256(0x13b3a20d8facea386e4bfd3eba6f28f5f6638c75cbd153f95f39fd649b9e3c2b), uint256(0x0558bec4d371b7b82a545d5b3f314e2572ac5f5ffb21c6c6d2069e6d5116c147));
        vk.gamma_abc[3] = Pairing.G1Point(uint256(0x1369e93ba4233f999efc2c16863f5e837731a7a2e399e02ab7ce748b69ed25d8), uint256(0x1e89e698f0dffd21512d3fa82271dc88c79bfc010b306801731a4419b42ee5f0));
        vk.gamma_abc[4] = Pairing.G1Point(uint256(0x22b72f93a7722b5e0b318a20a4281e340f8dad9fac1b9b9bbf5854c458552622), uint256(0x12c0105d23854a1f27db2fb0f9263a145a80f5cd8d5bc34b50be5bd989bfef52));
        vk.gamma_abc[5] = Pairing.G1Point(uint256(0x1ae4a63ae6d13a9000ee926ca6121b24fb62a44deaa9e5d2b7beecdb9a97ecb6), uint256(0x00939c40f5e7cc68c73823d6313edfd61636c39571d615e5f1af0f0e1bf0b4a7));
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
