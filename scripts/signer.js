require('dotenv').config()
// const { Sign } = require('crypto');
const ethers = require('ethers');
// const { truncate } = require('fs/promises');
const wallet = new ethers.Wallet("0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80")// const wallet = new ethers.Wallet(process.env.KEY);
module.exports.signTransaction
= async (contractAddress,userAddress,nftAddress,nftId,minimumTime,paymentPartition,loanAmount,interestPercent,apr,inStableCoin,nonce) =>
{
    const domain = {
        name: "SUSTAIN",
        version: "1",
        chainId: 31337, //put the chain id
        verifyingContract: contractAddress//contract address
    }

    const types ={
        WrappedSustain : [
            {name: 'userAddress', type: 'address'},
            {name: 'nftAddress',type: 'address'},
            {name: 'nftId', type: 'uint256'},
            {name: 'minimumTime', type: 'uint256'},
            {name: 'paymentPartition', type: 'uint256'},
            {name: 'loanAmount', type: 'uint256'},
            {name: 'interestPercent', type: 'uint256'},
            {name: 'apr', type: 'uint256'},
            {name: 'inStableCoin',type:'bool'},
            {name: 'nonce', type: 'uint256'},
        ]
    }


    const value = {
        userAddress:userAddress,
        nftAddress:nftAddress,
        nftId:nftId,
        minimumTime:minimumTime,
        paymentPartition:paymentPartition,
        loanAmount:loanAmount,
        interestPercent:interestPercent,
        apr:apr,
        inStableCoin:inStableCoin,
        nonce:nonce,
    };
    const sign = await wallet._signTypedData(domain,types,value)
    // console.log(sign);
    return sign
}
// signTransaction("0x4c701d94572eCd5464aa95CFD4E6aA70615Aad80","0xbec40A03cA0370026f66D8A2A191cb54C9fA4eb6",3458,10,2,"1000000000000000000000",10,30,"false",1654508917)
// module.exports = { signTransaction };

