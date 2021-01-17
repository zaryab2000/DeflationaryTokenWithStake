// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 *
*/

library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }

  function ceil(uint a, uint m) internal pure returns (uint r) {
    return (a + m - 1) / m * m;
  }
}

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
        require(msg.sender == owner);
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
abstract contract ERC20Interface {
    function totalSupply() public virtual view returns (uint);
    function balanceOf(address tokenOwner) public virtual view returns (uint256 balance);
    function allowance(address tokenOwner, address spender) public virtual view returns (uint256 remaining);
    function transfer(address to, uint256 tokens) public virtual returns (bool success);
    function approve(address spender, uint256 tokens) public virtual returns (bool success);
    function transferFrom(address from, address to, uint256 tokens) public virtual returns (bool success);

    event Transfer(address indexed from, address indexed to, uint256 tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint256 tokens);
}


// ----------------------------------------------------------------------------
// 'Infinity Yeild Token' token contract

// Symbol      : IFY
// Name        : Infinity Yeild Token
// Total supply: 250,000 (250 Thousand)
// Decimals    : 18
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// ERC20 Token, with the addition of symbol, name and decimals and assisted
// token transfers
// ----------------------------------------------------------------------------
contract Token is ERC20Interface, Owned {
    using SafeMath for uint256;

    string public symbol = "IFY";
    string public  name = "Infinity Yeild";

    uint256 public decimals = 18;
    uint256 _totalSupply = 250000 * 10 ** (decimals);
    uint256 deployTime;
    uint256 private totalDividentPoints;
    uint256 private unclaimedDividendPoints;
    uint256 private pointMultiplier = 1000000000000000000;
    uint256 public stakedCoins;
    uint256 public tax = 5;

    struct  Account {
        uint256 balance;
        uint256 lastDividentPoints;
        uint256 lastClaimed;
        uint256 old;
    }

    mapping(address => Account) accounts;
    mapping(address => bool) isInvertor;
    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowed;

    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    constructor() public {
        owner = msg.sender;

        balances[owner] = totalSupply();
        emit Transfer(address(0), owner, totalSupply());

    }
    
    function changeTax(uint256 _newTax) external onlyOwner{
        tax = _newTax;    
    }
    
    function Stake(uint256 _tokens) external returns(bool){
        require(transfer(address(this), _tokens), "Insufficient Funds!");
        uint256 owing = 0;
        if (isInvertor[msg.sender] == true){
            owing = dividendsOwing(msg.sender);
        }
        isInvertor[msg.sender] = true;
        stakedCoins = stakedCoins.add(_tokens);
        accounts[msg.sender].balance = accounts[msg.sender].balance.add(_tokens);
        accounts[msg.sender].lastDividentPoints = totalDividentPoints;
        accounts[msg.sender].old = owing;
        return true;
    }

    function updateDividend(address investor) internal returns(uint256) {
        uint256 owing = dividendsOwing(investor);
        if (owing > 0){
            unclaimedDividendPoints = unclaimedDividendPoints.sub(owing.add(accounts[msg.sender].old));
            accounts[investor].lastDividentPoints = totalDividentPoints;
        }
        return owing;
    }

    function StakedTokens(address _user) external view returns (uint256){
        return accounts[_user].balance;
    }

    function UnStake() external returns (bool){
        require(isInvertor[msg.sender] == true, "Sorry!, Not investor");
        require(stakedCoins > 0);

        stakedCoins = stakedCoins.sub(accounts[msg.sender].balance);

        uint256 owing = updateDividend(msg.sender);
        

        require(_transfer(msg.sender, owing.add(accounts[msg.sender].balance).add(accounts[msg.sender].old) ));

        isInvertor[msg.sender] = false;
        accounts[msg.sender].balance = 0;
        accounts[msg.sender].old = 0;
        return true;
    }


    function disburse(uint256 amount) internal{
        balances[address(this)] = balances[address(this)].add(amount);
        uint256 unnormalized = amount.mul(pointMultiplier);
        totalDividentPoints = totalDividentPoints.add(unnormalized.div(stakedCoins));
        unclaimedDividendPoints = unclaimedDividendPoints.add(amount);
    }

    function dividendsOwing(address investor) internal view returns (uint256){
        uint256 newDividendPoints = totalDividentPoints.sub(accounts[investor].lastDividentPoints);
        return ((accounts[investor].balance).mul(newDividendPoints)).div(pointMultiplier);
    }

    function ClaimReward() public returns(bool){
        require(isInvertor[msg.sender] == true, "Sorry!, Not an investor");
        require(accounts[msg.sender].balance > 0);

        uint256 owing = updateDividend(msg.sender);

        require(_transfer(msg.sender, owing.add(accounts[msg.sender].old)));
        accounts[msg.sender].old = 0;

        return true;
    }

    /** ERC20Interface function's implementation **/

    function totalSupply() public override view returns (uint256){
       return _totalSupply;
    }

    // ------------------------------------------------------------------------
    // Calculates onePercent of the uint256 amount sent
    // ------------------------------------------------------------------------
    function onePercent(uint256 _tokens) internal pure returns (uint256){
        uint256 roundValue = _tokens.ceil(100);
        uint onePercentofTokens = roundValue.mul(100).div(100 * 10**uint(2));
        return onePercentofTokens;
    }

    // ------------------------------------------------------------------------
    // Get the token balance for account `tokenOwner`
    // ------------------------------------------------------------------------
    function balanceOf(address tokenOwner) public override view returns (uint256 balance) {
        return balances[tokenOwner];
    }

    // ------------------------------------------------------------------------
    // Transfer the balance from token owner's account to `to` account
    // - Owner's account must have sufficient balance to transfer
    // - 0 value transfers are allowed
    // ------------------------------------------------------------------------
    function transfer(address to, uint256 tokens) public override returns (bool success) {
        require(address(to) != address(0));
        require(balances[msg.sender] >= tokens);
        require(balances[to] + tokens >= balances[to]);

        balances[msg.sender] = balances[msg.sender].sub(tokens);
        uint256 deduction = 0;
        if ( ( address(to) != address(this) ) && stakedCoins != 0 )   {
            deduction = onePercent(tokens).mul(tax);
            disburse(deduction);
        }
        balances[to] = balances[to].add(tokens.sub(deduction));
        emit Transfer(msg.sender, to, tokens.sub(deduction));
        return true;
    }

    // ------------------------------------------------------------------------
    // Token owner can approve for `spender` to transferFrom(...) `tokens`
    // from the token owner's account
    // ------------------------------------------------------------------------
    function approve(address spender, uint256 tokens) public override returns (bool success){
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender,spender,tokens);
        return true;
    }

    // ------------------------------------------------------------------------
    // Transfer `tokens` from the `from` account to the `to` account
    //
    // The calling account must already have sufficient tokens approve(...)-d
    // for spending from the `from` account and
    // - From account must have sufficient balance to transfer
    // - Spender must have sufficient allowance to transfer
    // - 0 value transfers are allowed
    // ------------------------------------------------------------------------
    function transferFrom(address from, address to, uint256 tokens) public override returns (bool success){
        require(tokens <= allowed[from][msg.sender]); //check allowance
        require(balances[from] >= tokens);
        balances[from] = balances[from].sub(tokens);
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);

        uint256 deduction = 0;
        if ( ( ( to != address(this) ) || ( from != address(this) ) ) && stakedCoins != 0 ){
            deduction = onePercent(tokens).mul(tax);
            disburse(deduction);
        }
        balances[to] = balances[to].add(tokens.sub(deduction));
        emit Transfer(from, to, tokens.sub(tokens));
        return true;
    }

    function _transfer(address to, uint256 tokens) internal returns(bool){
        // prevent transfer to 0x0, use burn instead
        require(address(to) != address(0));
        require(balances[address(this)] >= tokens );
        require(balances[to] + tokens >= balances[to]);

        balances[address(this)] = balances[address(this)].sub(tokens);
        balances[to] = balances[to].add(tokens);

        emit Transfer(address(this), to, tokens);
        return true;
    }
    // ------------------------------------------------------------------------
    // Returns the amount of tokens approved by the owner that can be
    // transferred to the spender's account
    // ------------------------------------------------------------------------
    function allowance(address tokenOwner, address spender) public override view returns (uint256 remaining) {
        return allowed[tokenOwner][spender];
    }

}
