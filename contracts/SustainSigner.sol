//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
contract SustainSigner is EIP712Upgradeable{

    string private  SIGNING_DOMAIN;
    string private  SIGNATURE_VERSION;

    struct Sustain{
        address userAddress;
        uint tokenType;
        uint nonce;
        uint tokenId;
        uint loanAmount;
        uint interestAmount;
        bool inStableCoin;
        bytes signature;
    }

    function __SustainSigner_init(string memory domain, string memory version) internal initializer {
        SIGNING_DOMAIN = domain;
        SIGNATURE_VERSION = version;
        __EIP712_init(domain, version);
    }

    function getSigner(Sustain memory sustain) public view returns(address){
        return _verify(sustain);
    }

    /// @notice Returns a hash of the given rarity, prepared using EIP712 typed data hashing rules.

    function _hash(Sustain memory sustain) internal view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(
                keccak256("Sustain(address userAddress,uint256 tokenType,uint256 nonce,uint256 tokenId,uint256 loanAmount,uint256 interestAmount,bool inStableCoin)"),
                    sustain.userAddress,
                    sustain.tokenType,
                    sustain.nonce,
                    sustain.tokenId,
                    sustain.loanAmount,
                    sustain.interestAmount,
                    sustain.inStableCoin
            )));
    }

    function _verify(Sustain memory sustain) internal view returns (address) {
        bytes32 digest = _hash(sustain);
        return ECDSAUpgradeable.recover(digest, sustain.signature);
    }

}