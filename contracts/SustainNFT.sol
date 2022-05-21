//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
//import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./ERC721AUpgradeable.sol";
import "./SustainSigner.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
contract SustainNFT is SustainSigner, OwnableUpgradeable, ERC721AUpgradeable {
    address public designatedSigner;
    IERC20Upgradeable token;
    string randomNonce;
    uint public globalTimeDelta;
    //(0,0.1,0.25,0.5)*100
    uint[] public rewardRate;
    uint[] public tokentierToPrice;
    uint[] public tokenIdToTokenAllocation;

    // tokenId => lastClaimTime
    mapping (uint => uint) public lastClaimTime;
    // tokenId => tokenTier
    mapping (uint => uint) public tokentier;
    // randomNess
    mapping (address => mapping (uint => bool)) public nonceUsed;
    // tokenId => true/false
    mapping (uint => bool) public tokenTaken;

    function initialize (
        string memory domain,
        string memory version,
        string memory name,
        string memory symbol,
        address _tokenAddress,
        address _designatedSigner) external initializer {
        __Ownable_init();
        __ERC721A_init(name,symbol);
        __SustainSigner_init(domain, version);
        designatedSigner = _designatedSigner;
        token = IERC20Upgradeable(_tokenAddress);
        randomNonce = string(abi.encodePacked(domain,symbol,name,version));
        rewardRate= [0,10,25,50];
        tokentierToPrice= [0,10 ether, 25 ether, 50 ether];
        tokenIdToTokenAllocation= [0,0,5000,10000];
        _mint(owner(),14999);
    }

    // tokenId <5000 tier =1 , tokenID <10000 && >=5000 tier=2, tokenID <15000 && >=10000
    function _giveTokens(Sustain memory sustain, uint[] memory tokenTypes) external {
        require (getSigner(sustain) == designatedSigner,'!Signer');
        require (msg.sender == sustain.userAddress,'!User');
        require (sustain.nonce + 10 minutes > block.timestamp,'Signature Expired');
        require (!nonceUsed[msg.sender][sustain.nonce],'Nonce Used Already');
        nonceUsed[msg.sender][sustain.nonce] = true;
        for (uint i=0;i< tokenTypes.length;i++){
                uint tokenId = getTokenNumber(tokenTypes[i]);
                tokentier[tokenId] = tokenTypes[i];
                tokenTaken[tokenId] = true;
                token.transferFrom(sustain.userAddress,address(this),tokentierToPrice[tokenTypes[i]]);
                safeTransferFrom(owner(),sustain.userAddress,tokenId);
        }
    }

    function getTokenNumber(uint tokenTier) internal returns (uint) {
        uint randomNumber;
        randomNumber = randomNumberGenerator();
        randomNumber = (randomNumber % 5000) + tokenIdToTokenAllocation[tokenTier];

        bool status;
        while(!status){
            randomNumber++;
            if (!tokenTaken[randomNumber]){
                    status = true;
            }
        }
        return randomNumber;
    }

    function getRewards(uint[] memory tokenIds, address user) public view returns(uint){
        uint totalRewardGenerated;
        for (uint i=0;i< tokenIds.length;i++) {
                require (user == ownerOf(tokenIds[i]),'!Owner');
                uint timeDelta = (block.timestamp - lastClaimTime[tokenIds[i]])/ globalTimeDelta ;
                uint rewardGenerated = ((timeDelta * rewardRate[tokentier[tokenIds[i]]])* 1 ether) / 100;
                totalRewardGenerated += rewardGenerated;
        }
        return totalRewardGenerated;
    }

    function claimReward(uint[] memory tokenIds) external {
        uint totalRewardGenerated = getRewards(tokenIds, msg.sender);
        for (uint i=0;i<tokenIds.length;i++){
            lastClaimTime[tokenIds[i]] = block.timestamp;
        }
        require (totalRewardGenerated > 0,'No rewards generated');
        token.transfer(msg.sender, totalRewardGenerated);
    }

    function mintTokensFromReward (Sustain memory sustain) external {
        uint[] memory tokenId;
        tokenId[0] = sustain.tokenId;
        require(getRewards(tokenId,sustain.userAddress)>tokentier[sustain.tokenId],'Minimum amount not satisfied');
        require (msg.sender == sustain.userAddress,'!User');
        require (sustain.nonce + 10 minutes > block.timestamp,'Signature Expired');
        uint amount = getRewards(tokenId,sustain.userAddress);
        token.transfer(msg.sender,amount-tokentier[sustain.tokenId]);
        lastClaimTime[sustain.tokenId] = block.timestamp;
        safeTransferFrom(address(this), msg.sender, sustain.randomTokenId);
    }

    function addDesignatedSigner(address _signer) external onlyOwner {
        designatedSigner = _signer;
    }

    function setTokenType(address _type) external onlyOwner {
        token = IERC20Upgradeable(_type);
    }

    function randomNumberGenerator () internal returns (uint) {
        uint randomNumber = uint(keccak256(abi.encodePacked(block.number, block.difficulty, randomNonce)));
        randomNonce = string(abi.encodePacked(block.number, block.difficulty, randomNonce));
        return randomNumber;
    }

    function withDrawToken () external onlyOwner {
        token.transferFrom(address(this),owner(),token.balanceOf(address(this)));
    }
}
