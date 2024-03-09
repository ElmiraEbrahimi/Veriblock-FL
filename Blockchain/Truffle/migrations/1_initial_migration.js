const Migrations = artifacts.require("Migrations");
const FederatedModel = artifacts.require("FederatedModel")
const verifier = artifacts.require("Verifier")
const verifier_aggregator = artifacts.require("VerifierAggregator")
const fs = require('fs');
const yaml = require('js-yaml');

module.exports = function (deployer) {
  let fileContents = fs.readFileSync('../../CONFIG.yaml', 'utf8');
  
 //let fileContents = fs.readFileSync('/D:/Advancing-Blockchain-Based-Federated-Learning-Through-Verifiable-Off-Chain-Computations/CONFIG.yaml', 'utf8');
 //const fs = require('fs');
 //const configPath = 'D:\\Advancing-Blockchain-Based-Federated-Learning-Through-Verifiable-Off-Chain-Computations\\CONFIG.yaml';
 //const fileContents = fs.readFileSync(configPath, 'utf8');

  let data = yaml.load(fileContents);
  deployer.deploy(Migrations);
  deployer.deploy(FederatedModel, data.DEFAULT.InputDimension, data.DEFAULT.OutputDimension, data.DEFAULT.LearningRate, data.DEFAULT.Precision, data.DEFAULT.BatchSize, data.DEFAULT.IntervalTime);
  deployer.deploy(verifier, { gas: data.DEFAULT.Gas });
  deployer.deploy(verifier_aggregator, { gas: data.DEFAULT.Gas });
};