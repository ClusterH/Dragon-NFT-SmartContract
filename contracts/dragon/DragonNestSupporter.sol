// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../libraries/TransferHelper.sol";

contract DragonNestSupporter is ERC721URIStorage, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    event Sold(address indexed buyer, uint256 indexed tokenId);

    Counters.Counter private _tokenIds;

    Counters.Counter private _currentSaleId;

    address public immutable STABLETOKEN;
    address payable private immutable _devWallet;
    uint256 private _itemCost;

    mapping(address => bool) _whitelist;

    mapping(address => uint256) _whitelistAllowance;

    bool private _isSaleActive;

    uint256 public PUBLICSALETIMESTAMP;

    constructor(
        address payable devWallet_,
        address _stableToken,
        uint256 _publicSaleOpenTimestamp
    ) ERC721("Dragon Nest Supporters", "DCNS") {
        _devWallet = devWallet_;
        STABLETOKEN = _stableToken;
        PUBLICSALETIMESTAMP = _publicSaleOpenTimestamp;
    }

    function devWallet() public view returns (address) {
        return _devWallet;
    }

    function itemCost() public view returns (uint256) {
        return _itemCost;
    }

    function addWhiteList(address whitelistAddress) external onlyOwner {
        require(_whitelistAllowance[whitelistAddress] < 2, "already has 2 in allowance");

        _whitelist[whitelistAddress] = true;
        _whitelistAllowance[whitelistAddress]++;
    }

    function activateSale() external onlyOwner {
        _isSaleActive = true;
    }

    function mintItem(string memory tokenURI) external onlyOwner returns (uint256) {
        require(_tokenIds.current() < 25, "All tokens have been minted");

        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(address(this), newItemId);
        _setTokenURI(newItemId, tokenURI);
        return newItemId;
    }

    function buyDragonNest() external nonReentrant {
        require(balanceOf(_msgSender()) < 2, "Dragon:Forbidden");
        require(_isSaleActive, "sale must be active");
        require(_currentSaleId.current() < 25, "all tokens sold");

        if (block.timestamp < PUBLICSALETIMESTAMP) {
            require(_whitelist[msg.sender], "Not in whitelist");
            require(_whitelistAllowance[msg.sender] > 0, "must have purchases left");
        }

        _currentSaleId.increment();

        TransferHelper.safeTransferFrom(STABLETOKEN, _msgSender(), _devWallet, _itemCost);

        _safeTransfer(address(this), msg.sender, _currentSaleId.current(), "");

        if (block.timestamp < PUBLICSALETIMESTAMP) {
            _whitelistAllowance[msg.sender]--;
        }

        emit Sold(msg.sender, _currentSaleId.current());
    }

    function setItemCost(uint256 _cost) external onlyOwner {
        _itemCost = _cost;
    }
}
