import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { getAddress, parseGwei } from "viem";

import {ethers} from "ethers";

describe("TokenVestingLinear", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployTokenVestingLinear() {

    const ethValue = parseGwei("0");
    const merkleRoot = ethers.utils.formatBytes32String("test")  // todo: fix it

    const [signer, otherAccount] = await hre.viem.getWalletClients();

    const tokenVestingLinear = await hre.viem.deployContract("TokenVestingLinear", [signer.account.address, merkleRoot], {
      value: ethValue,
    });

    const publicClient = await hre.viem.getPublicClient();

    return {
      tokenVestingLinear,
      ethValue,
      signer,
      otherAccount,
      publicClient,
    };
  }

  describe("test", function () {
    it("Should set the right unlockTime", async function () {
      const { tokenVestingLinear, signer } = await loadFixture(deployTokenVestingLinear);

      // expect(await lock.read.unlockTime()).to.equal(unlockTime);
    });

    it("Should set the right owner", async function () {

    }); 

  });
});
