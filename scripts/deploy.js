
const hre = require("hardhat");

async function main() {

  const SustainNFT = await hre.ethers.getContractFactory('SustainNFT')
    const deployContract = await SustainNFT.deploy()
  await deployContract.deployed()


  const Proxy = await hre.ethers.getContractFactory('UnstructuredProxy')
  const proxy = await Proxy.deploy()
  await proxy.deployed()
  await proxy.upgradeTo(deployContract.address)
  console.log('Proxy address', proxy.address)
  console.log('The sustain nft is deployed to ',deployContract.address)


}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
