//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
contract rewardToken is ERC20, ChainlinkClient, Ownable {
    using Chainlink for Chainlink.Request;

    // uint256 public volume;

    string url;
    address private oracle;
    bytes32 private jobId;
    uint public finalSupply;
    uint public totalMinted;
    uint256 private fee;
    mapping (address =>  bytes32[]) public totalRequestsMade;
    //@dev this is used to store the amount received from oracle to the bytes
    mapping (bytes32 => uint) public bytesToData;
    //@dev stores address of the user who made the api requests
    mapping (bytes32 => address) public requestDataToAddress;
    //@dev checks whether a request generated is already used or not
    mapping (bytes32 => bool) public requestChecker;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        setPublicChainlinkToken();
        url = "https://fantompadbackend.click/randomnumber?wallet=";
        oracle = 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8;
        jobId = "d5270d1c311941d0b08bead21fea7747";
        fee = 0.1 * 10 ** 18; // (Varies by network and job)
    }

    function requestVolumeData(string memory dataUrl) public returns (bytes32 requestId)
    {
        require (keccak256(abi.encodePacked(msg.sender)) == keccak256(abi.encodePacked(dataUrl)),'Not user');
        string memory finalUrl = string(abi.encodePacked(url,dataUrl));
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        request.add("get", finalUrl);
        request.add("path", "result,0,refundamount");
        bytes32 byteData = sendChainlinkRequestTo(oracle, request, fee);
        requestDataToAddress[bytes32(byteData)] = msg.sender;
        totalRequestsMade[msg.sender].push(byteData);
        return byteData;
    }

    function fulfill(bytes32 _requestId, uint256 amount) public recordChainlinkFulfillment(_requestId)
    {
        bytesToData[bytes32(_requestId)] = amount;
        address _to = requestDataToAddress[_requestId];
        tokenMinter(_to, amount, _requestId);
    }

    function tokenMinter(address _sender, uint _amount, bytes32 _request) internal {
        require (msg.sender != _sender,'You cannot initiate the transaction');
        require (!requestChecker[_request], 'Request already used');
        require (finalSupply >= totalMinted+_amount/100,'Supply Over');
        requestChecker[_request] = true;
        uint amount = _amount/100;
        totalMinted += amount;
        _mint(_sender,amount);
    }

    function burnToken(uint _amount) external {
        totalMinted -= _amount;
        _burn(msg.sender, _amount);
    }

    function setFinalLimit(uint amount) external onlyOwner {
        finalSupply = amount;
    }
}