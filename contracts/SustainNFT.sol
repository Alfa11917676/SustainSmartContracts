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
    mapping (address => mapping (uint => bool)) public nonceUsed;
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
        _mint(owner(),14999);
    }

    function _giveTokens(Sustain memory sustain, uint[] memory randomNumber, uint[] memory tokenTypes) external {
        require (getSigner(sustain) == designatedSigner,'!Signer');
        require (msg.sender == sustain.userAddress,'!User');
        require (!nonceUsed[msg.sender][sustain.nonce],'Nonce Used Already');
        for (uint i=0;i< tokenTypes.length;i++){
            if (tokenTypes[i]==1){
                token.transferFrom(sustain.userAddress,address(this),10 ether);
                safeTransferFrom(owner(),sustain.userAddress,randomNumber[i]%5000);
            }
            else if (tokenTypes[i]==2){
                token.transferFrom(sustain.userAddress,address(this),20 ether);
                safeTransferFrom(owner(),sustain.userAddress,randomNumber[i]%10000);
            }
            else if (tokenTypes[i]==3){
                token.transferFrom(sustain.userAddress,address(this),50 ether);
                safeTransferFrom(owner(),sustain.userAddress,randomNumber[i]%15000);
            }
            else {
                revert('Wrong tokentype');
                }
        }
    }

    function addDesignatedSigner(address _signer) external onlyOwner {
        designatedSigner = _signer;
    }

    function setTokenType(address _type) external onlyOwner {
        token = IERC20Upgradeable(_type);
    }

    function withDrawToken () external onlyOwner {
        token.transferFrom(address(this),owner(),token.balanceOf(address(this)));
    }
}
