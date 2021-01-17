pragma solidity ^0.6.0;

// SPDX-License-Identifier: UNLICENSED

// ----------------------------------------------------------------------------
// Owned contract
// ----------------------------------------------------------------------------
contract Owned {
    address payable public owner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Only allowed by owner");
        _;
    }

    function transferOwnership(address payable _newOwner) public onlyOwner {
        owner = _newOwner;
        emit OwnershipTransferred(msg.sender, _newOwner);
    }
}

// ----------------------------------------------------------------------------
// ERC Token Standard #20 Interface
// https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
// ----------------------------------------------------------------------------
/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract PreSale is Owned {

    address tokenAdd;
    uint256 startSale = 1611774000; // 27 January 2021, 7pm GMT
    uint256 endSale = 1612378800; // 3 Feb 2021, 7pm GMT
    uint256 claimDate = 1612382400; // 3 Feb 2021, 8pm GMT

    mapping(address => uint256) investor;

    constructor(address _tokenAddress) public {
        tokenAdd = _tokenAddress;
    }
    
    receive() external payable{
        Invest();
    }
    
    function Invest() public payable{
        require( now > startSale && now < endSale , "Sale is closed");
        uint256 tokens = getTokenAmount(msg.value);
        investor[msg.sender] = tokens;
        owner.transfer(msg.value);
    }

    function getTokenAmount(uint256 amount) internal view returns(uint256){
        uint256 _tokens = 0;
        if (now <= startSale + 3 days){
            _tokens = amount * 100;
        }
        if (now > startSale + 3 days){
            _tokens = amount * 80;
        }
        return _tokens;
    }

    function ClaimTokens() external returns(bool){
        require(now >= claimDate, "Token claim date not reached");
        require(investor[msg.sender] > 0, "Not an investor");
        uint256 tokens = investor[msg.sender];
        investor[msg.sender] = 0;
        require(IERC20(tokenAdd).transfer(msg.sender, tokens));
        return true;
    }
}
