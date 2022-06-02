//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "./SustainSigner.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
contract SustainNFT is SustainSigner, OwnableUpgradeable, ERC721Upgradeable, VRFConsumerBase{


    uint64 s_subscriptionId;
    uint256[] public s_randomWords;
    uint256 public s_requestId;
    address s_owner;
    address public designatedSigner;
    IERC20Upgradeable token;
    string randomNonce;
    uint public rebaseTime;
    bool isMinted;
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

    mapping (bytes32 => uint[]) public requestToTokenTypeMap;
    mapping (bytes32 => address) public requestToUserMap;

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
            address _designatedSigner
            ) external initializer {
                __ERC721_init(name,symbol);
                __Ownable_init();
                __SustainSigner_init(domain, version);
                designatedSigner = _designatedSigner;
                token = IERC20Upgradeable(_tokenAddress);
                randomNonce = string(abi.encodePacked(domain,symbol,name,version));
                rewardRate= [0,10,25,50];
                tokentierToPrice= [0,10 ether, 25 ether, 50 ether];
                tokenIdToTokenAllocation= [0,0,5000,10000];
                requestConfirmations = 3;
                __VRFInit_(0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed,0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
                keyHash = 0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;
                fee = 0.0005 ether;
                vrfCoordinator = 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed;
            }


    function getRandomNumber(Sustain memory sustain, uint[] memory tokenTypes) public  returns (bytes32){
        require (getSigner(sustain) == designatedSigner,'!Signer');
        require (sustain.userAddress == msg.sender,'!User');
        require (sustain.nonce + 10 minutes > block.timestamp,'Signature Expired');
        require (!nonceUsed[sustain.userAddress][sustain.nonce],'Nonce Used Already');
        nonceUsed[sustain.userAddress][sustain.nonce] = true;
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        bytes32 data = requestRandomness(keyHash, fee);
        requestToTokenTypeMap[data] = tokenTypes;
        requestToUserMap[data] = msg.sender;
        return data;
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        uint randomNumbersRequired = requestToTokenTypeMap[requestId].length;
        uint[] memory randomNumbers;
        for (uint i =0;i<randomNumbersRequired;i++) {
            uint number = randomNumberGenerator(randomness,i);
            randomNumbers[i] = number;
        }
        _giveTokens(requestToUserMap[requestId],requestToTokenTypeMap[requestId],randomNumbers);
    }

    function _giveTokens(address _user, uint[] memory tokenTypes, uint[] memory randomNumbers) public {
        for (uint i=0;i< tokenTypes.length;i++){
                uint tokenId = getTokenNumber(tokenTypes[i],randomNumbers[i]);
                tokentier[tokenId] = tokenTypes[i];
                tokenTaken[tokenId] = true;
                token.transferFrom(_user,address(this),tokentierToPrice[tokenTypes[i]]);
                _mint(_user,tokenId);
        }
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
        getRandomNumber(sustain,tokenTier);
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

    function changeSubscriptionID (uint64 id) external onlyOwner {
        s_subscriptionId = id;
    }

    function changeRebaseTime (uint time) external onlyOwner {
        rebaseTime = time;
    }

    function changeToken(address _tokenAddress) external onlyOwner {
        token = IERC20Upgradeable(_tokenAddress);
    }
}

