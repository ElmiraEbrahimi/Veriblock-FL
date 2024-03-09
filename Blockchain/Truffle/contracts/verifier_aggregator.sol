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
        vk.alpha = PairingAggregator.G1PointAggregator(uint256(0x1c18f3801e629848569a0bc1f0a91d1b52508dd4718a5be0337b7eba570bf721), uint256(0x2a8257b450464e2c4c6cf665556b6b613c7f5ecb9cb857d548c1fc091b7cef51));
        vk.beta = PairingAggregator.G2PointAggregator([uint256(0x18fc7d25f8679d46275d716ffffbb2cdf9e413a2c1166247d20da5e81c51d1b0), uint256(0x07ed7dd4c20b8228b71a4a0ec6587bea5dd18316868df4bded19bd4f9b662924)], [uint256(0x265ebd0afcaf608f0718e09af1e0ba939b52927ee95a00131fad0f990de73075), uint256(0x2549987139a646145dfe4754b30dc65f13a31885932d2133c945e411894c436e)]);
        vk.gamma = PairingAggregator.G2PointAggregator([uint256(0x245b06fc26af6422e993f878332249d2dc3bf7ecb566be587113cd2a13eed664), uint256(0x0b4e270ce4f488756e5b358367a2b580d0458c227732b1a32f67ed058430fde8)], [uint256(0x185477f000b6a24fc74a72ed3198f4c67163f8fd0bd735b3053b57e6700a2194), uint256(0x1ec36b479efca1c43e46c4bdd2ed1aedad63efbae949df3efeb91196909642e0)]);
        vk.delta = PairingAggregator.G2PointAggregator([uint256(0x0dc9e5fd8708d8c7ad48097957e208500a54b43a9558904b7707efe6f382e22b), uint256(0x2931bac9db54bcaf4b46f459a8b30d947f83c2674e169b7c4cdf5f7b52b2faba)], [uint256(0x275c88ed7d9b4d320c5ff08754b63210a8b1028185f12df7f04151567c0587f7), uint256(0x1268f0ba774b955d77c53cb473b87a4e89780e0b38aea08071da5c303df7487c)]);
        vk.gamma_abc = new PairingAggregator.G1PointAggregator[](21);
        vk.gamma_abc[0] = PairingAggregator.G1PointAggregator(uint256(0x273654e1fac75eb8bc4d9cf304fd2da7d5e66d244825666972788cdfba0235b2), uint256(0x22d8fc23d7895618f23027e20f446fb37a5f9b615fb2af573fd00645c38dabec));
        vk.gamma_abc[1] = PairingAggregator.G1PointAggregator(uint256(0x23e46ab444629bfaef3684d49df96a14ba1e778b19f7be14cb2d66e7634f462d), uint256(0x2d004eb269cf7570902e92ee20693dd074b4145f262021ce4b8faf246fa7ac2a));
        vk.gamma_abc[2] = PairingAggregator.G1PointAggregator(uint256(0x24d52a79fe5f2aad02ea0a0aabb15d936c40db751d9b938abe5f5a33efaac664), uint256(0x246b2eee8a820d7258de97a148b78220a5565d4973ebf70ee3879e02faaf3c2b));
        vk.gamma_abc[3] = PairingAggregator.G1PointAggregator(uint256(0x2e573570cc6d57b4eaff6a4d8724f9f50bedf94ad702a50f008c7bdeea81f564), uint256(0x2eae38bdb91de68b99d9bd55cd4a01f46c7c94de47b00827266f44abaa6d3ebe));
        vk.gamma_abc[4] = PairingAggregator.G1PointAggregator(uint256(0x18716e4efeee67183843ed1b9692fb3dcca035347e4d25a26e190a33521032a0), uint256(0x12592a1d7d279b60facb5531e50bbfa391efaa276b366aa45053bcb5e6d29fd6));
        vk.gamma_abc[5] = PairingAggregator.G1PointAggregator(uint256(0x1222a2ac096dfb687d1da5b401b10534a0cf436c2100486f8cb2acae59fd4686), uint256(0x2b335bf10461b310282758b3fbaa9e392567eacc02b699ac1331cec905b1cc87));
        vk.gamma_abc[6] = PairingAggregator.G1PointAggregator(uint256(0x1213307b6a21cbcb0c4df34890b7c8badfda95a5513efa6149b86cf00d3bf636), uint256(0x1156136301655fbc2d2606b6af2aebe725d63e2f4a40a21af52d5035dc85c03e));
        vk.gamma_abc[7] = PairingAggregator.G1PointAggregator(uint256(0x27d2826e0c7279a269c7a038bf38f9d25b0b80358d0b873e2b71e80e62eb639b), uint256(0x1b04a0dd79db52d08460a1724b093aed97c449abf6efdd6ee175a1b1463d4615));
        vk.gamma_abc[8] = PairingAggregator.G1PointAggregator(uint256(0x1d640d0480458942f2d0a3738cfdbfc5aef68b571b0539e43ff3900d3c4055e1), uint256(0x05e74b6b3c588fdf64622660c9ae3f24e9a06ca67857ab514fc92d74878d2ba0));
        vk.gamma_abc[9] = PairingAggregator.G1PointAggregator(uint256(0x0da4e338462e3f76a7bc33a6a8fbeb96fed4e646aa424caf3cadd8542fd9b720), uint256(0x1bc178c1491ff42e56181b797ac6996af9da42ef19b3222a7c0f65fa5fa68a72));
        vk.gamma_abc[10] = PairingAggregator.G1PointAggregator(uint256(0x0d0aa6979e4f1c14e709d7caf14a18e1215ce6c497209cbc29c52462fcd17e40), uint256(0x148ff9215de01d60c4a116c0ca223ff7f943cba9dba6d0b5984db178dc814aca));
        vk.gamma_abc[11] = PairingAggregator.G1PointAggregator(uint256(0x055454f2579485153ddc00e7e255b0703522c5770d2eac85f5bdebc09cc9172c), uint256(0x2cd8cea8bed47c42d56dc2654c2014b8ba1b2f7eea13d0242e7903e50ed22b94));
        vk.gamma_abc[12] = PairingAggregator.G1PointAggregator(uint256(0x0974438b2deb6ef91b7cf3f381e2801959022e9faffe28650708c72f4357ef87), uint256(0x2df8521a71c1297cb9e103b621d6214937fe8512aba7cf9c1188cd516e6fb8da));
        vk.gamma_abc[13] = PairingAggregator.G1PointAggregator(uint256(0x1e7a9ca81bf1f6cd01d9341089fc41153c024f221b4f3f9e81b0a7cd57c48e5b), uint256(0x2edcb363093d21e2f4be2e1bc8fde92a2d235bd78464b8a65f6c9f9db7ddb05f));
        vk.gamma_abc[14] = PairingAggregator.G1PointAggregator(uint256(0x0ba82c6fe2cccdf08621934e5909474f436dcc45cafd7cddeb168546a455305e), uint256(0x091b42afde4f696e61471eb542ea103697c3824162a7458d3bbbae0fc99065c7));
        vk.gamma_abc[15] = PairingAggregator.G1PointAggregator(uint256(0x20ca774c62f262a0a6ec77c5dbf1db7b2c264e142deb3cf4c1d45f9f8a7d2b68), uint256(0x1b069b5bdbb8fa9fed4eab9729fd0d09a9c28dd934c92d10d9d47068935f6785));
        vk.gamma_abc[16] = PairingAggregator.G1PointAggregator(uint256(0x1fb829068a9199c89a1342f0d1085311451d867acf97d986d2dc6ef3cabf5fdc), uint256(0x04d2c13874bbd7926dad8db3cd28eee17a06fff0e3358560dae43039b66ac58b));
        vk.gamma_abc[17] = PairingAggregator.G1PointAggregator(uint256(0x2a8f7f5312049a9b0283366fe6ab0f26ef4c158f202f737e3d68823fb169296a), uint256(0x153055741d438b3c23c3a81e32c046983a2fc89d5d0b3512f40c8c6e8a8c0250));
        vk.gamma_abc[18] = PairingAggregator.G1PointAggregator(uint256(0x2882f1134e9fb2aac66d66f6c51a74274eac5b9bb9eb39c6d729bf846be88eb6), uint256(0x241da7d7b83bb007db3df064de9bf1a9c75785fb38a0f64c5d5dd7f5004442f7));
        vk.gamma_abc[19] = PairingAggregator.G1PointAggregator(uint256(0x024f3d475df29ad3fa119e4fa04558d7ac4aec7e7a9fb7310ce53a5803d981e7), uint256(0x300427431eabe458eb262cb36304e9860a573df4babede6266a96f9c898523f9));
        vk.gamma_abc[20] = PairingAggregator.G1PointAggregator(uint256(0x25f87d0f5c37cf135dfadb264f928e2eb3e44d6e200dc4563cdc68964090c82f), uint256(0x1c4827d42e22588f154578d9dcbef1510cb8b3f35fb0af35c826e7607dc83ed0));
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
            ProofAggregator memory proof, uint[16] memory input
        ) public view returns (bool r) {
        uint[] memory inputValues = new uint[](16);
        
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






// This file is MIT Licensed.
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
        vk.alpha = Pairing.G1Point(uint256(0x11945c57f7097d24084f91754a4fb0cb9310b7e4514a7018dae3615cb7660b93), uint256(0x1cb1a0af12343fb67841db25eac8ed24b249fc2563b219ea03b1731bc87f7625));
        vk.beta = Pairing.G2Point([uint256(0x18fc7d25f8679d46275d716ffffbb2cdf9e413a2c1166247d20da5e81c51d1b0), uint256(0x07ed7dd4c20b8228b71a4a0ec6587bea5dd18316868df4bded19bd4f9b662924)], [uint256(0x265ebd0afcaf608f0718e09af1e0ba939b52927ee95a00131fad0f990de73075), uint256(0x2549987139a646145dfe4754b30dc65f13a31885932d2133c945e411894c436e)]);
        vk.gamma = Pairing.G2Point([uint256(0x245b06fc26af6422e993f878332249d2dc3bf7ecb566be587113cd2a13eed664), uint256(0x0b4e270ce4f488756e5b358367a2b580d0458c227732b1a32f67ed058430fde8)], [uint256(0x185477f000b6a24fc74a72ed3198f4c67163f8fd0bd735b3053b57e6700a2194), uint256(0x1ec36b479efca1c43e46c4bdd2ed1aedad63efbae949df3efeb91196909642e0)]);
        vk.delta = Pairing.G2Point([uint256(0x0dc9e5fd8708d8c7ad48097957e208500a54b43a9558904b7707efe6f382e22b), uint256(0x2931bac9db54bcaf4b46f459a8b30d947f83c2674e169b7c4cdf5f7b52b2faba)], [uint256(0x275c88ed7d9b4d320c5ff08754b63210a8b1028185f12df7f04151567c0587f7), uint256(0x1268f0ba774b955d77c53cb473b87a4e89780e0b38aea08071da5c303df7487c)]);
        vk.gamma_abc = new Pairing.G1Point[](21);
        vk.gamma_abc[0] = Pairing.G1Point(uint256(0x273654e1fac75eb8bc4d9cf304fd2da7d5e66d244825666972788cdfba0235b2), uint256(0x22d8fc23d7895618f23027e20f446fb37a5f9b615fb2af573fd00645c38dabec));
        vk.gamma_abc[1] = Pairing.G1Point(uint256(0x23e46ab444629bfaef3684d49df96a14ba1e778b19f7be14cb2d66e7634f462d), uint256(0x2d004eb269cf7570902e92ee20693dd074b4145f262021ce4b8faf246fa7ac2a));
        vk.gamma_abc[2] = Pairing.G1Point(uint256(0x24d52a79fe5f2aad02ea0a0aabb15d936c40db751d9b938abe5f5a33efaac664), uint256(0x246b2eee8a820d7258de97a148b78220a5565d4973ebf70ee3879e02faaf3c2b));
        vk.gamma_abc[3] = Pairing.G1Point(uint256(0x2e573570cc6d57b4eaff6a4d8724f9f50bedf94ad702a50f008c7bdeea81f564), uint256(0x2eae38bdb91de68b99d9bd55cd4a01f46c7c94de47b00827266f44abaa6d3ebe));
        vk.gamma_abc[4] = Pairing.G1Point(uint256(0x18716e4efeee67183843ed1b9692fb3dcca035347e4d25a26e190a33521032a0), uint256(0x12592a1d7d279b60facb5531e50bbfa391efaa276b366aa45053bcb5e6d29fd6));
        vk.gamma_abc[5] = Pairing.G1Point(uint256(0x1222a2ac096dfb687d1da5b401b10534a0cf436c2100486f8cb2acae59fd4686), uint256(0x2b335bf10461b310282758b3fbaa9e392567eacc02b699ac1331cec905b1cc87));
        vk.gamma_abc[6] = Pairing.G1Point(uint256(0x1213307b6a21cbcb0c4df34890b7c8badfda95a5513efa6149b86cf00d3bf636), uint256(0x1156136301655fbc2d2606b6af2aebe725d63e2f4a40a21af52d5035dc85c03e));
        vk.gamma_abc[7] = Pairing.G1Point(uint256(0x27d2826e0c7279a269c7a038bf38f9d25b0b80358d0b873e2b71e80e62eb639b), uint256(0x1b04a0dd79db52d08460a1724b093aed97c449abf6efdd6ee175a1b1463d4615));
        vk.gamma_abc[8] = Pairing.G1Point(uint256(0x1d640d0480458942f2d0a3738cfdbfc5aef68b571b0539e43ff3900d3c4055e1), uint256(0x05e74b6b3c588fdf64622660c9ae3f24e9a06ca67857ab514fc92d74878d2ba0));
        vk.gamma_abc[9] = Pairing.G1Point(uint256(0x0da4e338462e3f76a7bc33a6a8fbeb96fed4e646aa424caf3cadd8542fd9b720), uint256(0x1bc178c1491ff42e56181b797ac6996af9da42ef19b3222a7c0f65fa5fa68a72));
        vk.gamma_abc[10] = Pairing.G1Point(uint256(0x0d0aa6979e4f1c14e709d7caf14a18e1215ce6c497209cbc29c52462fcd17e40), uint256(0x148ff9215de01d60c4a116c0ca223ff7f943cba9dba6d0b5984db178dc814aca));
        vk.gamma_abc[11] = Pairing.G1Point(uint256(0x055454f2579485153ddc00e7e255b0703522c5770d2eac85f5bdebc09cc9172c), uint256(0x2cd8cea8bed47c42d56dc2654c2014b8ba1b2f7eea13d0242e7903e50ed22b94));
        vk.gamma_abc[12] = Pairing.G1Point(uint256(0x0974438b2deb6ef91b7cf3f381e2801959022e9faffe28650708c72f4357ef87), uint256(0x2df8521a71c1297cb9e103b621d6214937fe8512aba7cf9c1188cd516e6fb8da));
        vk.gamma_abc[13] = Pairing.G1Point(uint256(0x1e7a9ca81bf1f6cd01d9341089fc41153c024f221b4f3f9e81b0a7cd57c48e5b), uint256(0x2edcb363093d21e2f4be2e1bc8fde92a2d235bd78464b8a65f6c9f9db7ddb05f));
        vk.gamma_abc[14] = Pairing.G1Point(uint256(0x0ba82c6fe2cccdf08621934e5909474f436dcc45cafd7cddeb168546a455305e), uint256(0x091b42afde4f696e61471eb542ea103697c3824162a7458d3bbbae0fc99065c7));
        vk.gamma_abc[15] = Pairing.G1Point(uint256(0x20ca774c62f262a0a6ec77c5dbf1db7b2c264e142deb3cf4c1d45f9f8a7d2b68), uint256(0x1b069b5bdbb8fa9fed4eab9729fd0d09a9c28dd934c92d10d9d47068935f6785));
        vk.gamma_abc[16] = Pairing.G1Point(uint256(0x1fb829068a9199c89a1342f0d1085311451d867acf97d986d2dc6ef3cabf5fdc), uint256(0x04d2c13874bbd7926dad8db3cd28eee17a06fff0e3358560dae43039b66ac58b));
        vk.gamma_abc[17] = Pairing.G1Point(uint256(0x2a8f7f5312049a9b0283366fe6ab0f26ef4c158f202f737e3d68823fb169296a), uint256(0x153055741d438b3c23c3a81e32c046983a2fc89d5d0b3512f40c8c6e8a8c0250));
        vk.gamma_abc[18] = Pairing.G1Point(uint256(0x2882f1134e9fb2aac66d66f6c51a74274eac5b9bb9eb39c6d729bf846be88eb6), uint256(0x241da7d7b83bb007db3df064de9bf1a9c75785fb38a0f64c5d5dd7f5004442f7));
        vk.gamma_abc[19] = Pairing.G1Point(uint256(0x024f3d475df29ad3fa119e4fa04558d7ac4aec7e7a9fb7310ce53a5803d981e7), uint256(0x300427431eabe458eb262cb36304e9860a573df4babede6266a96f9c898523f9));
        vk.gamma_abc[20] = Pairing.G1Point(uint256(0x25f87d0f5c37cf135dfadb264f928e2eb3e44d6e200dc4563cdc68964090c82f), uint256(0x1c4827d42e22588f154578d9dcbef1510cb8b3f35fb0af35c826e7607dc83ed0));
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
            Proof memory proof, uint[20] memory input
        ) public view returns (bool r) {
        uint[] memory inputValues = new uint[](20);
        
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
