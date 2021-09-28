// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IDragonGol.sol";

import "hardhat/console.sol";

// MasterChef is the master of DragonGold. He can make DragonGold and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once DragonGold is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of DrgonGols
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accDgngPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accDgngPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    /**
    * DGNG (0% deposit) (50X multiplier) (also an auto compounding vault)
    * WETH (4% deposit) (5X multiplier)
    * WBTC (4% deposit) (5X multiplier)
    * WMATIC (4% deposit) (5X multiplier)
    * USDC (4% deposit) (5X multiplier)
    * DAI (4% deposit) (5X multiplier)
    * LINK (3% deposit) (7.5X multiplier)
    * POLYPUP BALL (3% deposit) (7.5X multiplier)
    * POLYPUP BONE (4% deposit) (5X multiplier)
    * POLYDOGE (4% deposit) (5X multiplier)

    * Farms (QUICKSWAP LP Pools)

    * DGNG/WMATIC (0% deposit) (100X multiplier) (also an auto compounding vault)
    * DGNG/USDC (0% deposit) (100X multiplier) (also an auto compounding vault)
    * DAI/USDC (4% deposit) (10X multiplier)
    * POLYPUP BALL/USDC (3% deposit) (15X multiplier)
    */
    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. DragonGols to distribute per block.
        uint256 lastRewardBlock; // Last block number that DragonGols distribution occurs.
        uint256 accDgngPerShare; // Accumulated DrgonGols per share, times 1e12. See below.
        uint16 depositFeeBP; // Deposit fee in basis points 10000 - 100%
        uint256 lpSupply;
    }

    struct PoolDragonNestInfo {
        uint256 accDepFeePerShare; // Accumulated LP token(from deposit fee) per share, times 1e12. See below.
        uint256 pendingDepFee; // pending deposit fee for the reward for the Dragon Nest Supporters
    }

    mapping(uint256 => PoolDragonNestInfo) public poolDragonNestInfo; // poolId => poolDragonNestInfo
    mapping(uint256 => mapping(uint256 => uint256)) public dragonNestInfo; // poolId => (nestId => rewardDebt)
    mapping(uint256 => address) nestSupporters; // tokenId => nest supporter;
    uint256 public nestSupportersLength;

    uint256 public constant dgngMaximumSupply = 146300 * (10**18);

    // The Dragon Gold TOKEN!
    address public dgng;
    uint256 public dgngPerBlock;
    address public immutable DRAGON_UTILITY;
    // Deposit Fee address
    address public feeAddress;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when Dragon mining starts.
    uint256 public startBlock;
    // The block number when Dragon mining ends.
    uint256 public emmissionEndBlock = type(uint256).max;

    address public devWallet;

    event AddPool(uint256 indexed pid, address lpToken, uint256 allocPoint, uint256 depositFeeBP);
    event SetPool(uint256 indexed pid, address lpToken, uint256 allocPoint, uint256 depositFeeBP);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event SetFeeAddress(address indexed user, address indexed newAddress);
    event UpdateStartBlock(uint256 newStartBlock);

    constructor(
        address _dgng,
        address _DRAGON_UTILITY,
        address _feeAddress,
        uint256 _startBlock,
        uint256 _dgngPerBlock,
        address _devWallet
    ) {
        dgng = _dgng;
        DRAGON_UTILITY = _DRAGON_UTILITY;
        feeAddress = _feeAddress;
        startBlock = _startBlock;
        dgngPerBlock = _dgngPerBlock;
        devWallet = _devWallet;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    mapping(IERC20 => bool) public poolExistence;
    modifier nonDuplicated(IERC20 _lpToken) {
        require(poolExistence[_lpToken] == false, "nonDuplicated: duplicated");
        _;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        uint16 _depositFeeBP,
        bool _withUpdate
    ) external onlyOwner nonDuplicated(_lpToken) {
        // Make sure the provided token is ERC20
        _lpToken.balanceOf(address(this));

        require(_depositFeeBP <= 401, "add: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint + _allocPoint;
        poolExistence[_lpToken] = true;

        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accDgngPerShare: 0,
                depositFeeBP: _depositFeeBP,
                lpSupply: 0
            })
        );

        emit AddPool(poolInfo.length - 1, address(_lpToken), _allocPoint, _depositFeeBP);
    }

    // Update the given pool's DragonGol allocation point and deposit fee. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        uint16 _depositFeeBP,
        bool _withUpdate
    ) external onlyOwner {
        require(_depositFeeBP <= 401, "set: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;

        emit SetPool(_pid, address(poolInfo[_pid].lpToken), _allocPoint, _depositFeeBP);
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        // As we set the multiplier to 0 here after emmissionEndBlock
        // deposits aren't blocked after farming ends.
        if (_from > emmissionEndBlock) return 0;
        if (_to > emmissionEndBlock) return emmissionEndBlock - _from;
        else return _to - _from;
    }

    // View function to see pending DragonGols on frontend.
    function pendingDgng(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accDgngPerShare = pool.accDgngPerShare;
        if (block.number > pool.lastRewardBlock && pool.lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 dgngReward = (multiplier * dgngPerBlock * pool.allocPoint) / totalAllocPoint;
            uint256 dgngRewardUser = (dgngReward * 975) / 1000;
            accDgngPerShare = accDgngPerShare + ((dgngRewardUser * 1e12) / pool.lpSupply);
        }

        return ((user.amount * accDgngPerShare) / 1e12) - user.rewardDebt;
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
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }

        if (pool.lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 dgngReward = (multiplier * dgngPerBlock * pool.allocPoint) / totalAllocPoint;

        // This shouldn't happen, but just in case we stop rewards.
        if (IERC20(dgng).totalSupply() > dgngMaximumSupply) dgngReward = 0;
        else if ((IERC20(dgng).totalSupply() + dgngReward) > dgngMaximumSupply)
            dgngReward = dgngMaximumSupply - IERC20(dgng).totalSupply();

        // 2.5% to dev 97.5% to user
        uint256 dgngRewardUser = (dgngReward * 975) / 1000;
        if (dgngReward > 0) {
            IDragonGol(dgng).mint(address(this), dgngRewardUser);
            IDragonGol(dgng).mint(devWallet, dgngReward - dgngRewardUser);
        }

        // The first time we reach DragonGol's max supply we solidify the end of farming.
        if (IERC20(dgng).totalSupply() >= dgngMaximumSupply && emmissionEndBlock == type(uint256).max)
            emmissionEndBlock = block.number;

        pool.accDgngPerShare = pool.accDgngPerShare + ((dgngRewardUser * 1e12) / pool.lpSupply);
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for DragonGol allocation.
    function deposit(uint256 _pid, uint256 _amount) external nonReentrant {
        require(_amount > 0, "Dragon: ZERO_VALUE");
        require(_pid < poolInfo.length, "Dragon: Non-existent pool");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = ((user.amount * pool.accDgngPerShare) / 1e12) - user.rewardDebt;
            if (pending > 0) {
                safeDgngTransfer(msg.sender, pending);
            }
        }

        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);

        if (pool.depositFeeBP > 0) {
            uint256 depositFee = (_amount * pool.depositFeeBP) / 10000;
            // We split this fee to feeAddress and Dragon Nest supporters - 90% 10%
            pool.lpToken.safeTransfer(feeAddress, (depositFee * 9000) / 10000);
            poolDragonNestInfo[_pid].pendingDepFee = (depositFee * 1000) / 10000;
            user.amount = user.amount + _amount - depositFee;
            pool.lpSupply = pool.lpSupply + _amount - depositFee;
        } else {
            user.amount = user.amount + _amount;
            pool.lpSupply = pool.lpSupply + _amount;
        }

        user.rewardDebt = (user.amount * pool.accDgngPerShare) / 1e12;

        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "Withdraw: not good");
        updatePool(_pid);
        uint256 pending = ((user.amount * pool.accDgngPerShare) / 1e12) - user.rewardDebt;
        if (pending > 0) {
            safeDgngTransfer(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount - _amount;
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
            pool.lpSupply = pool.lpSupply - _amount;
        }
        user.rewardDebt = (user.amount * pool.accDgngPerShare) / 1e12;
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);

        // In the case of an accounting error, we choose to let the user emergency withdraw anyway
        if (pool.lpSupply >= amount) pool.lpSupply = pool.lpSupply - amount;
        else pool.lpSupply = 0;

        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe DGNG transfer function, just in case if rounding error causes pool to not have enough DGNGs.
    function safeDgngTransfer(address _to, uint256 _amount) internal {
        uint256 dgngBal = IERC20(dgng).balanceOf(address(this));
        bool transferSuccess = false;
        if (_amount > dgngBal) {
            transferSuccess = IERC20(dgng).transfer(_to, dgngBal);
        } else {
            transferSuccess = IERC20(dgng).transfer(_to, _amount);
        }
        require(transferSuccess, "safeDgngTransfer: transfer failed");
    }

    function setFeeAddress(address _feeAddress) external {
        require(msg.sender == feeAddress, "setFeeAddress: FORBIDDEN");
        require(_feeAddress != address(0), "!nonzero");
        feeAddress = _feeAddress;
        emit SetFeeAddress(msg.sender, _feeAddress);
    }

    function setStartBlock(uint256 _newStartBlock) external onlyOwner {
        require(poolInfo.length == 0, "no changing start block after pools have been added");
        require(block.number < startBlock, "cannot change start block if sale has already commenced");
        require(block.number < _newStartBlock, "cannot set start block in the past");
        startBlock = _newStartBlock;

        emit UpdateStartBlock(startBlock);
    }

    function massUpdatePoolDragonNests() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePoolDragonNest(pid);
        }
    }

    // Update dragon nest.
    function updatePoolDragonNest(uint256 _pid) public {
        PoolDragonNestInfo storage poolDragonNest = poolDragonNestInfo[_pid];
        uint256 _pendingDepFee = poolDragonNest.pendingDepFee;

        if (_pendingDepFee > 0) {
            poolDragonNest.accDepFeePerShare = _pendingDepFee / nestSupportersLength;
            poolDragonNest.pendingDepFee = 0;
        }
    }

    /**
     * These functions are private function for using contract internal.
     * These functions will be used when user stakes new DragonUtility
     */
    function massUpdatePoolDragonNestsWithNewToken(uint256 _tokenId) private {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePoolDragonNestWithNewToken(pid, _tokenId);
        }
    }

    function updatePoolDragonNestWithNewToken(uint256 _pid, uint256 _tokenId) private {
        PoolDragonNestInfo storage _poolDragonNestInfo = poolDragonNestInfo[_pid];
        uint256 _pendingDepFee = _poolDragonNestInfo.pendingDepFee;

        if (_pendingDepFee > 0) {
            _poolDragonNestInfo.accDepFeePerShare = _pendingDepFee / nestSupportersLength;
            _poolDragonNestInfo.pendingDepFee = 0;
        }
        dragonNestInfo[_pid][_tokenId] = 0;
    }

    function stakeDragonUtility(uint256 tokenId) external nonReentrant {
        massUpdatePoolDragonNestsWithNewToken(tokenId);
        IERC721 _dragonUtility = IERC721(DRAGON_UTILITY);
        _dragonUtility.safeTransferFrom(msg.sender, address(this), tokenId);
        nestSupporters[tokenId] = msg.sender;
        nestSupportersLength++;
    }

    function withdrawDragonUtility(uint256 tokenId) external {
        require(nestSupporters[tokenId] == msg.sender, "Dragon: Forbidden");
        // TODO we should do transfer in for loop? Okay?

        IERC721 _dragonUtility = IERC721(DRAGON_UTILITY);
        _dragonUtility.safeTransferFrom(address(this), msg.sender, tokenId);
        nestSupportersLength--;
    }
}