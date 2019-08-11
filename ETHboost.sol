pragma solidity ^0.5.0;

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
    uint256 c = a / b;
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

  function ceil(uint256 a, uint256 m) internal pure returns (uint256) {
    uint256 c = add(a,m);
    uint256 d = sub(c,1);
    return mul(div(d,m),m);
  }
}

interface ERC20Interface {
    function totalSupply() external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


// ----------------------------------------------------------------------------
// Contract function to receive approval and execute function in one call
// Borrowed from MiniMeToken
// ----------------------------------------------------------------------------
contract ApproveAndCallFallBack {
    function receiveApproval(address from, uint256 tokens, address token, bytes memory data) public;
}

contract Owned {
    address public owner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
}

contract ETHboost is ERC20Interface, Owned {
    using SafeMath for uint256;

    string public symbol;
    string public name;
    uint8 public decimals;
    uint256 _totalSupply;
    uint256 stopBurnAt;

    mapping(address => uint256) _balances;
    mapping(address => mapping(address => uint256)) _allowed;

    constructor() public {
        symbol = "BOOST";
        name = "ETHboost";
        decimals = 4;
        _totalSupply = 200000000 * 10**uint(decimals);
        stopBurnAt = 101000 * 10**uint(decimals);

        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address owner) public view returns (uint256 balance) {
        return _balances[owner];
    }

    function getBurnValue(uint256 value) public view returns (uint256)  {
        if (!isBurnAllowed()) {
            return 0;
        }
        
        // 1.5%
        return value * 15 / 1000;
    }
    
    function isBurnAllowed() public view returns (bool) {
        return _totalSupply >= stopBurnAt;
    }
    
    function transfer(address to, uint256 value) public returns (bool) {
        require(value <= _balances[msg.sender]);
        require(to != address(0));

        uint256 tokensToBurn = getBurnValue(value);
        uint256 tokensToTransfer = value.sub(tokensToBurn);

        _balances[msg.sender] = _balances[msg.sender].sub(value);
        _balances[to] = _balances[to].add(tokensToTransfer);

        _totalSupply = _totalSupply.sub(tokensToBurn);

        emit Transfer(msg.sender, to, tokensToTransfer);
        // Burn by sending to an inaccessible address.
        if (isBurnAllowed()) {
            emit Transfer(msg.sender, address(0), tokensToBurn);
        }

        return true;
    }

    function approve(address spender, uint256 value) public returns (bool) {
        require(spender != address(0));
        _allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        require(value <= _balances[from]);
        require(value <= _allowed[from][msg.sender]);
        require(to != address(0));

        _balances[from] = _balances[from].sub(value);

        uint256 tokensToBurn = getBurnValue(value);
        uint256 tokensToTransfer = value.sub(tokensToBurn);

        _balances[to] = _balances[to].add(tokensToTransfer);
        _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);

        _totalSupply = _totalSupply.sub(tokensToBurn);

        emit Transfer(from, to, tokensToTransfer);
        if (isBurnAllowed()) {
            emit Transfer(from, address(0), tokensToBurn);
        }

        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowed[owner][spender];
    }

    function approveAndCall(address spender, uint256 tokens, bytes memory data) public returns (bool success) {
        _allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        ApproveAndCallFallBack(spender).receiveApproval(msg.sender, tokens, address(this), data);
        return true;
    }

    // Don't accept ETH transactions.
    function () external payable {
        revert();
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }
}