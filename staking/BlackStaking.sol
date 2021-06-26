
// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.6/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.6/contracts/utils/Context.sol";
import "https://github.com/binance-chain/bsc-genesis-contract/blob/master/contracts/interface/IBEP20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.6/contracts/utils/Address.sol";
//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.6/contracts/access/Ownable.sol";
//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.6/contracts/proxy/Initializable.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context {
    address public _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function initialize () public virtual {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}



contract Initializable  {

  /**
   * @dev Indicates that the contract has been initialized.
   */
  bool private initialized;

  /**
   * @dev Indicates that the contract is in the process of being initialized.
   */
  bool private initializing;

  /**
   * @dev Modifier to use in the initializer function of a contract.
   */
  modifier initializer() {
    require(initializing || isConstructor() || !initialized, "Contract instance has already been initialized");

    bool isTopLevelCall = !initializing;
    if (isTopLevelCall) {
      initializing = true;
      initialized = true;
    }

    _;

    if (isTopLevelCall) {
      initializing = false;
    }
  }

  /// @dev Returns true if and only if the function is running in the constructor
  function isConstructor() private view returns (bool) {
    // extcodesize checks the size of the code stored in an address, and
    // address returns the current address. Since the code is still not
    // deployed when running a constructor, any checks on its code size will
    // yield zero, making it an effective way to detect if a contract is
    // under construction or not.
    address self = address(this);
    uint256 cs;
    assembly { cs := extcodesize(self) }
    return cs == 0;
  }

  // Reserved storage space to allow for layout changes in the future.
  uint256[50] private ______gap;
}

contract MasterChef is Context,Ownable,Initializable {
    using SafeMath for uint256;
 

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of BLACKs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accBlackPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accBlackPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. BLACKs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that BLACKs distribution occurs.
        uint256 accBlackPerShare; // Accumulated BLACKs per share, times 1e9. See below.
    }

    // The BLACK TOKEN!
    IBEP20 public black;
   
    // Dev address.
    address public communitywallet;
    // BLACK tokens created per block.
    uint256 public blackPerBlock;
    // Bonus muliplier for early black makers.
    uint256 public BONUS_MULTIPLIER;
    // Info of each pool.
    PoolInfo public poolInfo;
    
    // Info of each user that stakes LP tokens.
    mapping  (address => UserInfo) public userInfo;
    
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when BLACK mining starts.
    uint256 public startBlock;
    //Todo maxlimit may be change
    uint256 public constant  maxStakeAmount = 1000000 * 10**9;
    //Todo lockperiod may be change 
    uint256 public constant lockPeriod = 2 weeks;
    //Todo withdrawLockupPeriod may be change 
    uint256 public constant withdrawLockupPeriod = 1 days;
    uint256 public startTime;
    uint256 public rewardStartdate;
    //Todo maxrewardlimit fixed
    uint256 public rewardAmount;
    
    mapping(address => uint256) private stakelock;
    mapping (address => uint256) private unLockTime;
    mapping(address => uint256) private stakeBalance ;
    
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user,  uint256 amount);
    
    function initialize ()  public override  initializer{
    Ownable.initialize();
    startBlock = block.number;
    startTime = block.timestamp;
    //TODO change rewardStartdate
    rewardStartdate = block.timestamp + 2 minutes;
    poolInfo.allocPoint=1000;
    poolInfo.lastRewardBlock= startBlock;
    poolInfo.accBlackPerShare= 0;
    totalAllocPoint = 1000;
    rewardAmount = 100 * 10**9 ;
    BONUS_MULTIPLIER = 1;
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }
   
    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        if((stakelock[msg.sender] - withdrawLockupPeriod) >= (startTime + 1 days) ){
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        }
        else{
            return _to.sub(_from).mul(BONUS_MULTIPLIER * 2);
        }
    }

    // View function to see pending BLACKs on frontend.
    function pendingBlack(address _user) external view returns (uint256) {
        if(rewardStartdate <= block.timestamp ){
            PoolInfo storage pool = poolInfo;
            UserInfo storage user = userInfo[_user];
            uint256 accBlackPerShare = pool.accBlackPerShare;
            uint256 lpSupply = pool.lpToken.balanceOf(address(this));
            if (block.number > pool.lastRewardBlock && lpSupply != 0) {
                uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
                uint256 blackReward = multiplier.mul(blackPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
                accBlackPerShare = accBlackPerShare.add(blackReward.mul(1e9).div(lpSupply));
            }
            return user.amount.mul(accBlackPerShare).div(1e9).sub(user.rewardDebt);
        }
        else
            return 0;
        
    }


    // Update reward variables of the given pool to be up-to-date.
    function updatePool() public {
        PoolInfo storage pool = poolInfo;
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 blackReward = multiplier.mul(blackPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        pool.accBlackPerShare = pool.accBlackPerShare.add(blackReward.mul(1e9).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for BLACK allocation.
    function deposit(uint256 _amount) public {
        require(!lock(msg.sender),"sender is in locking state");
	    uint256 stakedAmount =(_amount * 90)/100;
	    checkStakeLimit(_amount);
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        updatePool();
       
        if (_amount > 0) {
            pool.lpToken.transferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(stakedAmount);
        }
        user.rewardDebt = user.amount.mul(pool.accBlackPerShare).div(1e9);
        stakelock[msg.sender]= block.timestamp + withdrawLockupPeriod;
        emit Deposit(msg.sender, stakedAmount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _amount) public {
        require(rewardStartdate <= block.timestamp,"reward not yet Started" );
        require (stakelock[msg.sender] <= block.timestamp, " still in withdraw lockup");
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool();
        uint256 pending = user.amount.mul(pool.accBlackPerShare).div(1e9).sub(user.rewardDebt);
        if(pending > 0) {
            safeBlackTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.transfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accBlackPerShare).div(1e9);
        emit Withdraw(msg.sender, _amount);
    }



    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() public {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
		uint256 currentBalance = user.amount;
		require(currentBalance>0,"Insufficient balance !");
		user.amount = 0;
        user.rewardDebt = 0;
        bool flag = pool.lpToken.transfer(address(msg.sender), currentBalance);
		require(flag, "Transfer unsuccessful !");
        emit EmergencyWithdraw(msg.sender, user.amount);
        
    }
    

    // Safe black transfer function, just in case if rounding error causes pool to not have enough BLACKs.
    function safeBlackTransfer(address _to, uint256 _amount) internal {
        black.transferFrom(communitywallet,_to, _amount);
    }

   //---------------------locking-------------------------//
    //checks the account is locked(true) or unlocked(false)
    function lock(address account) public view returns(bool){
        return unLockTime[account] > block.timestamp;
    }
	
	 //if sender is in frozen state,then this function returns epoch value remaining for the address for it to get unfrozen.
    function secondsLeft(address account) public view returns(uint256){
        if(lock(account)){
            return  ( unLockTime[account] - block.timestamp );
        }
         else
            return 0;
    }
 
 
 
    function checkStakeLimit(uint256 _stakeAmount) internal{	  
        require(_stakeAmount <= maxStakeAmount,"Cannot stake  more than permissible limit");
        uint256 balance =  stakeBalance[msg.sender]  + _stakeAmount;
        if(balance == maxStakeAmount) {
            stakeBalance[msg.sender] = 0;        
		    unLockTime[msg.sender] = block.timestamp + lockPeriod;        
        }
        else{
            require(balance < maxStakeAmount,"cannot stake more than permissible limit");
            stakeBalance[msg.sender] = balance;       
        }
	  
    }
    
    //----------------------endlocking-----//
   //------------------claim reward----------------------------//
   
    function claimReward() external {
        require(rewardStartdate <= block.timestamp,"reward not yet Started" );
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        updatePool();
        uint256 pending = user.amount.mul(pool.accBlackPerShare).div(1e9).sub(user.rewardDebt);
        require(pending >= rewardAmount,"reward Limit for claiming not reached"); 
        safeBlackTransfer(msg.sender, pending);
        user.rewardDebt = user.amount.mul(pool.accBlackPerShare).div(1e9);
        emit Withdraw(msg.sender,pending);
    }
   
   
   //----------------reward end------------------------------------------------//

   //----------setter---------------------------------------------//

    function setBlackPerBlock(uint256 _blackPerBlock) public onlyOwner {
        blackPerBlock = _blackPerBlock;
    }
    
     function setTotalAllocationPoint(uint256 _totalAllocPoint) public onlyOwner {
        totalAllocPoint = _totalAllocPoint;
    }
    
     function setAllocationPoint(uint256 _allocPoint) public onlyOwner {
        poolInfo.allocPoint = _allocPoint;
    }
    
    function setRewardStartDate(uint256 _rewardStartdate) public onlyOwner {
       rewardStartdate = _rewardStartdate;
    }
    
    function setRewardAmount(uint256 _rewardAmount) public onlyOwner {
       rewardAmount = _rewardAmount;
    }
    
    function unLockWeeklyLock(address account) public onlyOwner{
        unLockTime[account] = block.timestamp;
    }
    
    function unLockStakeHolder(address account) public onlyOwner{
        stakelock[account] = block.timestamp;
    }
    
    function setblackaddress(address  _black)public onlyOwner{
     black = IBEP20( _black);
     poolInfo.lpToken= black;
    }
  
    function setCommunityWallet(address _communitywallet) public onlyOwner{
        communitywallet = _communitywallet;
    }
    
   
}
