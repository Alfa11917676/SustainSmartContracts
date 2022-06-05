//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./Sustain_Lender_Staker_Contract_Signer.sol";
import "./ABDKMath64x64.sol";
contract Sustain_Lender_Staker is OwnableUpgradeable, Sustain_Lender_Staker_Signer, ReentrancyGuardUpgradeable  {

    IERC721Upgradeable nft;
    IERC20Upgradeable sustainToken;
    IERC20Upgradeable stableToken;

    struct tokenInfo {
        uint stakeTime;
        uint lastClaimTime;
        uint apr;
        address owner;
    }

    struct loanInfo {
        bool currencyMode;
        uint timeInterval;
        uint paymentSplit;
        uint paymentMade;
        uint lastPaymentTime;
        uint principleTaken;
        uint interestPercent;
        uint principlePaid;
        uint interestPaid;
        uint principleToPayEachInterval;
        address owner;
    }



    uint public penaltyPercent;
    address public designatedSigner;

    // tokenId => nftAddress => Struct
    mapping (uint => mapping (address => loanInfo)) public loanHelper;
    // userAddress => nft => paymentInfo[]
    mapping (address => mapping (uint => uint[])) public repaymentOfPrincipleSplitInfo;
    mapping (address => mapping (uint => uint[])) public repaymentOfInterestSplitInfo;
    // tokenId => nftContractAddress => ownerAddress
    mapping(uint => mapping (address => address)) public tokenLendingOwner;
    mapping (address => mapping (uint => bool)) public nonceUsed;
    // info about tokens locked for staking
    mapping (uint => address) public tokenStakingOwner;
    // ownerAddress => nftAddress => tokenId[]
    mapping (address => mapping (address => uint[])) public tokensStakedPerOwner;
    mapping (address => mapping (address => uint[])) public tokensLendingPerOwner;
    mapping (uint => tokenInfo) public stakeInfo;

    function initialize (
        string memory domain,
        string memory version,
        address sustainNftAddress,
        address _stableAddress,
        address _sustainAddress
    ) external initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __WrappedSustainSignature_init(domain, version);
        stableToken = IERC20Upgradeable(_stableAddress);
        sustainToken = IERC20Upgradeable(_sustainAddress);
        nft = IERC721Upgradeable(sustainNftAddress);
    }

    function calculateInterest(uint tokenId, address _nftAddress) public view returns (uint) {
            uint principleAMount = loanHelper[tokenId][_nftAddress].principleToPayEachInterval;
            uint interestPercent = loanHelper[tokenId][_nftAddress].interestPercent;
            uint lastPaid = loanHelper[tokenId][_nftAddress].lastPaymentTime;
            uint timeInterval = loanHelper[tokenId][_nftAddress].timeInterval;
            uint timeTaken = block.timestamp - lastPaid; // total time taken to pay the next part of debt
            uint interestIncreased = timeTaken / timeInterval;
            uint finalInterest = interestPercent + (interestIncreased - 1) * penaltyPercent;
            uint interestAmount = principleAMount * finalInterest / 10000;
            return interestAmount;
    }

    function loanToken(WrappedSustain memory wrapped) external nonReentrant{
        require (msg.sender == wrapped.userAddress,'!User');
        require(wrapped.nonce+ 10 minutes >= block.timestamp,'!Signature Expired');
        require (getSigner(wrapped) == designatedSigner);
        require (!nonceUsed[msg.sender][wrapped.nonce],'Nonce Used Already');
        nonceUsed[msg.sender][wrapped.nonce] = true;
        IERC721Upgradeable(wrapped.nftAddress).safeTransferFrom(wrapped.userAddress,address(this),wrapped.nftId);
        tokensLendingPerOwner[msg.sender][wrapped.nftAddress].push(wrapped.nftId);
        tokenLendingOwner[wrapped.nftId][wrapped.nftAddress] = wrapped.userAddress;
        loanInfo memory info;
        info.owner = msg.sender;
        info.currencyMode = wrapped.inStableCoin;
        info.lastPaymentTime = block.timestamp;
        info.paymentMade = 0;
        info.paymentSplit = wrapped.paymentPartition;
        info.timeInterval = wrapped.minimumTime;
        info.principleTaken = wrapped.loanAmount;
        info.interestPercent = wrapped.interestPercent;
        info.principleToPayEachInterval = wrapped.loanAmount/wrapped.paymentPartition;
        loanHelper[wrapped.nftId][wrapped.nftAddress] = info;
        if (wrapped.inStableCoin)
        stableToken.transfer(wrapped.userAddress,wrapped.loanAmount);
        else
        payable(msg.sender).transfer(wrapped.loanAmount);
    }

    function payBackAmount (uint collateralNftId, address _nftContractAddress) external payable nonReentrant {
        require (tokenLendingOwner[collateralNftId][_nftContractAddress]==msg.sender,'!Owner of asset');
        if(loanHelper[collateralNftId][_nftContractAddress].currencyMode)
        stableToken.transferFrom(msg.sender, address(this), loanHelper[collateralNftId][_nftContractAddress].principleToPayEachInterval);
        else
        require (msg.value == loanHelper[collateralNftId][_nftContractAddress].principleToPayEachInterval,'Amount not paid');
        uint interestAmount = calculateInterest(collateralNftId,_nftContractAddress);
        sustainToken.transferFrom(msg.sender, address(this), interestAmount);
        loanHelper[collateralNftId][_nftContractAddress].lastPaymentTime = block.timestamp;
        loanHelper[collateralNftId][_nftContractAddress].principlePaid+=loanHelper[collateralNftId][_nftContractAddress].principleToPayEachInterval;
        loanHelper[collateralNftId][_nftContractAddress].paymentMade+=1;
        loanHelper[collateralNftId][_nftContractAddress].interestPaid+=interestAmount;
    }

    function bulkRepayment(uint collateralNftId, address _nftContractAddress, uint howManyTerms) external payable nonReentrant {
        for (uint i= 0;i< howManyTerms; i++) {
            require (tokenLendingOwner[collateralNftId][_nftContractAddress] == msg.sender,'!Owner of asset');
            if (loanHelper[collateralNftId][_nftContractAddress].currencyMode)
            stableToken.transferFrom(msg.sender, address (this), loanHelper[collateralNftId][_nftContractAddress].principleToPayEachInterval);
            else
            require (loanHelper[collateralNftId][_nftContractAddress].principleToPayEachInterval * howManyTerms == msg.value,'Correct Amount Not Paid');
            uint interestAmount = calculateInterest(collateralNftId,_nftContractAddress);
            sustainToken.transferFrom(msg.sender, address (this), interestAmount);
            loanHelper[collateralNftId][_nftContractAddress].lastPaymentTime = block.timestamp;
            loanHelper[collateralNftId][_nftContractAddress].principlePaid += loanHelper[collateralNftId][_nftContractAddress].principleToPayEachInterval;
            loanHelper[collateralNftId][_nftContractAddress].paymentMade+=1;
            loanHelper[collateralNftId][_nftContractAddress].interestPaid += interestAmount;
        }
    }

    function withdrawAsset (uint collateralNFTId, address _nftContractAddress) external {
        require (tokenLendingOwner[collateralNFTId][_nftContractAddress]==msg.sender,'!Owner');
        require (loanHelper[collateralNFTId][_nftContractAddress].paymentMade==loanHelper[collateralNFTId][_nftContractAddress].paymentSplit,'Not repaid');
        delete loanHelper[collateralNFTId][_nftContractAddress];
        delete tokenLendingOwner[collateralNFTId][_nftContractAddress];
        IERC721Upgradeable(_nftContractAddress).transferFrom(address(this), msg.sender, collateralNFTId);
    }

    function withDrawToken () external onlyOwner {
        if (sustainToken.balanceOf(address(this))>0)
        sustainToken.transferFrom(address(this),owner(),sustainToken.balanceOf(address(this)));
        if (stableToken.balanceOf(address(this))>0)
        stableToken.transferFrom(address(this),owner(),stableToken.balanceOf(address(this)));
        if (address(this).balance>0)
        payable(owner()).transfer(address(this).balance);
    }

    function withDrawNFT (uint[] memory nftIds,address[] memory nftAddress) external onlyOwner {
        for (uint i =0; i< nftIds.length; i++) {
            IERC721Upgradeable(nftAddress[i]).transferFrom(address(this), owner(), nftIds[i]);
        }
    }

    function setCryptoAddresses (address sustainToken_, address stableToken_, address _nftAddress) external onlyOwner {
        sustainToken = IERC20Upgradeable(sustainToken_);
        stableToken = IERC20Upgradeable(stableToken_);
        nft = IERC721Upgradeable(_nftAddress);
    }

    function setDesignatedSigner (address _signer) external onlyOwner {
        designatedSigner = _signer;
    }

    //@dev This percentage should be given by multiplying 100 with it
    //@dev Eg: If I have to give 2.5%, I will pass 250
    function setPenaltyPercent(uint _amount) external onlyOwner {
        penaltyPercent = _amount;
    }

    function getTotalTokenLendingPerUser(address _user, address _nftAddress) external view returns(uint[] memory) {
        return tokensLendingPerOwner[_user][_nftAddress];
    }

    // STAKING IMPLEMENTATION //

    function stakeTokens (uint[] memory tokenIds, WrappedSustain[] memory signer) external {
        for (uint i = 0; i< tokenIds.length; i++) {
            require (getSigner(signer[i]) == designatedSigner,'!Signer');
            require (signer[i].userAddress == msg.sender,'!User');
            require (nft.ownerOf(tokenIds[i]) == msg.sender,'!NFT_Owner');
            tokenStakingOwner[tokenIds[i]] = msg.sender;
            tokensStakedPerOwner[msg.sender][signer[i].nftAddress].push(tokenIds[i]);
            tokenInfo memory info;
            info.owner = msg.sender;
            info.stakeTime = block.timestamp;
            info.lastClaimTime = block.timestamp;
            info.apr = signer[i].apr;
            stakeInfo[tokenIds[i]] = info;
            nft.safeTransferFrom(msg.sender, address(this), tokenIds[i]);
        }
    }

    function claimRewards(uint[] memory tokenIds) public {
        uint finalAmount;
        for (uint i=0;i< tokenIds.length;i++) {
            require (tokenStakingOwner[tokenIds[i]]==msg.sender,'!Owner');
            finalAmount += getRewards(tokenIds[i]);
            stakeInfo[tokenIds[i]].lastClaimTime = block.timestamp;
        }
        sustainToken.transfer(msg.sender,finalAmount);
    }

    function getCompoundInterest(uint principal, uint periods) internal pure returns (uint) {
        return ABDKMath64x64.mulu(
            ABDKMath64x64.pow(ABDKMath64x64.div(100,97), periods),
            principal
        );
    }

    function getRewards(uint tokenId) public view returns(uint) {
            uint amount = getCompoundInterest(stakeInfo[tokenId].apr,block.timestamp - stakeInfo[tokenId].lastClaimTime);
            return amount;
    }

    function un_stakeToken(uint[] memory tokenIds) external {
        claimRewards(tokenIds);
        for (uint i=0;i<tokenIds.length;i++) {
                require (tokenStakingOwner[tokenIds[i]] == msg.sender);
                delete tokenStakingOwner[tokenIds[i]];
                nft.safeTransferFrom(address(this),msg.sender,tokenIds[i]);
        }
    }

    function getTotalTokenStakingPerUser(address _user, address _nftAddress) external view returns(uint[] memory) {
        return tokensStakedPerOwner[_user][_nftAddress];
    }

}
