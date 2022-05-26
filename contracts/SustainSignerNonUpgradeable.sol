//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
contract SustainSignerNonUpgradeable is EIP712{

    string private constant  SIGNING_DOMAIN = 'SUSTAIN_NFT';
    string private constant SIGNATURE_VERSION = '1';

    struct Sustain{
        address userAddress;
        uint tokenType;
        uint nonce;
        uint tokenId;
        bytes signature;
    }

    constructor() EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION){}

//    function __SustainSigner_init(string memory domain, string memory version) internal initializer {
//        SIGNING_DOMAIN = domain;
//        SIGNATURE_VERSION = version;
//        __EIP712_init(domain, version);
//    }

    function getSigner(Sustain memory sustain) public view returns(address){
        return _verify(sustain);
    }

    /// @notice Returns a hash of the given rarity, prepared using EIP712 typed data hashing rules.

    function _hash(Sustain memory sustain) internal view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(
                keccak256("Sustain(address userAddress,uint256 tokenType,uint256 nonce,uint256 tokenId)"),
                sustain.userAddress,
                sustain.tokenType,
                sustain.nonce,
                sustain.tokenId
            )));
    }

    function _verify(Sustain memory sustain) internal view returns (address) {
        bytes32 digest = _hash(sustain);
        return ECDSA.recover(digest, sustain.signature);
    }

}