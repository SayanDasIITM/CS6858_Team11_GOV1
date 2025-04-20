const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Petition", function () {
  let petition;
  beforeEach(async () => {
    const Factory = await ethers.getContractFactory("Petition");
    petition = await Factory.deploy();
    await petition.deployed();
  });

  it("creates a petition and signs it with a dummy proof", async () => {
    await petition.createPetition("My Title", "My Desc");
    // simulate a valid Semaphore proof: we bypass verifyProof here by
    // sending root=0, signal=0, nullifierHash=1, and an empty bytes proof
    await petition.signPetition(0, 0, 1, 0, "0x");
    const data = await petition.petitions(0);
    expect(data.signatureCount).to.equal(1);
  });
});
