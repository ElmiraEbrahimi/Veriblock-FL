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
        vk.alpha = Pairing.G1Point(uint256(0x269dae7cd9710dcfe3e7871f004eca6419727d2217931efecef2c069eba839eb), uint256(0x1a7447883504d2c78305f2f2c1598d21741be027be214b90b4706281ef78e11d));
        vk.beta = Pairing.G2Point([uint256(0x1de0941009c6e0808dbd5999da9dba7b2630ee6d1a511331ec2dbf568df34142), uint256(0x0f119e7f5ce7c42a45c94a4e6a8d3155a08357a93edc02318e4680994270cace)], [uint256(0x2f8e798bbac9cd4aba2e75539cd8eee44810d19009846609efb4d796c459a1e0), uint256(0x0f255f182b016bfd17433f17b3b850cdebf9479820cc65d1a341a8db26739e6c)]);
        vk.gamma = Pairing.G2Point([uint256(0x16b85bc3d0a053fc1714155dbca601420416e1a81d0eba6f09b52c1c50b3736b), uint256(0x01912c669e6e544e8648a4e6959e24d0d80a5526bbc3aaf0969f307ec96c5b6e)], [uint256(0x2667cebea48813c41b9b190016328afcbadaa3b34d291226d05a5252da2aea86), uint256(0x18409ee7277a8da38d5cf5c7cf71b5b5dd49b7ead1c90910416d6d95eba2884c)]);
        vk.delta = Pairing.G2Point([uint256(0x226bd30f8bc0c7120f0e65b5e681119b1f58573a3e462c727c900b4f53459c12), uint256(0x28812b3f16677831daea29bf68c28fc1306eb638dfd56308ae6566105a0a4d41)], [uint256(0x080382f2919664e5c2305ae488a71aef04175e79bedd4d943c9b597777677671), uint256(0x0c5547ba2a684cd6d3b44bd89e9ab08f5b4e5b348a376cab63cfc0c34067c6ea)]);
        vk.gamma_abc = new Pairing.G1Point[](184);
        vk.gamma_abc[0] = Pairing.G1Point(uint256(0x2da1780377c9308c636abaeb99e02a54913965839e08ae96e9f275e3355d186a), uint256(0x2b062cb623406330d663e9a08bafa7239787edb88fdc1149b74fca175f8bc08e));
        vk.gamma_abc[1] = Pairing.G1Point(uint256(0x047a03f5e11a138556568a3b381fedffca445c6b527db21ec631a04886f8ee71), uint256(0x151b4eff993ad62e0b6e049cff3860371d55f9909172f949ed1369a843f11b74));
        vk.gamma_abc[2] = Pairing.G1Point(uint256(0x056f2ba643a69b656b27b339080ed2bb27e93580b2e9205bf0c268d667fa7e3b), uint256(0x265e1c9bd67e2a764df0d527dd16626a1e4d408fca9bdd4da9737bc3e98545f9));
        vk.gamma_abc[3] = Pairing.G1Point(uint256(0x2322a5032a497498e3ac8b9f2ad3cf6a844ef8f2f61742a6369a52bdd06ca4ee), uint256(0x20b70ca6feee79d026a564e646a7bfd4d924035a9100abfca8036c7383c864e1));
        vk.gamma_abc[4] = Pairing.G1Point(uint256(0x02b1e472adcebe58a047dfd055f5301b10931e628575212aebd0dbff06694255), uint256(0x10b618f8d3e67af325da54689af4c82bbc514afc29930fd743fe1d04ec3dfef7));
        vk.gamma_abc[5] = Pairing.G1Point(uint256(0x0d16f587d04e35da6a5c257244fb514f076b39ed6a37579bdf9ed32ca8a3403c), uint256(0x228f1ea91ac52a63d1c189f59823e9db57280af227c1bc6ee458e9cb7a11ce5f));
        vk.gamma_abc[6] = Pairing.G1Point(uint256(0x2e68e46126750abd1503a330423ac5401a2296949e2560f96d02d986413fd295), uint256(0x288d72776a0e4dd5a809663da7660aaf6a5bfe1e0147f08af4fb31e07cad8288));
        vk.gamma_abc[7] = Pairing.G1Point(uint256(0x0e9d7aeb0a64e1202df7404894e40585e9bc5e2ea22bcd93fe46306cb5231240), uint256(0x0d399b56a339da8783d228501c6dfb6f31f97fe0b6644838285ac8058247ec87));
        vk.gamma_abc[8] = Pairing.G1Point(uint256(0x234cbb1ed5b3a94a26b301b9b5121c59f44d10e2d15edf44a82db1cd7eb3085c), uint256(0x1c83de1cf74d32cb87c1b16fd1ffed6e592332d1ca0866df2ac03bdfde3860d7));
        vk.gamma_abc[9] = Pairing.G1Point(uint256(0x184b989d8c7d73777dcd49286a4126508fa9991430bb7db04eb4d92fc228aa0e), uint256(0x270cfa2366cc2149016eb2026a507b8af75e84b173e7ae54914c09bb6f20afd5));
        vk.gamma_abc[10] = Pairing.G1Point(uint256(0x039c813a1725b0af518f03c4dc93d97d5fd6b8ef6f819492bbb1253aa89c82e3), uint256(0x267aa273bcb1668d7634441bc5420e66d6e138c0c72692c14a91ee3e6a9987c1));
        vk.gamma_abc[11] = Pairing.G1Point(uint256(0x1c6746f14c7a4c356d7d2bed8441768145e54d50d4615d52ccaaa867c9707aff), uint256(0x0abe25f97908cbaaa0c610f84e736101a68bd0cc46833f535d51090cc7b21e7e));
        vk.gamma_abc[12] = Pairing.G1Point(uint256(0x01414ed79af2e8e579a1dd909890f4f07e34e9a5b7d7428f1e64a11a99bd0a34), uint256(0x16dd57c25d836f57d5e100b90583815b940142b8cf7bba482f766201907a5f44));
        vk.gamma_abc[13] = Pairing.G1Point(uint256(0x2a75cc9ac25dc7c105db0e047a045381f37898125cf6a30f097441cf76084543), uint256(0x0db1ed84b68caba63303713b1e5a14bb0ac47bfe16f815763d82c120ee34278c));
        vk.gamma_abc[14] = Pairing.G1Point(uint256(0x0e9b46027622c3aa350bab545cabbe8cb1121cf71950d351e7e1b567f0355c07), uint256(0x0c3a02533454c6381df700877194baff6fe1b992023472fbfff744e008066d53));
        vk.gamma_abc[15] = Pairing.G1Point(uint256(0x26f535e218cf075d9140a7695a60a839073f1da40bc89e7e9332e86dbfb04d60), uint256(0x25e0e6333d7bab798b68ca6b2a98574136178ca8c5adb0ddf00a258b08b8f527));
        vk.gamma_abc[16] = Pairing.G1Point(uint256(0x09d05cd43a6f0a0ac350f2b02c89b2ec669a3d56a7bb26a39891ffbab9b0fd50), uint256(0x19ceeb48f843bce4e38cd69e07ccb4369d18d31e5752748e4df970638b00c707));
        vk.gamma_abc[17] = Pairing.G1Point(uint256(0x076277f88141a1c7a26e239e1b61b2196904762d5f7acf1472c2837cb2443054), uint256(0x1570a6b3267cccef5a10d126831ca9d5a19ece5a5344441648bf953c3a8ce2f4));
        vk.gamma_abc[18] = Pairing.G1Point(uint256(0x22ecf3631ff2dbb245c61451d357aa1696448245ed50df96a57b5ea7f89c2b3e), uint256(0x18f754ecad55c6174415072187d3d629e5d617966d6144e9a1883f7adf620f9b));
        vk.gamma_abc[19] = Pairing.G1Point(uint256(0x28ea0c888f3b5f3961c6f12d20037e21502c083b00fcfb95fd59199690c0a392), uint256(0x06e9afa105b909ef85d96de939eba051b7e32d6305481518380969bcb037f9cf));
        vk.gamma_abc[20] = Pairing.G1Point(uint256(0x30569dd422d84f875e1930f4b8371ec222a05ec030665bfe81f240c644b6359e), uint256(0x060ff1bf1f3b0a08c0872513d4649d5b58e2000d8c511885124516bbb1332bba));
        vk.gamma_abc[21] = Pairing.G1Point(uint256(0x1afa65645dd8e36d38baef8cdd5798007b63ca10e4fccb5662a1c5ea37fdc7c2), uint256(0x22eaa4f2b85940c61d9a3c2532a675ad9b777e7ca2dc10ca8b852ffcbc59804b));
        vk.gamma_abc[22] = Pairing.G1Point(uint256(0x19b25c47ad8cf49b103ecc41fe9fac5c40af7f0a172ba24185ad0fd412ea5b01), uint256(0x184ddc09b9cb0bbfd0794b7115b86f0ac548d9d7637c00d4d7696ad95f77a9a8));
        vk.gamma_abc[23] = Pairing.G1Point(uint256(0x17acafc383abc7f7ae6cc80d38f1c33cda67d338387ca9a078dd64f97cf5b090), uint256(0x0a5a3dcc4f63d6cb099e26543dd4e5f41eff53595a3b8d6201d3998d172f673e));
        vk.gamma_abc[24] = Pairing.G1Point(uint256(0x0d43266425bae798fcbd8bfcdd8d4681ca2fc47b81e28a42dfa065f38413f41b), uint256(0x23c63384742fab69cd4068478f77c00a5b69609a170d94ac6b605eb2a2f50960));
        vk.gamma_abc[25] = Pairing.G1Point(uint256(0x19a5a3cc6961a5de36d4a6d6064d087fe72d922294bb32e43a084a89830947a1), uint256(0x1ada896aa30cf87d41c7efefa9c8862ba1f790ff40aa86df41a5f6f9b38d5fbd));
        vk.gamma_abc[26] = Pairing.G1Point(uint256(0x198acca6f274cd2278c49f4aa10962a4bd2bcd265aeb80fbc03fc2306cd8088a), uint256(0x0b72a9a0430c8778a7ddaf5fb8af89c1e60863b8979e0e235734cd8ede39f9c2));
        vk.gamma_abc[27] = Pairing.G1Point(uint256(0x2879a76fff02ee7fbc95a891aa97768984d5434ab2f7c9c361a7e06ebcbb0ed3), uint256(0x1af7e1698df42ca6b7176295e94a0ef6b3f6671f94bae85291010bd38f2b09e5));
        vk.gamma_abc[28] = Pairing.G1Point(uint256(0x075a2190bb0fffe49799c30eddd0107293fc1cb25f4ecc1c62373c9b30a66588), uint256(0x0e9b00aec7aca4e4cd17db3590eed731045cb0abfee85735113984a2934d2f98));
        vk.gamma_abc[29] = Pairing.G1Point(uint256(0x21b7426c3f52afadac1aa7b9446401eeeddf1f89352f7bd7f8c4b4c66e2497dd), uint256(0x0963d5f372bd5684ff73350f27b84a35446b0fd3020cb7d8c34728720231a7ca));
        vk.gamma_abc[30] = Pairing.G1Point(uint256(0x0947d369a575a9995934b64d4c58b75ddd09480867772ddbc452c67de74b2a5e), uint256(0x2ff35d88f6aa3ca962c783ac96b96d168c451ca38909ea2f7dd20404b57b4a2d));
        vk.gamma_abc[31] = Pairing.G1Point(uint256(0x19f2359b5de5433aa0113f045218e3d9354493a42b4ef8d1ad7365858aa7bf72), uint256(0x1bf0d49ca6e88e90d6c3fa724c50d0592531c0868b8ee6d7b4344676b0851a0e));
        vk.gamma_abc[32] = Pairing.G1Point(uint256(0x2bdb5c1d5a5237c46ee4cdcaeb4b95d19418ad6e6743db886b967c3693e75be7), uint256(0x2298282a748b681fc67226a1db9c0cebd9911afc5db54652433d35849a04564a));
        vk.gamma_abc[33] = Pairing.G1Point(uint256(0x0f592d5b39415a69fb4367acd88ddbe7e50e5dc33a4f44468e2a42b08f83102c), uint256(0x080072ee3d762d7d7db328f467f97f6082618dd21fd140d83e346ce288bab97a));
        vk.gamma_abc[34] = Pairing.G1Point(uint256(0x086a0577f714a18116d72b850e27a776311e1bcbd5108d88dde3049b608e0f7e), uint256(0x11b4fe16ff55e5ec75cd9475cd2412444b3a341dd6d5c236823731feb139525d));
        vk.gamma_abc[35] = Pairing.G1Point(uint256(0x2c2f06c395dcdbb68ae8cdf831813c7176c3cf0fef505836e85af3b499d1ae0a), uint256(0x1b15b7b6cc46349193ea40d603e87565754bd9260b75f38d6784d5b911df9c03));
        vk.gamma_abc[36] = Pairing.G1Point(uint256(0x0ba803fcc569d7945659b55a1ab40b4311663914aeb0f2dcaa61a101e83bf47c), uint256(0x2a60fb7bacd2546c860689d4867dd7ea531fc935d7ee7a5db9fceb9afd86a398));
        vk.gamma_abc[37] = Pairing.G1Point(uint256(0x0ac1e4d2a1c5cc4a3f12349c0d31e68e8125e0d3286348e62cdafa1e91dc99c2), uint256(0x2a033e1b165761b3c1c9f800e658ef6a0da48f90f4c3f13e57ee2c1e81761aee));
        vk.gamma_abc[38] = Pairing.G1Point(uint256(0x130b946f2fe059bbce02edc44bf603b85acab13cf9b829738dea2d9059c23c33), uint256(0x070779619513495af2d8144ba9e11436fa45ef749b020989b151110d40bce4b3));
        vk.gamma_abc[39] = Pairing.G1Point(uint256(0x2dc2ab0332e1bdc3e7237eb5587fa2b130645ee95fcf61d84dcd3fbaa5dc8301), uint256(0x248140a904626160574d89e6729c6d0c28fad196fd08c5ef79737f5ed7008c84));
        vk.gamma_abc[40] = Pairing.G1Point(uint256(0x03c0099205449806a125171abffbee87b7244240ed22a46cf27a538c49e03f19), uint256(0x21aa2df4ea170c87a958178d740b303cc08c70c76180783a7a0bfe9122984e9c));
        vk.gamma_abc[41] = Pairing.G1Point(uint256(0x266bd802c0aee75517c9601bff72bbb0ff56fb8e6e198885a26d8cc4279ffa61), uint256(0x0817bff40aaafbddb0fa7ebc8234383f688cb4f0b76517440ea16ea0f84ef2ff));
        vk.gamma_abc[42] = Pairing.G1Point(uint256(0x0231c90db12428b35e8aaba97577b84bf2ddba6b211bc7ea4359da169ae84d7a), uint256(0x1be6577176917b5d0c38a6ef750c1bdf2f9f7375abeea89e6f80b01f0120a190));
        vk.gamma_abc[43] = Pairing.G1Point(uint256(0x09373004ec471dca96ee6c9e8e9d125861f72eeb6cfaed25b4c9e7ea5f3d676b), uint256(0x03cfcc7c54d0a885056206b617a1e190c9c59a3193db4e5efe846a019a941af5));
        vk.gamma_abc[44] = Pairing.G1Point(uint256(0x1e58ed52aa59b423ab12f890bcf363764be4cb1131267b959b0800489fcbf51f), uint256(0x01140aa8feaac528de7a635a73cb0055ccd94dcd0ebb4fa9ed51e2a5bc248aa3));
        vk.gamma_abc[45] = Pairing.G1Point(uint256(0x00d53d654683b6ff63313f626c4a184e9a61e5e6aed17a04382da60ef4610e01), uint256(0x244a3a4e8d9dd218e44f24d06123b4cc08761fe3dac709bc2f42a1505acbaea0));
        vk.gamma_abc[46] = Pairing.G1Point(uint256(0x200c389f9e4b03d4dc349d0bd0643f596f1f246fb94fca6cad7a80c807892ea7), uint256(0x0e49699af07062b38750a8ba7633e58c9b19c15b8e70b4e0668335df4722c71f));
        vk.gamma_abc[47] = Pairing.G1Point(uint256(0x27a4522ac0d1eada24f5bf1b6921c78126728bc792acc77eb074be8957b18c0b), uint256(0x0c8a1da8678e71995eb94903b49a3c936633a121936e250a6a0435cd38cc9849));
        vk.gamma_abc[48] = Pairing.G1Point(uint256(0x1a0189defb12505b05406bf02351609cf9bde56e42431847a4ed4949173a997d), uint256(0x0fb2a4bcd47a2cc5354d44679efd5fcd0429f0274a761fed9d109615575d33f6));
        vk.gamma_abc[49] = Pairing.G1Point(uint256(0x02e162aec2a782bd8e5a6e9e7d8638b5d38715c66d55c28aa753ad88524db7bb), uint256(0x079f124277f9df5d2097e17e1ea41cdd1884183923b7fd1741f4b0ae2e4074ae));
        vk.gamma_abc[50] = Pairing.G1Point(uint256(0x25e0c84bbb99d302b7ac7d03ef8699f239cfedf714bf1bd1c13ef5cbfb959f6b), uint256(0x17852f3546c91cfd9c57a613b51e522dd6c00cf06602e44776a8672f1c8f8fbe));
        vk.gamma_abc[51] = Pairing.G1Point(uint256(0x2fcb17d141181ec73499cc26d206875cfd34f493d3b26a2bc561627ec21209d1), uint256(0x1ca6c2f83d59fd1211ae56570d67602f8f1c893389a7e8214f0dac19262a97c8));
        vk.gamma_abc[52] = Pairing.G1Point(uint256(0x22b5df52cfc4b8e693bc18a1057aa313cd09c87b2e1140cfb4be186c3845544e), uint256(0x130c6298bbdad61b59f70b55db2390cc8a3a15f0477a53111438ae0eb73e646a));
        vk.gamma_abc[53] = Pairing.G1Point(uint256(0x296942fb43e2154dc02b8f202ff9a7ce683d4b8fd20513d6cbb9ddf9b9966a99), uint256(0x20a6d46331de81bc04cac79303fbcd718e93a017e9f28f10aa032ce9b2f0f446));
        vk.gamma_abc[54] = Pairing.G1Point(uint256(0x2a8394a3882f4e8a4ba18aa649322f629c4edbafe6e644c9d95e1e80282fa178), uint256(0x24da74b4e8a59bdac6db851e00f6689693261c86ee970f539b9583d7d1621d4d));
        vk.gamma_abc[55] = Pairing.G1Point(uint256(0x2e8e8e6dad8e83dfca7190fd92cc6cb457f1546700adf7db5d67f47e0597b830), uint256(0x03cde6f8bbb9dd02c5966fc024b06b3e8e34a2a497601bfa169354b73c4131a5));
        vk.gamma_abc[56] = Pairing.G1Point(uint256(0x0160c7cd58cdc2611dc2768b395aa85c9b5490349291071234d613b10d6955c1), uint256(0x2b246f8bef56df2fa76c38eb2386ba3a6166274a8178072c6cac3af2e9b1d76f));
        vk.gamma_abc[57] = Pairing.G1Point(uint256(0x06dfc33c9210a1862ab69bb77dece263a15822670a9f07e132784bd53b603f31), uint256(0x241eff97367e21e6fbfa5485d57dda0232106cf63cd5aedc849de26ab1602b97));
        vk.gamma_abc[58] = Pairing.G1Point(uint256(0x22ec02c1d0f5d06eaf6b95edec8199fb1ad158ef31e3cf9d380be5925a0f0a74), uint256(0x2a9d5df7c805ccdf5d04dae09f66af296dacd958acc167dfa1571cf7fb00d9ac));
        vk.gamma_abc[59] = Pairing.G1Point(uint256(0x2cd8040f861d0275c399a3a02193beff875287d5323b9ce490f1e350b9da2c6b), uint256(0x1a94a5c3a6053443f88ee3e98c090cbabc28695e6cc9d08311efe2087a6ea777));
        vk.gamma_abc[60] = Pairing.G1Point(uint256(0x03654a5c8951a80ae5d261295a2bbffa572d969e6dc6b5ff3120152266f0afa7), uint256(0x0fe3e1aff3e922db5e673f2abcda98b0dbe8630db0d20c612217ba7c99d5f849));
        vk.gamma_abc[61] = Pairing.G1Point(uint256(0x00282eb1426c09a95537b486acea909ebbff80c04cccb143d8691132224a5459), uint256(0x0baded6d98dc3bcd70c457342f1d1d19be46aa909644313b010bd8616431a155));
        vk.gamma_abc[62] = Pairing.G1Point(uint256(0x09109b978ab6af4bbee6d2ed2f6b3dcfb45d53f20d6650215fcd6036805ac5c3), uint256(0x074e40391ddb609661d10495f6b75fd78bbe3ac1d25d191106ec0a9b9c443b6d));
        vk.gamma_abc[63] = Pairing.G1Point(uint256(0x00ddf4972aa5025525cac6afddd8b401481a5e5a54a161366c7b264690e7448a), uint256(0x08c97f6a75831b9dec43ff39c551c8052887dad2202b690d33d5f60ef91220db));
        vk.gamma_abc[64] = Pairing.G1Point(uint256(0x06285a47ac795c34c70d1d9fd7c341d123cdb39c7d546872be1af5b5ce997f2e), uint256(0x074cab36d003a65f795776bcba32b345f57cfdcfee6fb56b593453d4870e4cab));
        vk.gamma_abc[65] = Pairing.G1Point(uint256(0x0424d2d38376bbbbdaa12b28cc42a4f05ac39685e541df139c16fa5d80be57ec), uint256(0x2f71141baa47eb2ec4cff8face1dac9862ad9b9629bb1551641ff617de02dece));
        vk.gamma_abc[66] = Pairing.G1Point(uint256(0x11f51cfa25ee2b6eb1bc7e5e48c7f8d2c0221051da75ce6fce6bc5cfc70f03ec), uint256(0x138116e0b905f35a29aa0e50d2987c2282010b4bb0deaea24ef05c4a3e17b52b));
        vk.gamma_abc[67] = Pairing.G1Point(uint256(0x2fdadf7a5940f15d5ae2529d7ddfb011624cb9750505efe9575b59f1db926c89), uint256(0x0e442398b3b31851bec34ddb589455866369d526e4f34129210c8387992e3b33));
        vk.gamma_abc[68] = Pairing.G1Point(uint256(0x1fbb7e828131859afb231705de418d501a39754378f97e30f4b5cc6a9a696c8d), uint256(0x26eea77888cac5ace21d0aa98d7906733d6885d534513a5514ccd314d3d95ee8));
        vk.gamma_abc[69] = Pairing.G1Point(uint256(0x2f4d82b0484a99bb4d71ec56343a3131a292197a4a7e527fa6d2a5d98af4b98d), uint256(0x068fa0a110f6aae1ff81f9f349bcd1d40a3ed871484aec83d1a73f8c8d1c7897));
        vk.gamma_abc[70] = Pairing.G1Point(uint256(0x11ad2b1cc35107d4e0db3ba80bc9c125c84d75f1fd29bc82f92bb71f7e43127c), uint256(0x0c95c971dc14f0b68a6010121e76754a71aeb1111fc844e191ff4b90b8b559d1));
        vk.gamma_abc[71] = Pairing.G1Point(uint256(0x2247ffc21752e4d003c8fdf0b095e261c36c08c8429cd2a45de46c2686906827), uint256(0x290171ecc944c51ce49cd31a0554ce5c76a109b2d2a97d89dd4e2656e7958992));
        vk.gamma_abc[72] = Pairing.G1Point(uint256(0x217c93c02d8945e8c3984aad791a6fa03e5ea1fe6554857b9a852f1728157c71), uint256(0x1bf4587ba91defe3bccc32bab8710350a1291c7e4dc563bb427eedfdb2ed8071));
        vk.gamma_abc[73] = Pairing.G1Point(uint256(0x21ed05f72be5c90e85f8953d87ed7f0a8749b10e9b34e0f0e3cd265a7ef00f17), uint256(0x2af012a9597d4df59cf849bbd6ff2c663c7c8552ff991e041eebf6709f1a866f));
        vk.gamma_abc[74] = Pairing.G1Point(uint256(0x059b238061964e14eaf4e858ae92bfdf747a7d6b9231c27376676deb0898b62c), uint256(0x26a61359335f4179daedfb0589e1559f533b7e237537fc74aff21a28eb0ca237));
        vk.gamma_abc[75] = Pairing.G1Point(uint256(0x247fc1bdf10226b647356c55b31ae3927e3e5e114c30a217bc4b453674ad52e9), uint256(0x050e0f99b1c25c0f8b00afe6e54428ff3130175707a00de9d357de051b312221));
        vk.gamma_abc[76] = Pairing.G1Point(uint256(0x1736e752c1e26c1b296f03568dcbe3b3959d4b2b76ace734df18047757dc5d66), uint256(0x166e3b5e6457b664fafd52a38750cab506e26d0508c81375870e551849f31403));
        vk.gamma_abc[77] = Pairing.G1Point(uint256(0x2d598e529a8911eeca0c77889464a4c77ee19581aa3d3f8583d7d0a660967967), uint256(0x008f60a0f825997287320592f8b6857fac818120cbb1bfe506f7805a36524da5));
        vk.gamma_abc[78] = Pairing.G1Point(uint256(0x06e220eb96ae1748d6e78d32d3b6bb425ff357412950dd4879b226f73c91b991), uint256(0x2be72aa5d5104c0d963bc55e5eda66371c737954d88a7d7033c93b90c0b28f99));
        vk.gamma_abc[79] = Pairing.G1Point(uint256(0x301c33bbaeabfff18f75118227a908d3fbcf8f34e360d1546a6e91f5417a31bd), uint256(0x1a3e15fdaee4aa6b3660ba9b061fa3df9b44d4a0736155f3bf453b79a9dd3561));
        vk.gamma_abc[80] = Pairing.G1Point(uint256(0x19e43492851c50f946c52230c17f80e1702270cc8bb707e7f2bc2504fb9df633), uint256(0x0493d0767d1d39ed6e425ed4afa769a7c6df1362b59838281f0f403a42418ce0));
        vk.gamma_abc[81] = Pairing.G1Point(uint256(0x24f83847b55b8872ca3661d1c8478447824f9497254b6ae9baf42b5de0c3b1b3), uint256(0x0fd2bb8b4fa9b4af7c4ed518900e670492a00d636c49980642c10fc587d12636));
        vk.gamma_abc[82] = Pairing.G1Point(uint256(0x0de766ec6f29dcd11c892a3b5f22daebf81cbba687225c29b5a6c5742ca939d0), uint256(0x11fef4aeb637a311ea3ebf62fad2b646bda49146a256e07c15fd3265279a89e5));
        vk.gamma_abc[83] = Pairing.G1Point(uint256(0x1ac0219a6980f21c2cd0df63b5f10b7fd8d2127e950ad5910c44ab1d8ade7042), uint256(0x0ea216007b8f77bec4c1224cacf1542f8cabf5d3d7bfcd4560d739bbe232d656));
        vk.gamma_abc[84] = Pairing.G1Point(uint256(0x0286afa02b47aea638b2ac763eda4c70b576d87bc7dd0945f7e27c0619cfd975), uint256(0x157b87a20797db94fb423794114abd70025ce1bc6cee721d25298c443fbcc76d));
        vk.gamma_abc[85] = Pairing.G1Point(uint256(0x2307d54379cc595c15a2240f8fedcf5dcb7058491ff46de8dca632d0ffef6a9c), uint256(0x09264781d04a4b94dbe873a82395dc8f0b9af62a537c4fcb334b581b204fd7fb));
        vk.gamma_abc[86] = Pairing.G1Point(uint256(0x0268b45368b4b47ad52f02350cb1f2e11bd83364e658af996aa457cd288f7264), uint256(0x0913c3e312b722f712156611af038555ab00cc1eadd86653e079b9dfead67dc8));
        vk.gamma_abc[87] = Pairing.G1Point(uint256(0x04f2fc7ffd44f6d8cd856b654c8b724eb0bcde8e2d5a5b68c90e19e372b06af2), uint256(0x067a5ce8240686d1ce175350dbc7bb401699bd7cfced60e0e3b0e7b5f004b3a0));
        vk.gamma_abc[88] = Pairing.G1Point(uint256(0x098f284253569f70a65f3d02713a146a6e2eee14fb8461448c0d1d22392129b1), uint256(0x00414c1a3ad19d42a8b4ad3b7e7bf9bb59b1d9b9b442384cb920ec6b6747b99e));
        vk.gamma_abc[89] = Pairing.G1Point(uint256(0x26eeb1190caca9a545f705021ca722d7309848bee55f0c2623cdc7f6b81a3701), uint256(0x08acb8e03b24d7b52544daecdbb00859936d348f9dbe748204f1f8b21204e580));
        vk.gamma_abc[90] = Pairing.G1Point(uint256(0x2458c558ec5f9b8070a69eaa31053b76bd3c39413dd01185c316d3572477bd26), uint256(0x1136f44bfcc17d36d48c21fd9b5c3974a70d62cc24ea6cbd433c4553c1de8868));
        vk.gamma_abc[91] = Pairing.G1Point(uint256(0x1da0bfa7ad6ffbcf4c86c602c6fce79fda6427d805bde1c72f3f6334064a5b50), uint256(0x18eda12c9f0e8a95a1185ea06462606c587800b2e92ccdebe3f51b68897f72d3));
        vk.gamma_abc[92] = Pairing.G1Point(uint256(0x04247f7f7f4c5702e2f1b3ce43bf41bab298f58620900bba27f78acdb5611e8c), uint256(0x2c89f06c39924a04e2eb458030ad04ca0542f7dcabc5e7084bdac4bbb92e78a2));
        vk.gamma_abc[93] = Pairing.G1Point(uint256(0x234a460c0d01e71d5ad201de8f1015d4c9089045c53f5a53218d20fd1ee13a64), uint256(0x2487d9051c0fc5cbaf79d48b687610e1fa27e395d6134d03bd872222acfefe38));
        vk.gamma_abc[94] = Pairing.G1Point(uint256(0x0f1cff0508ca0f134848a7e1c568ae1158eb71938dc13d8ed81912d1c36db9b2), uint256(0x0d61216736a94879ac9cc37c72db64eed9e3dac1d50b651091ceac2115ca3e3e));
        vk.gamma_abc[95] = Pairing.G1Point(uint256(0x18fb508fc8be9c912a9be71a91f40447ac29ea4a3c0199732a8e9f3b2ef8e857), uint256(0x302d880ed39b39ddc37a64c21cc69d9fc8caf0c1392c7265c15de72c3f5fa845));
        vk.gamma_abc[96] = Pairing.G1Point(uint256(0x174fb2aa88e33f6fed8da82d0eeada1bdc4af3a4d72c846246168aedcbee698e), uint256(0x29141b6ab8e577c57a1b02b0caf6a4e51f7a3a7c991e90598c00afbdc2e0e084));
        vk.gamma_abc[97] = Pairing.G1Point(uint256(0x10b45cbe4546aa8a49237796adc1fc1beee57510e065602f6c0beb0ae5cf3999), uint256(0x132a5b01ddc16b3803cc4e7b9d188fe11a7d8ca4236f1c85db1c2fc4c12f51c6));
        vk.gamma_abc[98] = Pairing.G1Point(uint256(0x016ab8c7e281b667902b0e7b5ddde08a677670459b506d0c4b86a0f66b44a295), uint256(0x23da5f9b727cd4eee6e13db03b6eec5ebafd7b964ee9d0513488f6e7387b125b));
        vk.gamma_abc[99] = Pairing.G1Point(uint256(0x0e38db05c75f15ceae3b960e597a3d4ebdfc77b06532fa0cd3a5446c550a53dc), uint256(0x23aefb816e2b538f31c4c474e2f56900170a22c26ca4f28bef298af6d0a0e5c0));
        vk.gamma_abc[100] = Pairing.G1Point(uint256(0x105340bad4d3526f04693a3950d9b06168e02b90ea23676ed9955473f011cdc2), uint256(0x241763d8ba819cc2145f5cd16ec183e0591bc89439ee9e1eee57e0e481004514));
        vk.gamma_abc[101] = Pairing.G1Point(uint256(0x236ea52e3948a1925cd042ce3d94f70e43f61de4bcd08b77da8d267c502bfaae), uint256(0x2b9a480b89255ec2459450ef07bfa265ac2df25835634d869fbd90a64993e7f9));
        vk.gamma_abc[102] = Pairing.G1Point(uint256(0x234caa17c92ffa8b834089d2dae0e375aba8da9e48bc884ef510b09d79ab76d1), uint256(0x1c0b0782eeebd1ae8e73f0a3fcab4333a21db17969eb6531bce5f7ea2cd689d6));
        vk.gamma_abc[103] = Pairing.G1Point(uint256(0x2a188eef1c4e29c49e0ca8861d472449b62babcf6ce55a20c9ac45962af396c6), uint256(0x09d2d51d9df0a02020de06e936880ff0515a796dbd2923b31c5105e81a72a9cf));
        vk.gamma_abc[104] = Pairing.G1Point(uint256(0x0c193bb6d30c25cb9e9efb2d48706418365e8f09e4da40e4d37a8c14d286dfdb), uint256(0x2f3ab47562621a21de14a98e760ad2ad9ec9b7ae49106fe9b342c37febb149e7));
        vk.gamma_abc[105] = Pairing.G1Point(uint256(0x2642fb2e3c9b25346412241d0fe896a22a8e0d70932cb32f47fc5799f6db6e1f), uint256(0x12234b5f93952bac089c23b444afa8fdbfdfc8c0fa78f849fce2ca3d7ff7be74));
        vk.gamma_abc[106] = Pairing.G1Point(uint256(0x1242d8813f38e56f9c086c462c9f8be3b67b19e70927b7f7dbac5d4d797bbcf5), uint256(0x109bc897011b6d9e1dcd120136c217f9da7da44a4a3da317bb2da8c079e98de0));
        vk.gamma_abc[107] = Pairing.G1Point(uint256(0x0ee1cd09c60ea775838cfc3966eb76f1fbc73587ba91614b35874e51b0d12d06), uint256(0x262b998da1c86a3394f68ae1ff4f1847cbfc4481cca385840f399129c127b66d));
        vk.gamma_abc[108] = Pairing.G1Point(uint256(0x1fbcdc138647604f24b19dbb52b3357b5c77a880dd5e4901e41804d866aeb39f), uint256(0x135c98d15bcf81a993e5fb0f3f41a4f52d75b0c77e9428b2b5419244a76c9a21));
        vk.gamma_abc[109] = Pairing.G1Point(uint256(0x2d0305fed60782f33d792a4c9ab33ea7c88c07d31f87f575613ff1f463330f9f), uint256(0x0aa8796d853118233a49fd6644b21c7729c2bb4ee184f9675b17303cc5b785d7));
        vk.gamma_abc[110] = Pairing.G1Point(uint256(0x10f24eb68278d95df75b21d08373ed345ffd9ca219fc4364e07e013726a98d37), uint256(0x08dfda695cb7fdb07f0231a08a643dc03f9b259407beb7c83636aaee4bcd8e85));
        vk.gamma_abc[111] = Pairing.G1Point(uint256(0x20e136201d007f9c089e4d2a707e11a33ee8d695550fa30fcfc662b4a473b45e), uint256(0x01e14f95da9ae3256656df886e04f19f2a95457568c76f2c3866851deac4df37));
        vk.gamma_abc[112] = Pairing.G1Point(uint256(0x0175b716f451ac67a1f3ab53c248cc9e815760f30a66e57158463fc780432b6e), uint256(0x12048b66092a8cbfeec0b7a11c5d49a238c66602b6e38a00843aaccbeaaf31cd));
        vk.gamma_abc[113] = Pairing.G1Point(uint256(0x06e0716ad0c76eff48563e742fd684cd912a5b53adcd1bd133b8e8fc4cee1aec), uint256(0x162fb82a646d89d7a95d0cd01515eb818caabaad9f2071443fc787ad2bf8f694));
        vk.gamma_abc[114] = Pairing.G1Point(uint256(0x263d75660f88d6dd22400f171f0e9fcefe55e2c188849462052dbf3b80e9845a), uint256(0x046c9998b711d1f1affd45b098d2078fcf54a790dde67d45ed71a1762e7d88e7));
        vk.gamma_abc[115] = Pairing.G1Point(uint256(0x26d0a18d89e906edd698918a5e57660dc8c672909a4b23cd85d4e2129cad6088), uint256(0x0bb1374a049dd8767bf9259a9dc98c6912858ca754f6dabf05848cbd336bd31d));
        vk.gamma_abc[116] = Pairing.G1Point(uint256(0x2606e26d2c7752f0cf60cd1ac85314dbeceeb7e3a86d596fbb15fc10aba7c8f6), uint256(0x09339b10c8da7f3f7d797b1aed5e73df94db18759dc5bc72eab2218edc63b784));
        vk.gamma_abc[117] = Pairing.G1Point(uint256(0x056e205f3e4ce4bb7e1c6b2aab5bb3969bdf445e3816a9d8057cfbaf7c3487b0), uint256(0x0b5bce2dd18dec505db1a7def683701232610e11a8596e1f61bbeeb9b270229e));
        vk.gamma_abc[118] = Pairing.G1Point(uint256(0x0de97203e3b8b93a81549f4e74d4e8c6018363d5af3a127025e634e9ee7f7dac), uint256(0x0475f71bca6867f462675ae2674c6f6abe054513b96a2c21968c66f937fa2999));
        vk.gamma_abc[119] = Pairing.G1Point(uint256(0x24943521b10eeeb45d30b79d03113684009ef3f389080d183e8652eb8f8d7d4c), uint256(0x10f5ad3228091665c5ee8bc931f97bac9ac7aa578f9516179af47794ab906eba));
        vk.gamma_abc[120] = Pairing.G1Point(uint256(0x2b868ef6b9f8ddb5c57173d11fe9789e851a469b605e2aa4f3a3b262e2e0490f), uint256(0x0d4769607f402e6e65ab5e81644127e2ab5f2862337c2f9e86b6245e91b031c1));
        vk.gamma_abc[121] = Pairing.G1Point(uint256(0x2923a240695f6255d8ade171d93d3cb451b52a06439312303e5b4e62df642373), uint256(0x2b2beac136ac405f41615e3e48d2f950304a51de35c08c46864d9d6bd7e92871));
        vk.gamma_abc[122] = Pairing.G1Point(uint256(0x2e695f34c8c965caf06fcccdda2e889f1156593f1785408ae7014e99b542bf1a), uint256(0x2abbe351e7da4b75675067aef3707cea46faf00cae77925c49f9fa545cd51b1c));
        vk.gamma_abc[123] = Pairing.G1Point(uint256(0x213beadaa621d253b9de66af1d4068ded746ab7e12fe19771ef1f4249a029940), uint256(0x074ae6eba6d5e00f21756e3cf642655e3b49af134918adb249e77dc57017d396));
        vk.gamma_abc[124] = Pairing.G1Point(uint256(0x10d465ac2f411d4411420f7ea2788376cb9fba4d882b39e949d4a36da01b421b), uint256(0x25c5daa55fc0b2213dc87ce74af2cf5a7c0a8dfa03ca0e0a73150ec35d72595e));
        vk.gamma_abc[125] = Pairing.G1Point(uint256(0x093ac213c85a686b4033ddf9bc2b4ce9dff724515a3aa1518a741e1909e8e134), uint256(0x0a8890bbe6d9e9c6a0ca6560c13b68dfc9f6302690c8fa87de1be36295666799));
        vk.gamma_abc[126] = Pairing.G1Point(uint256(0x1f3f447910105618374f5df4a8b40962fd99e0262c2e1757f32266c878d0b5ef), uint256(0x2e15139969e0ee1be1873ab48cedf57ea3bfb608cb1497289d5d4611d57fe58d));
        vk.gamma_abc[127] = Pairing.G1Point(uint256(0x2e28bb214376f32eb25330200f62a702bf4fadb9816e46478f08fe0012e1596b), uint256(0x15ef42cd5c824433963bdd7233aba6b4c0b3c12817a6685e5826fbe80b49f394));
        vk.gamma_abc[128] = Pairing.G1Point(uint256(0x1746c6d350b3d4c1810d63395ef3a3e22c3118e6ba2fe2b4039d2e75ea03edf7), uint256(0x1ea8e47b0c0298813757f961aea7e96d546485bd58b459a0a75d3f0676636017));
        vk.gamma_abc[129] = Pairing.G1Point(uint256(0x0c45f9cdf48b1b592cb3dfa94609964cf6040ce3e30163f5dab29229749b12ea), uint256(0x12e38540601799dc5982699efecff95be6bce7e0d870db760d087381f0ca1173));
        vk.gamma_abc[130] = Pairing.G1Point(uint256(0x0c0916c129926b2d2abe39cf8d350ff171cf4aa6cee7ae382df56006023fc9e9), uint256(0x0f82aee2dfbf77601600d967239da5249e6363d6f08ca33b74682c50f5efcf82));
        vk.gamma_abc[131] = Pairing.G1Point(uint256(0x07dcd59f5752cf6aad27cdb40ec1e17914ca58ddc16ea9c37256f922f2d82d47), uint256(0x091d5c5c8a52f60ed199440dabdef2da0047f49022a226a0029c6fe7ab0a3c30));
        vk.gamma_abc[132] = Pairing.G1Point(uint256(0x1fca72a8c01ff0d3fb78eeaec0e0916869f5e30bfa9824c7cd6e93092657e2b6), uint256(0x1a4b1c96d670d0fc52d6535e41368cee21d12fb9ac6452dae747918802f9d17c));
        vk.gamma_abc[133] = Pairing.G1Point(uint256(0x1eedd61512738271176a92d88dcac59403b0c4c6f0a50e7beaa0497c3e0a17f2), uint256(0x1c2beba523ffa5690a6fa4a3b86dd9b5fe414e997c8060efe53e73c014c11a61));
        vk.gamma_abc[134] = Pairing.G1Point(uint256(0x149147b60075708298e04f29735fc031dbafb15c178f5401e34fd5d298f87dd2), uint256(0x08402e23fedd858e7d4a25026366033472da3427d098eaffbe5a88819bbfacd7));
        vk.gamma_abc[135] = Pairing.G1Point(uint256(0x175c82ad2cd93ab43b8901b2e6f0b6fd389f3b79bc40148066cb9e025b837a8e), uint256(0x26c38e9a505bf99003d8e075ab4025ce08e7b4af704d55bc62cc093719f2adf0));
        vk.gamma_abc[136] = Pairing.G1Point(uint256(0x2effafbe5b09811062f0b322be998fe8d022c70e2f48cfd7647b9ca585309610), uint256(0x1c892c820fe6d768fd2eba6aa113832342df16597ec97d0910e163f82db9d49d));
        vk.gamma_abc[137] = Pairing.G1Point(uint256(0x26fff42836169d537ef5a07ddcc09acd5bffe0d0dc6d04178f26de366d3236ee), uint256(0x20c257329bb1c4f97b835d09049ffbc080a6fc2fb0269f644ef90e12b95094f6));
        vk.gamma_abc[138] = Pairing.G1Point(uint256(0x2c0c8c063c3070a17790a29c9c791147fca3380f33bb7800eab302a87426acbc), uint256(0x00a36aa2e9ff07f80191b977f40a3499c3424aac681112f8d4173c9f7d629966));
        vk.gamma_abc[139] = Pairing.G1Point(uint256(0x26f24ae47de70b75aafd2a415d3b6e34b4e46759857669892e198771a0d8b057), uint256(0x2222f2243c5c24313a78a05d8a5794ea6d9e4b9269cf444ad45be96d42fa89a7));
        vk.gamma_abc[140] = Pairing.G1Point(uint256(0x3019f655f2cb17faca6f743d475e1baa431cdcd50b6717992b9ff1bb25b3be7c), uint256(0x28ee6e3ea9cd333c49b93156242b7e6f16ce834efeb50390e97e0c82f2c73db5));
        vk.gamma_abc[141] = Pairing.G1Point(uint256(0x25c660c895183b3d1b47e655669c0fad867fdbba8da1dfde5ab9be1d69ab8e47), uint256(0x1fca4087ad3343f2c3cab3ca17888b4b023243726510b39bb12ed136bfbf4c29));
        vk.gamma_abc[142] = Pairing.G1Point(uint256(0x27beeb9ae7f7049a68be56d50035e18d5dfffb6ab05d251cf383179008e889bb), uint256(0x1de9d0856f73cb2a6de6f5d01cf642ebc1a65032ba7d6a00ca5c7cc181506fb7));
        vk.gamma_abc[143] = Pairing.G1Point(uint256(0x0fee47e93b1c5eb70a1771824245ae3b94b93b7435981d477de2b1ca17fa06f0), uint256(0x2f570bd7c90cad663b973c329232c57f7dd9e19a2fe1477005ed9ff75291c4eb));
        vk.gamma_abc[144] = Pairing.G1Point(uint256(0x09ce4fd7e99213399ff8c52b5d8dbb5606ccf60d008b7a151f92c26cb5e0863c), uint256(0x1ca8578fb28ebc97883c979c5755fba0b3abd2fd9831d8cb744a42d6e9db4c7e));
        vk.gamma_abc[145] = Pairing.G1Point(uint256(0x1fba639328ce8ab8af944bbf68164db905a53ae92c39ac6b0cc07c10a6437931), uint256(0x269f65d779cb4e86724fb88ce9354855551e3bdf3f042cf85a80d8f89926e120));
        vk.gamma_abc[146] = Pairing.G1Point(uint256(0x2535ff9903a8692473656fd87311f1ebd9f75b25b8a8ea29565d6e77e2820c13), uint256(0x2abc5836fb9d7a481f859ba77211a00bb962e7f345d51abb379e0a040914ea4d));
        vk.gamma_abc[147] = Pairing.G1Point(uint256(0x2c4b2ab314973c09dd3d5d0848a1b27373e4510df45e991b90f8b530333ca3d6), uint256(0x1ab35516995a04f7b2738bf53b6ea4daa212bab267624c6a22cb579d54f3ce54));
        vk.gamma_abc[148] = Pairing.G1Point(uint256(0x2cb5ba8709f23c9eb35cb1e7549b505733a882cd5edf2bf5a78b748c0235090e), uint256(0x0a7a37e2d2858e6d493063b6642476b3492d2145d6a8bf0e8d5fc0ba89939dae));
        vk.gamma_abc[149] = Pairing.G1Point(uint256(0x2365e1d06692e1b0573cde740c8b6641a628bf3be2f4d8fb4a3c186ccbf96662), uint256(0x072df42174d50c666d0e97de3603508cada72809016b28fb6d738bceea3c8837));
        vk.gamma_abc[150] = Pairing.G1Point(uint256(0x11a178d58a50df2b876812a442f416601bdb4d2d6fcfad051fdfe3c17a06c38f), uint256(0x1fdc2f1eeaad4b5684d38a5d8435e7035c0abc93e417e063f32d14317470d8fe));
        vk.gamma_abc[151] = Pairing.G1Point(uint256(0x1d2a498e1241035398a2f63645d36a271f5a15923017b00e34f461edde6077cc), uint256(0x19c6883b626a579fd27dae8a7f5b0871d7b303a7f0e9eb1f15be0785866d4d42));
        vk.gamma_abc[152] = Pairing.G1Point(uint256(0x03829a968e1844e20ee95bd93e1d251aaaca51ef53a075b6ec21d23db8a9acb3), uint256(0x23097a9775ec4744a8d4d5581a568d994db09f5cad63047825c951b253a5abc0));
        vk.gamma_abc[153] = Pairing.G1Point(uint256(0x27c47762326a4f54e717790e69c249085ab0af2eb1f95524df47dc7cf9e620d3), uint256(0x274c24b1582efbec298b4c9b8c97234658d573ee4058db5a767d9f007d40c0aa));
        vk.gamma_abc[154] = Pairing.G1Point(uint256(0x2906e33eb2e87fd568362bf3d9e7871e5c32d722d8866154a2df6ba3bf748663), uint256(0x149b3ba7923fcf686bb57f2b7dbafcf707e47c85c7633dbdd321a4491d528bb3));
        vk.gamma_abc[155] = Pairing.G1Point(uint256(0x11d4198fcd5856dbdf87dc70dc0cdc613ee0beea5096d23d581a4097e7d5ccd4), uint256(0x0e848935d1f05bd0c26e3ab06fa90f91b3221a63d47fdf810020e920a54aa1e5));
        vk.gamma_abc[156] = Pairing.G1Point(uint256(0x0d9bba1206722dc04cf93d2b2f7dd769a970545fcc29a3e8d068ee1f90c6764a), uint256(0x12e0b76961d60b54b52d84236d8eda4e359e3407246d3ff740d59355807e0d20));
        vk.gamma_abc[157] = Pairing.G1Point(uint256(0x040b614ffbda9162d4958cdfeccd15b9effddda8bdc947c6f54be858b3f632be), uint256(0x0b21304e5ce4e951cb3e1dae0f94448f0d9a2260d71e170bd67921b24ede3f7c));
        vk.gamma_abc[158] = Pairing.G1Point(uint256(0x06f5258b65b368b41821b6ea47bcd7d56e20ac94928fdda81ecec1f5ba334398), uint256(0x1bfc4da7d0c1cb03819ff2bc4447aa60f4beedab99cbb15443eff93c6dc0685a));
        vk.gamma_abc[159] = Pairing.G1Point(uint256(0x15f619a04ffbf45137bcfdebcc94604c967e2e0b62e5832576d51413b607dd07), uint256(0x0d79f54ad058bcb12ab35026c32c46467ea172da8fb6fc8456e8f162773edaa3));
        vk.gamma_abc[160] = Pairing.G1Point(uint256(0x225ac4839bf84d7e091618bd60316973898420f6f2229f280cbef26359cb69d1), uint256(0x2ba60d69e358b707d565b06eeabdc1ebccddca368e16cf0081069d361d4c5a22));
        vk.gamma_abc[161] = Pairing.G1Point(uint256(0x09c7dd2c0bcc501b336dd720437f90e52391501e32a2064ba45efa703fb9a5ca), uint256(0x1bc7ee5dfc5ee4f6548cd87d25efcdcde6fb811be8de219e68c1cf7336666ca8));
        vk.gamma_abc[162] = Pairing.G1Point(uint256(0x086f5e3f60196276147d526a266a42f3f849eeb85b0ec01c69bb932a81c3243b), uint256(0x2b5855eb73e703a3a9cadd233e5fcabd0d7c43f1736023869a3e80caea2b85d3));
        vk.gamma_abc[163] = Pairing.G1Point(uint256(0x156f455b7d93c0221e614eb1e59d215944234df24e649dee305bb5ba04330270), uint256(0x0118ebb20a538ec45e33a0b9ad8c5bb9926e7d59c08a0c67a310f4b05c877d9a));
        vk.gamma_abc[164] = Pairing.G1Point(uint256(0x16de2ad76bac2e80aeba29cdb91616ecc26aeeb0ce40cfa1ce91cff06040de07), uint256(0x1bc698037326b4b733513c147a92c224d35f8f05c6c4d480833927bbc487257b));
        vk.gamma_abc[165] = Pairing.G1Point(uint256(0x0b8edab85e4c3bdb1ff4aac6ca6d73e798193a3d34391d6265f0cc7ef09ef1e8), uint256(0x19b069e0d9e88d7593af30ccd5f9a94b56c06a9157facdd79ea255ec32895a64));
        vk.gamma_abc[166] = Pairing.G1Point(uint256(0x161b05936935cac8fc3bcd025303631d13b2348d08664ca2cfd931bc1c209cf5), uint256(0x04de958a82a9f301b6ef7019fd740dd52670293243083651a5aefe3a752f4389));
        vk.gamma_abc[167] = Pairing.G1Point(uint256(0x0e7264f18f88b32baba570ab89b37a7c2240acc933c024109c141d82d6402f05), uint256(0x0d12f9c1597dd926417175ef6d33f1538f5eadfdf4af93e7177e1decd1d62f97));
        vk.gamma_abc[168] = Pairing.G1Point(uint256(0x2b03e8f048a51d5c2b9fb614618c5704d7d7b24b89722994d1da57631b28063f), uint256(0x07c6e914d7db525b27191060311fadbe904bcec8999e958dc26a098574694f39));
        vk.gamma_abc[169] = Pairing.G1Point(uint256(0x1df09500b02704fff1144f64f0277439b4a757a7e767fc0e9d0a9f853d186a5a), uint256(0x2e606c03ab40133e14a5c188391d4707490588cdccff930a96dcda4ba56d5e34));
        vk.gamma_abc[170] = Pairing.G1Point(uint256(0x19f588cf8b878c04d067940184cfc054a9767826dfad718ae7942dc1cbcc1849), uint256(0x091b9434ca94ce3a6fdd8749c6ec2df1d026a50e8503d9ce9b2c2d812bff612c));
        vk.gamma_abc[171] = Pairing.G1Point(uint256(0x2880ad658a1b3059b57f8ab07e17c3ca80513b3e84de04cea0ba58d8aebae163), uint256(0x16918be850e494fcfc0de5430d6b459c0c9186fc6bf31dc8907bbf3225f4cf77));
        vk.gamma_abc[172] = Pairing.G1Point(uint256(0x29557c2021ff149611c0778f3067f0f270b8b21f1dc729f31265093c5e5cba7d), uint256(0x169cbcf083d0679e8b0a4a060b3cea0dbf08791bf5f3bdccd0d4a0fef43f3d23));
        vk.gamma_abc[173] = Pairing.G1Point(uint256(0x27d972accb5374bb0eda0ab4911d1d66e03eb057b5eee2d92e90d64b13165994), uint256(0x11a84192d0a27582ebffca9fae3753e3f6c026c5fc1da1ab0b86cdaabfdef595));
        vk.gamma_abc[174] = Pairing.G1Point(uint256(0x02330b9bcc3fc8e42851867ae7e20b8d5e93f76ee1e90d24cfdcd6fd6e43d3a9), uint256(0x0bf5468fe068a49caa375fa765eef51b207640e04835b464cd14f66ce2939384));
        vk.gamma_abc[175] = Pairing.G1Point(uint256(0x303ca292278ccd04ca1606881a5c40ee778ed09f0b8f1011f2d1eb44247b9d08), uint256(0x1647f1bc79079ce806117ec631db7e6b470aa8ccedf63d5c1b1452dd40d2d24b));
        vk.gamma_abc[176] = Pairing.G1Point(uint256(0x2207dfa56662ca9a3c413f913c619cb18a9b86c7ee6f6aae343de36276122ac5), uint256(0x236875c3c26bfee2ade3f474ec5ade22c8c1da7a3297057929191b49303ea1d9));
        vk.gamma_abc[177] = Pairing.G1Point(uint256(0x108dffb433840de239240b22315b2764fbfa4c2586256f71b478171c58c8fe70), uint256(0x235da3443ebf0425d5bfdc0c6d62784b9a01836b4db47135c8d242618eb44cec));
        vk.gamma_abc[178] = Pairing.G1Point(uint256(0x2c43f00829cd479165f3d48751db0faf3d37e92ac3604358b9341a4bdb81ed50), uint256(0x07d3f194a246cc691ce958c65dead92087cfabf9b4d297fb2e439e354f636216));
        vk.gamma_abc[179] = Pairing.G1Point(uint256(0x0d2ff26e73029d7871337c7701289835279d952afed7d96476e3e5511a188068), uint256(0x17ceee8571523d59c5b3858b7bc3f3c17402e699030ac483db1a8579e5b1a323));
        vk.gamma_abc[180] = Pairing.G1Point(uint256(0x28a00fdc06232d7af88724fd33a5453b847e52ec2f906ea3d35212f0a80a76ad), uint256(0x1cef15663d7ea6b277cf4f10dc1a2bcf3311f752c859e4622b1a18ee072bb77d));
        vk.gamma_abc[181] = Pairing.G1Point(uint256(0x08e922cf34d2ebd5bc2bfe8c1d225d9f85ed4218130b9a0bd30436aa7c4376ef), uint256(0x012e546bb87f477bc11aca878e4645b2a17827152e1e3488c49cc53c36c84164));
        vk.gamma_abc[182] = Pairing.G1Point(uint256(0x1846169e07d9590c21dfdbaf81de923fe4e2856123f7727ec925753938da7da7), uint256(0x2ac0c5f0ac009a4cca3023f6d4aa08c9062975788bec970a3149223eb02d7ca3));
        vk.gamma_abc[183] = Pairing.G1Point(uint256(0x13271f2fe813263ff38c3ab450079347bed1b24edd3726fb8db919e06302ad86), uint256(0x070b2e557f42db440c1685a8bfb40f25a450f03e28c9eeb776d363903b1e1ac4));
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
            Proof memory proof, uint[183] memory input
        ) public view returns (bool r) {
        uint[] memory inputValues = new uint[](183);
        
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
