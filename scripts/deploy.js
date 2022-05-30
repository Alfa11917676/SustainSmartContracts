
const hre = require("hardhat");

async function main() {
//  string memory domain,
//             string memory version,
//             string memory name,
//             string memory symbol,
//             address _tokenAddress,
//             address _designatedSigner,
//             uint64 subscriptionId
  const SustainNFT = await hre.ethers.getContractFactory('SustainNFT')
    const deployContract = await hre.upgrades.deployProxy(SustainNFT,[
        "STAKING",
        "1",
        "ARNAB",
        'ARNAB',
        "0xb82f344d01A7Fae318fB5287c0eb80F04121ab51",
        "0xb82f344d01A7Fae318fB5287c0eb80F04121ab51",
        1234
    ],{initializer:'initialize'})
  await deployContract.deployed()
  console.log(deployContract.address)

  // const Proxy = await hre.ethers.getContractFactory('UnstructuredProxy')
  // const proxy = await Proxy.deploy()
  // await proxy.deployed()
  // await proxy.upgradeTo(deployContract.address)
  // console.log('Proxy address', proxy.address)
  // console.log('The sustain nft is deployed to ',deployContract.address)


}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
