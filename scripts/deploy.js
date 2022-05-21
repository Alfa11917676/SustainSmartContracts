
const hre = require("hardhat");

async function main() {

  const sustain = await hre.ethers.getContractFactory("rewardToken");
  const Sustain = await sustain.deploy("Sustain",'$SUS');
  await Sustain.deployed();
  console.log("Sustain deployed to:", Sustain.address);

  const SustainNFT = await hre.ethers.getContractFactory('SustainNFT')
  const sustainNFt = await hre.upgrade.deployProxy(SustainNFT,[
      "SUSTAIN_NFT",
      "1",
      "SUSTAIN_NFT",
      "SNFT",
      Sustain.address,
      Sustain.address
  ])
  await sustainNFt.deployed()
  console.log('The sustain nft is deployed to ',sustainNFt.address)

  const Wrapped = await hre.ethers.getContractFactory("WrappedSustainNFTTokens")
  const wrapped = await hre.upgrade.deployProxy(Wrapped, [
        "Wrapped_NFT_Asset",
        "1",
        sustainNFt.address,
        Sustain.address
  ])

 await  wrapped.deployed()
  console.log('The wrapped asset is deployed to: ', wrapped.address)
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
