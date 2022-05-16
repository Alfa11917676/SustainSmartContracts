//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
contract WrappedSustainNFTTokens is OwnableUpgradeable {

    IERC721Upgradeable nft;
    IERC20Upgradeable token;
    // userAddress => nftId => amount
    mapping(address => mapping (uint => uint)) public loanTaken;
    mapping(address => mapping (uint => uint)) public loanRepaid;
    mapping(uint => address) public tokenOwner;
    function initialize() external initializer {
        __Ownable_init();
    }

    function loanToken(uint collateralNftId, uint loanAmount) external {
        nft.safeTransferFrom(msg.sender,address(this),collateralNftId);
        loanTaken[msg.sender][collateralNftId] = loanAmount;
        tokenOwner[collateralNftId] = msg.sender;
        token.transfer(msg.sender,loanAmount);
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
}
