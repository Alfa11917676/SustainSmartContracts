require("dotenv").config();
const ethers = require("ethers");
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY ); // const wallet = new ethers.Wallet(process.env.KEY);
async  function signTransaction(
    projectOwnerAddress,
    tokenType,
    nonce,
    tokenId,

)  {
    const Sustain = {
        name: "STAKING",
        version: "1",
        chainId: 80001, //put the chain id
        verifyingContract: '0x7ffb34739F9b5bb4EdA8375d670eF4a9002Aa038', //contract address
    };

    const types = {
        Sustain: [
            { name: "userAddress", type: "address" },
            { name: "tokenType", type: "uint256" },
            { name: "nonce", type: "uint256" },
            { name:"tokenId", type:"uint256"}
        ],
    };

    const value = {
        userAddress: projectOwnerAddress,
        tokenType: tokenType,
        nonce: nonce,
        tokenId: tokenId
    };

    const sign = await wallet._signTypedData(Sustain, types, value);
    console.log(`['${projectOwnerAddress}',${tokenType},${nonce},${tokenId},'${sign}']`)
    return sign;
}

signTransaction('0x79BF6Ab2d78D81da7d7E91990a25A81e93724a60',3,1654248775,12797)
