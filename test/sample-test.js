const { expect } = require("chai");
const { ethers,upgrades, network} = require("hardhat");
const Web3 = require("web3");
const {fromWei} = Web3.utils;
const {artifacts} = require ("hardhat");
const {signTransaction} = require('../scripts/signer');

describe('L1, 8080 Locker Contract Test-Suite', async () => {
  let owner, alice, bob, stable, sustain, lender, nft;
  before(async () =>{
    [owner, alice, bob] = await ethers.getSigners();
    const erc = await ethers.getContractFactory('MyToken');
    stable = await erc.deploy();
    sustain = await erc.deploy();
    const NFT = await ethers.getContractFactory('MyNFTToken');
    nft = await NFT.deploy()
    const stake = await ethers.getContractFactory('Sustain_Lender_Staker');
    lender = await upgrades.deployProxy(
            stake,
        ["SUSTAIN",
              "1",
              nft.address,
              stable.address,
              sustain.address],
        {initializer: 'initialize'});
    await lender.deployed();
    await stable.connect(owner).mint(owner.address,ethers.utils.parseEther('10000'));
    await sustain.connect(owner).mint(owner.address,ethers.utils.parseEther('10000'));
    await stable.connect(owner).mint(lender.address,ethers.utils.parseEther('10000'));
    await lender.setDesignatedSigner('0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266');
    await nft.safeMint(owner.address,1);
    await nft.connect(owner).setApprovalForAll(lender.address, true);
    await stable.connect(owner).approve(lender.address, ethers.utils.parseEther('1000'));
    await sustain.connect(owner).approve(lender.address, ethers.utils.parseEther('1000'));
    await lender.setPenaltyPercent(5000)
  });

  describe ('Starting The Test Suite For Lending 🤞🏾', async () => {
    it ('Lending The Money', async ()=> {
      const block = await (ethers.getDefaultProvider()).getBlock('latest')
      const time = block.timestamp
      let signature = await signTransaction(lender.address,owner.address,nft.address,1,86400,5,ethers.utils.parseEther('100'),2000,1,true,time);
      await lender.loanToken([owner.address,nft.address,1,86400,5,ethers.utils.parseEther('100'),2000,1,true,time,signature])
      let structDetails = await lender.loanHelper(1,nft.address)
      expect (structDetails[0]).to.equal(true)
      expect (structDetails[1]).to.equal(86400)
      expect (structDetails[2]).to.equal(5)
      expect (structDetails[5]).to.equal(ethers.utils.parseEther('100'))
      expect (structDetails[6]).to.equal(2000)
      expect (structDetails[9]).to.equal(ethers.utils.parseEther('20'))
      expect (structDetails[10]).to.equal(owner.address)
    });

    it ('1st term repay 😊', async()=>{
        await network.provider.send("evm_increaseTime", [1*24*3600])
        await lender.payBackAmount(1,nft.address)
        let structDetails = await lender.loanHelper(1,nft.address)
        expect (fromWei(structDetails[8].toString(),'ether')).to.equal('4')
        // console.log(await lender.loanHelper(1,nft.address))
      });

    it ('2nd term payment with 1 month due with 50% penalty 😱', async() =>{
      await network.provider.send("evm_increaseTime", [2*24*3600])
      await lender.payBackAmount(1,nft.address)
      let structDetails = await lender.loanHelper(1,nft.address)
      expect(fromWei(structDetails[8].toString(),'ether')).to.equal('18')
    });

    it ('Trying to withdraw asset without paying whole amount 👨🏾‍✈️', async() => {
      await expect(lender.withdrawAsset(1,nft.address)).to.be.revertedWith('Not repaid')
    });

    it('Repaying All due payment at once🤑', async() => {
      await network.provider.send("evm_increaseTime",[1*24*3600])
      await expect(lender.bulkRepayment(1,nft.address,4)).to.be.revertedWith('Already Paid Enough')
      await lender.bulkRepayment(1,nft.address,3)
      let structDetails = await lender.loanHelper(1,nft.address)
      expect (fromWei(structDetails[8].toString(),'ether')).to.equal('30')
      // console.log(await lender.loanHelper(1,nft.address))
    });

    it ('Trying To Pay After Repaying Principle + Interest 😧', async()=>{
      await network.provider.send("evm_increaseTime", [1*24*3600])
      await expect (lender.payBackAmount(1,nft.address)).to.be.revertedWith('Already Paid Enough');
    });

    it ('Trying to withdraw asset after paying whole amount + interest🤠', async() => {
          expect( await nft.ownerOf(1)).to.equal(lender.address)
          await lender.withdrawAsset(1,nft.address)
          expect( await nft.ownerOf(1)).to.equal(owner.address)
    });

    it ('Trying To Pay After removing asset 😊', async()=>{
      await network.provider.send("evm_increaseTime", [1*24*3600])
      await expect (lender.payBackAmount(1,nft.address)).to.be.reverted;
    });

    it.only ('Minting_NFT', async()=> {
      let getSig1 = await signTransaction("0x67aC840FB47FB94Ad9EeE2dc9F8ab06dEe553aAF","0x79BF6Ab2d78D81da7d7E91990a25A81e93724a60",2,1655467589,1)
      let getSig2 = await signTransaction("0x67aC840FB47FB94Ad9EeE2dc9F8ab06dEe553aAF","0x79BF6Ab2d78D81da7d7E91990a25A81e93724a60",2,1655467590,1)
      let getSig3 = await signTransaction("0x67aC840FB47FB94Ad9EeE2dc9F8ab06dEe553aAF","0x79BF6Ab2d78D81da7d7E91990a25A81e93724a60",2,1655467591,1)
      console.log([["0x79BF6Ab2d78D81da7d7E91990a25A81e93724a60",2,1655467589,1,`'${getSig1}'`],["0x79BF6Ab2d78D81da7d7E91990a25A81e93724a60",2,1655467590,1,`'${getSig2}'`],["0x79BF6Ab2d78D81da7d7E91990a25A81e93724a60",2,1655467591,1,`'${getSig3}'`]])

    })


  });
});