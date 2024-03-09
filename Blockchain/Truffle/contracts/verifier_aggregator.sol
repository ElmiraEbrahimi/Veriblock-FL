// SPDX-License-Identifier: MIT
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
        vk.alpha = PairingAggregator.G1PointAggregator(uint256(0x02aa4a00765fbd277242c522e99bbf9450a51deffbb5ac143830e501075f98c1), uint256(0x2c057cd1394519cc8ddf58e11b6e38c08832f1ae3a2694b8cb16a6503617c984));
        vk.beta = PairingAggregator.G2PointAggregator([uint256(0x226393df31f89f4699ef24ce9a601062baf4b51d8eb64e43291ab69f671cba71), uint256(0x2f7c190b63458c933abafed9f2c779a6ec456ac5321f9ae2492aec8b0d6b7e90)], [uint256(0x17d7116f4a3b24dd28238a90b107f98532b23f4fe61c3d73e4d3dbf3ccd21aa0), uint256(0x037f8afeb098a22ea957a4fcf297438f6561c3f52bb404e3b6fb8545cc609679)]);
        vk.gamma = PairingAggregator.G2PointAggregator([uint256(0x2ee6b931af611404fce2ce2dc4455c32771f5a587842980ceab56f0770de2ebd), uint256(0x2cbfbdda32e8e4f21cca7ae47bf40d211764150c99028687cd6df0bb55570824)], [uint256(0x0f1f28802650fce8e98d6a64a3acebddf160ded70bbfdac06aec74b3b7954ced), uint256(0x17be0cd026f5c02f2d56e59ea750382ec781c85cccaf51ea5ade38e1d0af3608)]);
        vk.delta = PairingAggregator.G2PointAggregator([uint256(0x174d6c09f3d4d4c0de6c689b8ede45209cc2c276c2ca528d7d130627cb33a375), uint256(0x19d93724b1cf44545e0394ef556ce3ad4a1a15ef4e5c91b41d6709eb25663e66)], [uint256(0x0b1171610da5ecbc464da69a63cea0e32883bfe19be07c69a94b90f341c6d8fa), uint256(0x06beb61355719faa7dbc629664e2e3119c0d37856fc9a3655d19630f15fc1e65)]);
        vk.gamma_abc = new PairingAggregator.G1PointAggregator[](15);
        vk.gamma_abc[0] = PairingAggregator.G1PointAggregator(uint256(0x00db629f41f86644d677dc67ae04807579fffab24ce54a34bd20eb74da26f0c7), uint256(0x179257e68c6cff73878698ad1637bd45b84ca3bbfa59309b72bd9d00e635f660));
        vk.gamma_abc[1] = PairingAggregator.G1PointAggregator(uint256(0x13e8c961aadc6feb472ebb1050a545525d920d6574f9419dcbe00be954243286), uint256(0x0df1acf77b3680c42cbefcaae9c3529df771b1c98d2f1d3c6ec11d1b0388ef38));
        vk.gamma_abc[2] = PairingAggregator.G1PointAggregator(uint256(0x26b08ffe92fb5f651bd0f43f492d132dbf0e44d393c7a2a06ddf4e900870cea7), uint256(0x1a2dcc401c6f99d44a50195f0a1ffcbfb8c3436ba581bd26ad0ff62483d78c90));
        vk.gamma_abc[3] = PairingAggregator.G1PointAggregator(uint256(0x21fa3f5976c698fa57c3faf80ad2177a48ffda5eabd63ee67ecced8119c05d8f), uint256(0x10744d60a7fa81655baf6c74fb061e3c34257beeb3527fd8796d57b5a141b03f));
        vk.gamma_abc[4] = PairingAggregator.G1PointAggregator(uint256(0x1fe18f885e7b562add291a2cf8b331ccb7bc8e745d4a476dce6f04a695f23c4a), uint256(0x2bdcbeafcf67aa86172f879b119bdbf946d46a6374360af465a4d94f5bddcc7f));
        vk.gamma_abc[5] = PairingAggregator.G1PointAggregator(uint256(0x1330054f5dcc537fa6e45da27f46aa8b03a2f30aed94bab767838604d9e1db7a), uint256(0x286eb7499b08bd12e72db16ca7e3e8ed48935dd8a42ee1fff3bf2050f8352e37));
        vk.gamma_abc[6] = PairingAggregator.G1PointAggregator(uint256(0x16e94e4b0fd6cc32304be8aa221339468e7e510988f4ceef6dd68c1690704f2e), uint256(0x2786af3aea438dd45e67513df57924fd0c111bf4854fd1cf2980efaccbad6445));
        vk.gamma_abc[7] = PairingAggregator.G1PointAggregator(uint256(0x1a56a51a947c59b1c7635f1ca94cc9b201ae28b4a00a0afa7f8e0616c596ef53), uint256(0x0af5fa04203910ab9e12f58e66ab58ed8a3423e40266064574e846d0bcb8b800));
        vk.gamma_abc[8] = PairingAggregator.G1PointAggregator(uint256(0x26bb5d982bfd6960c712539a98d9176e20fd64ab94880c6967f1f626e98fb751), uint256(0x017d796115203e30f08a98ad1028658bcafbb289fd1a856c1dce547f7bd23512));
        vk.gamma_abc[9] = PairingAggregator.G1PointAggregator(uint256(0x1c455f4204ae6972af2f01263ee70031955daf1a91a0a627a77428e8cd3a9844), uint256(0x2625413eda053c1644d714b9bca39a04d4987ce2b86eb3a7112bd30eef81505d));
        vk.gamma_abc[10] = PairingAggregator.G1PointAggregator(uint256(0x021dea2a57e2951b618e89e4d44107641b0d8d68b3a02e5a19f85c3e366ad84d), uint256(0x1ad98de98a8f78e8796084ea6ec82d4c69d035da8b22e55119595733d4342cfe));
        vk.gamma_abc[11] = PairingAggregator.G1PointAggregator(uint256(0x2f4f3bee6134bc2647a52b1d56bcbbc985ce6154af71d1cd38efa7583b58ff6f), uint256(0x1dc6b77772f9d9b0f8e857438f2816370a55e547ebeb54e402b81d5bc8aec849));
        vk.gamma_abc[12] = PairingAggregator.G1PointAggregator(uint256(0x2f2fff716159d3b603b456e6eb3d31b547bb91a4587d21fc68768e991cf4fb66), uint256(0x1c7834fd596dd02861e56202b34dc1de9d9daa7d0dff2e01c3ee2bd939e1ede4));
        vk.gamma_abc[13] = PairingAggregator.G1PointAggregator(uint256(0x2a20b277639c7afced1ef01c3fb4c355509430e6c5a461b7fe9d3a6e5dfdf038), uint256(0x231a77b728d25d864d98f285153fcaa5406ab068b9ca6049e3675e3fcc072ce1));
        vk.gamma_abc[14] = PairingAggregator.G1PointAggregator(uint256(0x049591c88f0e2c0d12253493a2751564049a5bae25ff81c6c1901743cbd30e44), uint256(0x14586d364ce5f43b339c857e2e29a3642362c0b727d9c3734104eb556b276cdd));
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
            ProofAggregator memory proof, uint[14] memory input
        ) public view returns (bool r) {
        uint[] memory inputValues = new uint[](14);
        
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
