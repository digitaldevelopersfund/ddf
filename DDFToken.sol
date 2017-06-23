pragma solidity ^0.4.11;
import "./StandardToken.sol";
import "./SafeMath.sol";
import "./splitter.sol";

// note introduced onlyPayloadSize in StandardToken.sol to protect against short address attacks



contract DDFToken is StandardToken, SafeMath {

    // metadata
    string public constant name = "Digital Developers Fund Token";
    string public constant symbol = "DDF";
    uint256 public constant decimals = 18;
    string public version = "1.0";

    // contracts
    address public ethFundDeposit;      // deposit address for ETH for Domain Development Fund
    address public ddftFundDeposit;     // deposit address for Domain Development Fund reserve
    address public splitter;          // DA 8/6/2017 - splitter contract

    // crowdsale parameters
    bool public isFinalized;              // switched to true in operational state
    uint256 public fundingStartTime;
    uint256 public fundingEndTime;
    uint256 public constant ddftFund = 1 * (10**6) * 10**decimals;   // 1m DDFT reserved for DDF use
    uint256 public constant tokenExchangeRate = 1000;               // 1000 DDFT tokens per 1 ETH
    uint256 public constant tokenCreationCap =  250 * (10**6) * 10**decimals;
    uint256 public constant tokenCreationMin =  1 * (10**6) * 10**decimals;


    // events
    event LogRefund(address indexed _to, uint256 _value);
    event CreateDDFT(address indexed _to, uint256 _value);

    // constructor
    function DDFToken(
        address _ethFundDeposit,
        address _ddftFundDeposit,
        address _splitter, // DA 8/6/2017
        uint256 _fundingStartTime,
        uint256 duration)
    {
      isFinalized = false;                   //controls pre through crowdsale state
      ethFundDeposit = _ethFundDeposit;
      ddftFundDeposit = _ddftFundDeposit;
      splitter =  _splitter ;                  // DA 8/6/2017
      fundingStartTime = _fundingStartTime;
      fundingEndTime = fundingStartTime + duration * 1 days;
      totalSupply = ddftFund;
      balances[ddftFundDeposit] = ddftFund;    // Deposit DDF share
      CreateDDFT(ddftFundDeposit, ddftFund);  // logs DDF fund
    }

    function () payable {           // DA 8/6/2017 prefer to use fallback function
      createTokens(msg.value);
    }

    /// @dev Accepts ether and creates new DDFT tokens.
    function createTokens(uint256 _value)  internal {
      if (isFinalized) throw;
      if (now < fundingStartTime) throw;
      if (now > fundingEndTime) throw;
      if (msg.value == 0) throw;

      uint256 tokens = safeMult(_value, tokenExchangeRate); // check that we're not over totals
      uint256 checkedSupply = safeAdd(totalSupply, tokens);

      // DA 8/6/2017 to fairly allocate the last few tokens
      if (tokenCreationCap < checkedSupply) {
        if (tokenCreationCap <= totalSupply) throw;  // CAP reached no more please
        uint256 tokensToAllocate = safeSubtract(tokenCreationCap,totalSupply);
        uint256 tokensToRefund   = safeSubtract(tokens,tokensToAllocate);
        totalSupply = tokenCreationCap;
        balances[msg.sender] += tokensToAllocate;  // safeAdd not needed; bad semantics to use here
        uint256 etherToRefund = tokensToRefund / tokenExchangeRate;
        msg.sender.transfer(etherToRefund);
        CreateDDFT(msg.sender, tokensToAllocate);  // logs token creation
        LogRefund(msg.sender,etherToRefund);
        splitterContract(splitter).update(msg.sender,balances[msg.sender]);
        return;
      }
      // DA 8/6/2017 end of fair allocation code
      totalSupply = checkedSupply;
      balances[msg.sender] += tokens;  // safeAdd not needed; bad semantics to use here
      CreateDDFT(msg.sender, tokens);  // logs token creation
      splitterContract(splitter).update(msg.sender,balances[msg.sender]);
    }

    /// @dev Ends the funding period and sends the ETH home
    function finalize() external {
      if (isFinalized) throw;
      if (msg.sender != ethFundDeposit) throw; // locks finalize to the ultimate ETH owner
      if(totalSupply < tokenCreationMin + ddftFund) throw;      // have to sell minimum to move to operational
      if(now <= fundingEndTime && totalSupply != tokenCreationCap) throw;
      // move to operational
      isFinalized = true;
      // DA 8/6/2017 change send/throw to transfer
      ethFundDeposit.transfer(this.balance);  // send the eth to DDF
    }

    /// @dev Allows contributors to recover their ether in the case of a failed funding campaign.
    function refund() external {
      if(isFinalized) throw;                       // prevents refund if operational
      if (now <= fundingEndTime) throw; // prevents refund until sale period is over
      if(totalSupply >= tokenCreationMin + ddftFund) throw;  // no refunds if we sold enough
      if(msg.sender == ddftFundDeposit) throw;    // DDF not entitled to a refund
      uint256 ddftVal = balances[msg.sender];
      if (ddftVal == 0) throw;
      balances[msg.sender] = 0;
      totalSupply = safeSubtract(totalSupply, ddftVal); // extra safe
      uint256 ethVal = ddftVal / tokenExchangeRate;     // should be safe; previous throws covers edges
      LogRefund(msg.sender, ethVal);               // log it 
      // DA 8/6/2017 change send/throw to transfer
      msg.sender.transfer(ethVal);                 // if you're using a contract; make sure it works with .send gas limits
    }

    // DA 8/6/2017
    /// @dev Updates splitter contract with ownership changes
    function transfer(address _to, uint _value) returns (bool success)  {
      success = super.transfer(_to,_value);
      splitterContract sc = splitterContract(splitter);
      sc.update(msg.sender,balances[msg.sender]);
      sc.update(_to,balances[_to]);
      return;
    }

}
