const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with address:", deployer.address);

  // Deploy Verifier
  const Verifier = await hre.ethers.getContractFactory("Verifier");
  const verifier = await Verifier.deploy();
  await verifier.deployed();
  console.log("Verifier deployed to:", verifier.address);

  // Deploy PetitionPoll with verifier address
  const PetitionPoll = await hre.ethers.getContractFactory("PetitionPoll");
  const petitionPoll = await PetitionPoll.deploy(verifier.address);
  await petitionPoll.deployed();
  console.log("PetitionPoll deployed to:", petitionPoll.address);
}

main().catch((error) => {
  console.error("Deployment failed:", error);
  process.exitCode = 1;
});
