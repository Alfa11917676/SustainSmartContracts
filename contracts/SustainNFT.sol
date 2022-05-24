//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
//import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./ERC721AUpgradeable.sol";
import "./SustainSigner.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
contract SustainNFT is SustainSigner, OwnableUpgradeable, ERC721AUpgradeable, VRFConsumerBaseV2{
    VRFCoordinatorV2Interface COORDINATOR;

    uint64 s_subscriptionId;


    uint256[] public s_randomWords;
    uint256 public s_requestId;
    address s_owner;



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

    mapping (uint => uint[]) public requestToTokenTypeMap;
    mapping (uint => address) public requestToUserMap;

    bytes32  internal keyHash;// = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
    uint256  internal fee;// = 0.0001 * 10 **18;
    address vrfCoordinator; // = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;
    uint32 callbackGasLimit; //= 100000;
    uint16 requestConfirmations;// = 3;

    function initialize (
        string memory domain,
        string memory version,
        string memory name,
        string memory symbol,
        address _tokenAddress,
        address _designatedSigner,
        uint64 subscriptionId) external initializer {
        __Ownable_init();
        __ERC721A_init(name,symbol);
        __SustainSigner_init(domain, version);
        designatedSigner = _designatedSigner;
        token = IERC20Upgradeable(_tokenAddress);
        randomNonce = string(abi.encodePacked(domain,symbol,name,version));
        rewardRate= [0,10,25,50];
        tokentierToPrice= [0,10 ether, 25 ether, 50 ether];
        tokenIdToTokenAllocation= [0,0,5000,10000];
        requestConfirmations = 3;
        keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
        fee = 0.0001 * 10 **18;
        vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;
        callbackGasLimit = 100000;
        __Chianlink_init(vrfCoordinator);
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
        _mint(owner(),14999);
    }

    function requestRandomWords(uint32 randomNumbersRequired,Sustain memory sustain, uint[] memory tokenTypes) public {

        require (getSigner(sustain) == designatedSigner,'!Signer');
        require (sustain.userAddress == msg.sender,'!User');
        require (sustain.nonce + 10 minutes > block.timestamp,'Signature Expired');
        require (!nonceUsed[sustain.userAddress][sustain.nonce],'Nonce Used Already');
        nonceUsed[sustain.userAddress][sustain.nonce] = true;
        s_requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            randomNumbersRequired
        );
        requestToTokenTypeMap[s_requestId] = tokenTypes;
        requestToUserMap[s_requestId] = msg.sender;
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        s_randomWords = randomWords;
        _giveTokens(requestToUserMap[requestId],requestToTokenTypeMap[requestId],randomWords);
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
                token.transferFrom(_user,address(this),tokentierToPrice[tokenTypes[i]]);
                safeTransferFrom(owner(),_user,tokenId);
        }
    }

    function getTokenNumber(uint tokenTier, uint _randomNumber) internal view returns (uint) {
        uint randomNumber;
        randomNumber = _randomNumber;
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

    function mintTokensFromReward (Sustain memory sustain, uint _tokenTier) external {
        uint[] memory tokenId;
        uint[] memory tokenTier;
        tokenId[0] = sustain.tokenId;
        tokenTier[0] = _tokenTier;
        require(getRewards(tokenId,sustain.userAddress)>tokentier[sustain.tokenId],'Minimum amount not satisfied');
        require (msg.sender == sustain.userAddress,'!User');
        require (sustain.nonce + 10 minutes > block.timestamp,'Signature Expired');
        uint amount = getRewards(tokenId,sustain.userAddress);
        token.transfer(msg.sender,amount-tokentier[sustain.tokenId]);
        lastClaimTime[sustain.tokenId] = block.timestamp;
        requestRandomWords(1,sustain,tokenTier);
    }

    function addDesignatedSigner(address _signer) external onlyOwner {
        designatedSigner = _signer;
    }

    function setTokenType(address _type) external onlyOwner {
        token = IERC20Upgradeable(_type);
    }

//    function randomNumberGenerator () internal returns (uint) {
//        uint randomNumber = uint(keccak256(abi.encodePacked(block.number, block.difficulty, randomNonce)));
//        randomNonce = string(abi.encodePacked(block.number, block.difficulty, randomNonce));
//        return randomNumber;
//    }

    function withDrawToken () external onlyOwner {
        token.transfer(owner(),token.balanceOf(address(this)));
    }
}
