//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./WrappedSustainSignature.sol";
contract WrappedSustainNFTTokens is OwnableUpgradeable, WrappedSustainSignature, ReentrancyGuardUpgradeable  {

    IERC721Upgradeable nft;
    IERC20Upgradeable sustainToken;
    IERC20Upgradeable stableToken;
    address public designatedSigner;
    // true => stable coin, false => native
    // userAddress => nftId =>  true/false => amount
    mapping(address => mapping (uint => mapping (bool => uint))) public loanTaken;
    // userAddress => nftId =>  true/false => amount
    mapping(address => mapping (uint =>  mapping (bool => uint))) public loanRepaid;
    mapping (uint => bool) public tokenIdToLoanCurrency;
    mapping(uint => address) public tokenOwner;
    mapping (uint => uint) public interestAmount;
    mapping (uint => uint) public interestPaid;
    mapping (address => mapping (uint => bool)) public nonceUsed;
    function initialize (string memory domain, string memory version, address nftAddress, address _stableAddress, address _sustainAddress) external initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __WrappedSustainSignature_init(domain, version);
        stableToken = IERC20Upgradeable(_stableAddress);
        sustainToken = IERC20Upgradeable(_sustainAddress);
        nft = IERC721Upgradeable(nftAddress);
    }

    function loanToken(WrappedSustain memory wrapped) external nonReentrant{
        require (msg.sender == wrapped.userAddress,'!User');
        require(wrapped.nonce+ 10 minutes >= block.timestamp,'!Signature Expired');
        require (getSigner(wrapped) == designatedSigner);
        require (!nonceUsed[msg.sender][wrapped.nonce],'Nonce Used Already');
        nonceUsed[msg.sender][wrapped.nonce] = true;
        nft.safeTransferFrom(wrapped.userAddress,address(this),wrapped.nftId);
        loanTaken[wrapped.userAddress][wrapped.nftId][wrapped.inStableCoin] = wrapped.loanAmount;
        tokenOwner[wrapped.nftId] = wrapped.userAddress;
        tokenIdToLoanCurrency[wrapped.nftId] = wrapped.inStableCoin;
        interestAmount[wrapped.nftId] = wrapped.interestAmount;
        if (wrapped.inStableCoin)
        stableToken.transfer(wrapped.userAddress,wrapped.loanAmount);
        else
        payable(msg.sender).transfer(wrapped.loanAmount);
    }

    function payBackAmount (uint collateralNftId, uint amount, uint _interestAmount) external payable nonReentrant {
        require (tokenOwner[collateralNftId]==msg.sender,'!Owner of asset');
        if(tokenIdToLoanCurrency[collateralNftId])
        stableToken.transferFrom(msg.sender, address(this), amount);
        else
        require (msg.value == amount,'Amount not paid');

        if(_interestAmount>0){
            interestPaid[collateralNftId] = _interestAmount;
            sustainToken.transferFrom(msg.sender, address(this), _interestAmount);
        }
        loanRepaid[msg.sender][collateralNftId][tokenIdToLoanCurrency[collateralNftId]]+=amount;
    }

    function withdrawAsset (uint collateralNFTId) external {
        require (tokenOwner[collateralNFTId]==msg.sender,'!Owner');
        require (loanRepaid[msg.sender][collateralNFTId][tokenIdToLoanCurrency[collateralNFTId]] >= loanTaken[msg.sender][collateralNFTId][tokenIdToLoanCurrency[collateralNFTId]],'Loan Not Repaid');
        require (interestAmount[collateralNFTId] == interestPaid[collateralNFTId],'Interest Not Paid');
        nft.transferFrom(address(this), msg.sender, collateralNFTId);
    }

    function withDrawToken () external onlyOwner {
        if (sustainToken.balanceOf(address(this))>0)
        sustainToken.transferFrom(address(this),owner(),sustainToken.balanceOf(address(this)));
        if (stableToken.balanceOf(address(this))>0)
        stableToken.transferFrom(address(this),owner(),stableToken.balanceOf(address(this)));
        if (address(this).balance>0)
        payable(owner()).transfer(address(this).balance);
    }

    function withDrawNFT (uint[] memory nftIds) external onlyOwner {
        for (uint i =0; i< nftIds.length; i++) {
            nft.transferFrom(address(this), owner(), nftIds[i]);
        }
    }

    function setCryptoAddresses (address sustainToken_, address stableToken_, address nftAddress) external onlyOwner {
        sustainToken = IERC20Upgradeable(sustainToken_);
        stableToken = IERC20Upgradeable(stableToken_);
        nft = IERC721Upgradeable(nftAddress);
    }

    function setDesignatedSigner (address _signer) external onlyOwner {
        designatedSigner = _signer;
    }

}
