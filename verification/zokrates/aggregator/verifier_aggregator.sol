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
        vk.alpha = PairingAggregator.G1PointAggregator(uint256(0x09376bf6cb30842dc1eefcb91b963bd27b063f813b0e3614038f951a1ceb3ddf), uint256(0x094c96f9a1c438502c8aba47db9a07978abeba6ceac8ff07ae9add5550a41527));
        vk.beta = PairingAggregator.G2PointAggregator([uint256(0x209a3c7d7594e90e97400b1f4ac55281cfb4ab07724da9cb4c03622ef211fde6), uint256(0x2c97237308556f9619e0b716910c582a9db7ab5ba87989bc63aa9fa7393c9ad3)], [uint256(0x0117643a39e5595d1ebe21c62d3e84334a8a72690f479de564c5192df00b7ecd), uint256(0x28efc8de31f4fd57e30139377bd38d439234398d0a4ab9da764560762829ebb7)]);
        vk.gamma = PairingAggregator.G2PointAggregator([uint256(0x0abe0f30772b94b49ed74481306d60bf241786d3ad17cd3e3adfb77781993b2a), uint256(0x01e7972aef8a981c20d5dc3ba5c471cc0c3e88bb04c06001cb6d41aed1a39caa)], [uint256(0x1a7da86fdd32540944c08e27c7499dd8f87984acc73976772faba561de2db0a6), uint256(0x2595e2c7be1b3ed189d67cd8a9c617c2613b93f39e537ea7b92856621361cf64)]);
        vk.delta = PairingAggregator.G2PointAggregator([uint256(0x244308653b05ad4ca6a681a438b5f19dd6320788c4d0e60ae32cec1d54b1510b), uint256(0x1acebf91a47a51f8c5069aca0c62b5a8d7d7c2e17bee22bf2bc53521abd1c802)], [uint256(0x2bc4efb6180e75f0839dcc5ba4fc24a688127280e6e9d6c54d9e45d7298496ed), uint256(0x00b34ad52a38837f91864e68e03ed4490298b1bd759533f1c48ca602b7b623e7)]);
        vk.gamma_abc = new PairingAggregator.G1PointAggregator[](11);
        vk.gamma_abc[0] = PairingAggregator.G1PointAggregator(uint256(0x0f7ec1cab090691d4a2336cb0c8cb3316901abe5c9d891a5b529a5f2b8b91b23), uint256(0x044aac092d769b83fa4a2e016b7e6e703eaef0dacc157874913209eac3aa6c6a));
        vk.gamma_abc[1] = PairingAggregator.G1PointAggregator(uint256(0x137f065a57a2e778acc8712fca343b0ce3c75bc4a972acd6b6a9b8e106d14e83), uint256(0x13aee4b289edc022b885e79494fc0bbc9223da02df34b463fbb62e172c3a94a4));
        vk.gamma_abc[2] = PairingAggregator.G1PointAggregator(uint256(0x0176cd08c1ea196a804787bfe693674c59667dfef08fae2ca2936c97b2a45d13), uint256(0x282977ac069217b6e9f1820e8bfd70597a36a0d0c877b8b8a0ef1e7b0f06d7d8));
        vk.gamma_abc[3] = PairingAggregator.G1PointAggregator(uint256(0x0de45ffce9a1ba69eb7ebc839cfbb34dd22d62910f15e5247691cc6e56e2badf), uint256(0x1f6d9add493e6bccad6979d49da240b82cd54603cf66866e071324f98c927f89));
        vk.gamma_abc[4] = PairingAggregator.G1PointAggregator(uint256(0x073a354b1de0a7497666d6eb91e8724b3b014e1013aa3fea776e05f7e466178a), uint256(0x2fef5393e1e4a6ca1c0ff485d140b8a617939d65aead651cb3390642ef9b4e8d));
        vk.gamma_abc[5] = PairingAggregator.G1PointAggregator(uint256(0x02d81e6c1461b6e07596923c84ab980d65a1170f080f15bf64e22f7e7bf72227), uint256(0x194ed06fe83a8e61febbc58c6ec3ed22585a7a72f1fce3132d66f3811c23f431));
        vk.gamma_abc[6] = PairingAggregator.G1PointAggregator(uint256(0x2f2b06a6030dd1011213924f1ad915c38af14f3b81e6bd9d6a39a5182b40d0fc), uint256(0x0d3ee6e7363530cf23d0d8f298d33eafe947d7eec852be821df248c2889b83c9));
        vk.gamma_abc[7] = PairingAggregator.G1PointAggregator(uint256(0x22bc22b82462d4431dc201c0a4d06d32fd862a66c4dccaba0c393b38a9519af0), uint256(0x1b1ea3ed3ec56fff9280047f2a9c22a240f4951ec18834c1a958ec5959cca30b));
        vk.gamma_abc[8] = PairingAggregator.G1PointAggregator(uint256(0x03b1abc4296392f7cf7b7bd913e9f30fffe373b2da22e749cd95e38d8abcbe33), uint256(0x26900501a239347c2c82f73676a212ba3a93d030b72cbf4af67504de7181f619));
        vk.gamma_abc[9] = PairingAggregator.G1PointAggregator(uint256(0x18f083b98aed3b12e737c155117b720025cdd861802086262f89292f3a4dbd12), uint256(0x079f4bd7e29008e73e369f212d6af47f1b092ce49da947a6108a54eccd72e8d8));
        vk.gamma_abc[10] = PairingAggregator.G1PointAggregator(uint256(0x0dfe8e84d708a79f96931ee78f6ecfb7714efa5790bf734f21f97aaaefc827dd), uint256(0x05982b96a6077226f3019027ac556c1532bda8aa714604fe50dc1116f4e30f4b));
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
