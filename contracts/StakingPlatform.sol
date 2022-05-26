pragma solidity ^0.8.0;
import "./IERC721A.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
contract StakingPlatform is OwnableUpgradeable, ReentrancyGuardUpgradeable {

    IERC721A nft;
    IERC20Upgradeable rewardToken;
    address public signer;

    struct tokenInfo {
        uint stakeTime;
        uint lastClaimTime;
        address owner;
    }


    mapping (uint => address) public tokenOwner;
    mapping (address => uint[]) public tokensStakedPerOwner;
    mapping (uint => tokenInfo) public stakeInfo;

    function initialize(address _nftAddress, address _rewardAddress, address _signer) external initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        nft = IERC721A(nft);
        rewardToken = IERC20Upgradeable(_rewardAddress);
        signer = _signer;
    }

    function stakeTokens (uint[] memory tokenIds) external {
        for (uint i = 0; i< tokenIds.length; i++) {
            require (nft.ownerOf(tokenIds[i])==msg.sender,'!Owner');
            tokenOwner[tokenIds[i]] = msg.sender;
            tokensStakedPerOwner[msg.sender].push(tokenIds[i]);
            tokenInfo memory info;
            info.owner = msg.sender;
            info.stakeTime = block.timestamp;
            info.lastClaimTime = block.timestamp;
            stakeInfo[tokenIds[i]] = info;
            nft.safeTransferFrom(msg.sender, address(this), tokenIds[i]);
        }
    }

    function claimRewards(uint[] memory tokenIds ) public {
        uint finalAmount;
        for (uint i=0;i< tokenIds.length;i++) {
            require (tokenOwner[tokenIds[i]]==msg.sender,'!Owner');
            finalAmount = getRewards(tokenIds[i]);
        }
    }

    function getRewards(uint tokenId) public view returns(uint) {
        return amount;
    }

}
