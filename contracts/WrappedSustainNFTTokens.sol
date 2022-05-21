//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./WrappedSustainSignature.sol";
contract WrappedSustainNFTTokens is OwnableUpgradeable, WrappedSustainSignature {

    IERC721Upgradeable nft;
    IERC20Upgradeable token;
    address public designatedSigner;
    // userAddress => nftId => amount
    mapping(address => mapping (uint => uint)) public loanTaken;
    // userAddress => nftId => amount
    mapping(address => mapping (uint => uint)) public loanRepaid;
    mapping(uint => address) public tokenOwner;
    mapping (address => mapping (uint => bool)) public nonceUsed;
    function initialize(string memory domain, string memory version, address nftAddress, address tokenAddress) external initializer {
        __Ownable_init();
        __WrappedSustainSignature_init(domain, version);
        token = IERC20Upgradeable(tokenAddress);
        nft = IERC721Upgradeable(nftAddress);
    }

    function loanToken(WrappedSustain memory wrapped) external {
        require (msg.sender == wrapped.userAddress,'!User');
        require(wrapped.nonce+ 10 minutes >= block.timestamp,'!Signature Expired');
        require (getSigner(wrapped) == designatedSigner);
        require (!nonceUsed[msg.sender][wrapped.nonce],'Nonce Used Already');
        nonceUsed[msg.sender][wrapped.nonce] = true;
        nft.safeTransferFrom(wrapped.userAddress,address(this),wrapped.nftId);
        loanTaken[wrapped.userAddress][wrapped.nftId] = wrapped.loanAmount;
        tokenOwner[wrapped.nftId] = wrapped.userAddress;
        token.transfer(wrapped.userAddress,wrapped.loanAmount);
    }

    function payBackAmount (uint collateralNftId, uint amount) external {
        require (tokenOwner[collateralNftId]==msg.sender,'!Owner of asset');
        token.transferFrom(msg.sender, address(this), amount);
        loanRepaid[msg.sender][collateralNftId]+=amount;
    }

    function withdrawAsset (uint collateralNFTId) external {
        require (tokenOwner[collateralNFTId]==msg.sender,'!Owner');
        require (loanRepaid[msg.sender][collateralNFTId] >= loanTaken[msg.sender][collateralNFTId],'Loan Not Repaid');
        nft.transferFrom(address(this), msg.sender, collateralNFTId);
    }

    function withDrawToken () external onlyOwner {
        token.transferFrom(address(this),owner(),token.balanceOf(address(this)));
    }

    function withDrawNFT (uint[] memory nftIds) external onlyOwner {
        for (uint i =0; i< nftIds.length; i++) {
            nft.transferFrom(address(this), owner(), nftIds[i]);
        }
    }

    function setCryptoAddresses (address tokenAddress, address nftAddress) external onlyOwner {
        token = IERC20Upgradeable(tokenAddress);
        nft = IERC721Upgradeable(nftAddress);
    }

    function setDesignatedSigner (address _signer) external onlyOwner {
        designatedSigner = _signer;
    }
}
