
const hre = require("hardhat");
const {signTransaction} = require("./signer")
async function main() {

  const SustainNFT = await hre.ethers.getContractFactory('SustainNFT')
  const upgrade = await upgrades.upgradeProxy('0x7ffb34739F9b5bb4EdA8375d670eF4a9002Aa038',SustainNFT)
    await upgrade.deployed()
    console.log(upgrade.address)

    //   const deployContract = await hre.upgrades.deployProxy(SustainNFT,[
    //     "STAKING",
    //     "1",
    //     "SUSTAIN_TOKEN",
    //     'SUT',
    //     "0x6d97825c13cd633E0a596cA4AEBeb6a9Dda52884",
    //     "0x79BF6Ab2d78D81da7d7E91990a25A81e93724a60"
    // ],{initializer:'initialize'})
  // await deployContract.deployed()
  // console.log(deployContract.address)


    //   const deployToken = await ethers.getContractFactory('sustainToken')
  //   const token = await deployToken.deploy('SUSTAIN','SUS')
  //   await token.deployed()
  //   console.log(token.address)
  //   console.log(await signTransaction('0x79BF6Ab2d78D81da7d7E91990a25A81e93724a60',2,1654162269,1))
//['0x79BF6Ab2d78D81da7d7E91990a25A81e93724a60',1,1654162269,1,'0xd33f8a4e551e1a637a4894c7e6803e70098e42244f6545b67cde90b19fe4ab586d9b0f3d47c0d9b189228c352b3cc9f4d6cdb6696b243074b80021f155f2be971b']

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
