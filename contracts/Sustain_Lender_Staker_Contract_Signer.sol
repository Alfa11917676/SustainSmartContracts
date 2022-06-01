//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
contract Sustain_Lender_Staker_Signer is EIP712Upgradeable{

    string private SIGNING_DOMAIN;
    string private SIGNATURE_VERSION;

    struct WrappedSustain{
        address userAddress;
        uint nftId;
        uint loanAmount;
        uint interestAmount;
        uint apr; // value in wei
        bool inStableCoin;
        uint nonce;
        bytes signature;
    }

    function __WrappedSustainSignature_init(string memory domain, string memory version) internal initializer {
        SIGNING_DOMAIN = domain;
        SIGNATURE_VERSION = version;
        __EIP712_init(domain, version);
    }

    function getSigner(WrappedSustain memory sustain) public view returns(address){
        return _verify(sustain);
    }

    /// @notice Returns a hash of the given rarity, prepared using EIP712 typed data hashing rules.

    function _hash(WrappedSustain memory sustain) internal view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(
                keccak256("WrappedSustain(address userAddress,uint256 nftId,uint256 loanAmount,uint256 loanAmount,uint256 interestAmount,uint256 apr,bool inStableCoin,uint256 nonce)"),
                    sustain.userAddress,
                    sustain.nftId,
                    sustain.loanAmount,
                    sustain.interestAmount,
                    sustain.apr,
                    sustain.inStableCoin,
                    sustain.nonce
            )));
    }

    function _verify(WrappedSustain memory sustain) internal view returns (address) {
        bytes32 digest = _hash(sustain);
        return ECDSAUpgradeable.recover(digest, sustain.signature);
    }

}