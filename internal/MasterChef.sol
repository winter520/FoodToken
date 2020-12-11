// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./FoodToken.sol";

contract MasterChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. REWARDs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that REWARDs distribution occurs.
        uint256 accRewardPerShare; // Accumulated REWARDs per share, times 1e12. See below.
    }

    // The REWARD TOKEN!
    FoodToken public rewardToken;
    // REWARD tokens created per block.
    uint256 private _rewardPerBlock;
    // trade reward address
    address public tradeRewardAddr;
    // reduce reward cycle (of block numbers)
    uint256 public reduceCycle = 2 * 28800;
    uint256 public reducePercent = 50;
    uint256 public lastReduceBlock;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    mapping (address => uint256) public poolIndex;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when REWARD mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        FoodToken _rewardToken,
        uint256 _rewardPerBlockVal,
        uint256 _startBlock
    ) public {
        rewardToken = _rewardToken;
        _rewardPerBlock = _rewardPerBlockVal;
        startBlock = _startBlock;
        tradeRewardAddr = msg.sender;
        lastReduceBlock = startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function rewardPerBlock() public view returns (uint256) {
        uint256 start = lastReduceBlock;
        uint256 rewardPB = _rewardPerBlock;
        while (block.number >= start.add(reduceCycle)) {
            start = start.add(reduceCycle);
            rewardPB = rewardPB.mul(reducePercent).div(100);
        }
        return rewardPB;
    }

    function setRewardPerBlock(uint256 _rewardPerBlockVal, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        _rewardPerBlock = _rewardPerBlockVal;
    }

    function setReduce(uint256 _start, uint256 _reduceCycle, uint256 _reducePercent) public onlyOwner {
        require(block.number < _start.add(_reduceCycle), "passed cycle");
        lastReduceBlock = _start;
        reduceCycle = _reduceCycle;
        reducePercent = _reducePercent;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) public onlyOwner {
        require(poolIndex[address(_lpToken)] == 0, "exist");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accRewardPerShare: 0
        }));
        poolIndex[address(_lpToken)] = poolInfo.length;
    }

    // Update the given pool's REWARD allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // View function to see pending REWARDs on frontend.
    function pendingReward(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = block.number.sub(pool.lastRewardBlock);
            uint256 tokenReward = multiplier.mul(rewardPerBlock()).mul(pool.allocPoint).div(totalAllocPoint);
            accRewardPerShare = accRewardPerShare.add(tokenReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accRewardPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        while (block.number >= lastReduceBlock.add(reduceCycle)) {
            lastReduceBlock = lastReduceBlock.add(reduceCycle);
            _rewardPerBlock = _rewardPerBlock.mul(reducePercent).div(100);
        }
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = block.number.sub(pool.lastRewardBlock);
        uint256 tokenReward = multiplier.mul(_rewardPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        rewardToken.mint(tradeRewardAddr, tokenReward.div(4)); // 20% to tradeRewardAddr
        rewardToken.mint(address(this), tokenReward);
        pool.accRewardPerShare = pool.accRewardPerShare.add(tokenReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for REWARD allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accRewardPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeRewardTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accRewardPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeRewardTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe rewardToken transfer function, just in case if rounding error causes pool to not have enough REWARDs.
    function safeRewardTransfer(address _to, uint256 _amount) internal {
        uint256 rewardTokenBal = rewardToken.balanceOf(address(this));
        if (_amount > rewardTokenBal) {
            rewardToken.transfer(_to, rewardTokenBal);
        } else {
            rewardToken.transfer(_to, _amount);
        }
    }

    // Update trade reward address.
    function setTradeRewardAddr(address _tradeRewardAddr) public onlyOwner {
        tradeRewardAddr = _tradeRewardAddr;
    }
}
