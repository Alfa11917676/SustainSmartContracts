
const hre = require("hardhat");
const {signTransaction} = require("./signer")
async function main() {

  const SustainNFT = await hre.ethers.getContractFactory('SustainNFT')
    const deployContract = await hre.upgrades.deployProxy(SustainNFT,[
        "STAKING",
        "1",
        "ARNAB",
        'ARNAB',
        "0xb82f344d01A7Fae318fB5287c0eb80F04121ab51",
        "0xb82f344d01A7Fae318fB5287c0eb80F04121ab51",
        450
    ],{initializer:'initialize'})
  await deployContract.deployed()
  console.log(deployContract.address)
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
