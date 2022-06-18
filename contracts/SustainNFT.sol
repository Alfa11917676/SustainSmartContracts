//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "./SustainSigner.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
contract SustainNFT is SustainSigner, OwnableUpgradeable, ERC721Upgradeable, VRFConsumerBase{


    address public designatedSigner;
    IERC20Upgradeable token;
    string randomNonce;
    uint public rebaseTime;
    bool isMinted;
    uint public delta;
    string public baseTokenURI;
    //(0,0.1,0.25,0.5)*100
    uint[] public rewardRate;
    uint[] public tokentierToPrice;
    uint[] public tokenIdToTokenAllocation;

    mapping (address => mapping (uint => uint)) public outstandingBalances;
    // tokenId => lastClaimTime
    mapping (uint => uint) public lastClaimTime;
    // tokenId => tokenTier
    mapping (uint => uint) public tokentier;
    // randomNess
    mapping (address => mapping (uint => bool)) public nonceUsed;
    // tokenId => true/false
    mapping (uint => bool) public tokenTaken;

    mapping (bytes32 => uint) public requestToTokenTypeMap;
    mapping (bytes32 => address) public requestToUserMap;
    mapping (bytes32 => uint) public requestToRandomNumber;

    bytes32  internal keyHash;
    uint256  internal fee;


    function initialize (
            string memory domain,
            string memory version,
            string memory name,
            string memory symbol,
            string memory baseUri,
            address _tokenAddress,
            address _designatedSigner
            ) external initializer {
                __ERC721_init(name,symbol);
                __Ownable_init();
                __SustainSigner_init(domain, version);
                designatedSigner = _designatedSigner;
                token = IERC20Upgradeable(_tokenAddress);
                baseTokenURI = baseUri;
                randomNonce = string(abi.encodePacked(domain,symbol,name,version));
                rewardRate= [0,10,25,50];
                delta = 100;
                rebaseTime = 60;
                tokentierToPrice= [0,10 ether, 25 ether, 50 ether];
                tokenIdToTokenAllocation= [0,0,5000,10000];
                __VRFInit_(0x8C7382F9D8f56b33781fE506E897a4F1e2d17255,0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
                keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
                fee = 0.0001 ether;
            }


//    function mintMultipleTokens (Sustain[] memory sustain, uint[] memory tokenTypes) external {
    function mintMultipleTokens (uint[] memory tokenTypes) external {
//        require (sustain.length == tokenTypes.length,'Please send equal amount');
        for (uint i=0; i<tokenTypes.length; i++)
            mintNFT(tokenTypes[i],false);
    }
    mapping (bytes32 => bool) public mintFromReward;
//    function mintNFT( uint tokenTypes) public  returns (bytes32){
    function mintNFT( uint tokenTypes, bool takeMoney) internal  returns (bytes32){
//        require (getSigner(sustain) == designatedSigner,'!Signer');
//        require (sustain.userAddress == msg.sender,'!User');
//        require (sustain.nonce + 10 minutes > block.timestamp,'Signature Expired');
//        require (!nonceUsed[sustain.userAddress][sustain.nonce],'Nonce Used Already');
//        nonceUsed[sustain.userAddress][sustain.nonce] = true;
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        bytes32 data = requestRandomness(keyHash, fee);
        mintFromReward[data] = takeMoney;
        requestToTokenTypeMap[data] = tokenTypes;
        requestToUserMap[data] = msg.sender;
        return data;
    }


    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
            requestToRandomNumber [requestId] = randomness;
            uint tokenType = requestToTokenTypeMap[requestId];
            uint tokenId = getTokenNumber(tokenType ,randomness);
            tokentier[tokenId] = tokenType;
            tokenTaken[tokenId] = true;
            if (!mintFromReward[requestId])
            token.transferFrom(requestToUserMap[requestId],address(this),tokentierToPrice[tokenType]);
            lastClaimTime[tokenId] = block.timestamp;
            _mint(requestToUserMap[requestId],tokenId);
    }

    function getTokenNumber(uint tokenTier, uint _randomNumber) internal view returns (uint) {
        uint randomNumber;
        randomNumber = _randomNumber;
        randomNumber = (randomNumber % 5000) + tokenIdToTokenAllocation[tokenTier];

        bool status;
        while(!status){

            if (!tokenTaken[randomNumber]){
                    status = true;
            }
            else{
                randomNumber++;
            }
        }
        return randomNumber;
    }


    function getRewards(uint[] memory tokenIds, address user) public view returns(uint){
        uint totalRewardGenerated;
        for (uint i=0;i< tokenIds.length;i++) {
                require (user == ownerOf(tokenIds[i]),'!Owner');
                uint timeDelta = (block.timestamp - lastClaimTime[tokenIds[i]])/ rebaseTime ;
                uint rewardGenerated = ((timeDelta * rewardRate[tokentier[tokenIds[i]]])* 1 ether) / delta;
                totalRewardGenerated += rewardGenerated;
                totalRewardGenerated += outstandingBalances[user][tokenIds[i]];
        }
        return totalRewardGenerated;
    }

    function claimReward(uint[] memory tokenIds) external {
        uint totalRewardGenerated = getRewards(tokenIds, msg.sender);
        for (uint i=0;i<tokenIds.length;i++){
            lastClaimTime[tokenIds[i]] = block.timestamp;
            outstandingBalances[msg.sender][tokenIds[i]] = 0;
        }
        require (totalRewardGenerated > 0,'No rewards generated');
        token.transfer(msg.sender, totalRewardGenerated);
    }
    // user => tokenId => balance

//    function mintTokensFromReward (Sustain memory sustain, uint _tokenTier) external {
    function mintTokensFromReward (uint _tokenTier, uint tokenId) external {
            uint[] memory tokenIds = new uint[](1);
//            uint[] memory tokenTier= new uint[](1);
//            tokenIds[0] = sustain.tokenId;
            tokenIds[0] = tokenId;
//            tokenTier[0] = _tokenTier[0];
//            require(getRewards(tokenIds,sustain.userAddress)>tokentierToPrice[_tokenTier],'Minimum amount not satisfied');
//            uint amount = getRewards(tokenIds,msg.sender);
//            uint amount = getRewards(tokenId,msg.sender);
            uint amount = getRewards(tokenIds,msg.sender);
            uint price = amount - tokentierToPrice[_tokenTier];
            outstandingBalances[msg.sender][tokenId] += price;
//            token.transfer(msg.sender,amount);
//            lastClaimTime[sustain.tokenId] = block.timestamp;
            lastClaimTime[tokenId] = block.timestamp;
//            mintNFT(sustain,_tokenTier);
            mintNFT(_tokenTier,true);
        }


    function randomNumberGenerator (uint _randomNumber, uint nonce) internal returns (uint) {
        uint randomNumber = uint(keccak256(abi.encodePacked(block.number, block.difficulty,  _randomNumber, nonce)));
        randomNonce = string(abi.encodePacked(block.number, block.difficulty, randomNonce));
        return randomNumber;
    }

    function addDesignatedSigner(address _signer) external onlyOwner {
        designatedSigner = _signer;
    }

    function setTokenType(address _type) external onlyOwner {
        token = IERC20Upgradeable(_type);
    }

    function withDrawToken () external onlyOwner {
        token.transfer(owner(),token.balanceOf(address(this)));
    }

    function changeRebaseTime (uint time) external onlyOwner {
            rebaseTime = time;
        }

    function setDelta(uint time) external onlyOwner {
        delta = time;
    }

    function changeRewardRate(uint[] memory rates) external onlyOwner {
        rewardRate = rates;
    }

    function setBaseURI(string memory baseURI_) public onlyOwner {
        require(bytes(baseURI_).length > 0, "Invalid base URI");
        baseTokenURI = baseURI_;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

}

