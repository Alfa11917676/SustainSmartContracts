require('dotenv').config()
// const { Sign } = require('crypto');
const ethers = require('ethers');
// const { truncate } = require('fs/promises');
const wallet = new ethers.Wallet("c3fe21d0d8def509c2315d174362126f9cd7ef640d74fdfb74d6d6aa7bf06621")// const wallet = new ethers.Wallet(process.env.KEY);
module.exports.signTransaction
= async (contractAddress,userAddress,tokenType,nonce,tokenId) =>
{
    const domain = {
        name: "SUSTAIN",
        version: "1",
        chainId: 800001, //put the chain id
        verifyingContract: contractAddress//contract address
    }

    const types ={
        Sustain : [
            {name: 'userAddress', type: 'address'},
            {name: 'tokenType',type: 'uint256'},
            {name: 'nonce', type: 'uint256'},
            {name: 'tokenId', type: 'uint256'}
        ]
    }


    const value = {
        userAddress:userAddress,
        tokenType:tokenType,
        nonce:nonce,
        tokenId:tokenId,
    };
    const sign = await wallet._signTypedData(domain,types,value)
    // console.log(sign);
    return sign
}
// signTransaction("0x4c701d94572eCd5464aa95CFD4E6aA70615Aad80","0xbec40A03cA0370026f66D8A2A191cb54C9fA4eb6",3458,10,2,"1000000000000000000000",10,30,"false",1654508917)
// module.exports = { signTransaction };

