// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract TokenFarm is Ownable {
    // mapping token addr -> staker addr -> amount
    mapping(address => mapping(address => uint256)) public stakingBalance;
    mapping(address => uint256) public uniqueTokensStaked;
    mapping(address => address) public tokenPriceFeedMapping;
    address[] public stakers;
    address[] public allowedTokens;
    IERC20 public dappToken;

    // stakeTokens - DONE
    // unstakeTokens
    // issueTokens - DONE
    // addAllowedTokens - DONE
    // getValue - DONE

    // 100 ETH 1:1 for every 1 ETH, we give 1 DappToken
    // 50 ETH and 50 DAI staked, and we want to give a reward of 1 DAPP/ 1 DAI
    constructor(address _dappTokenAddress) public {
        dappToken = IERC20(_dappTokenAddress);
    }

    // STAKE TOKENS
    function stakeTokens(uint256 _amount, address _token) public {
        require(_amount > 0, "Amount must be more than 0");
        require(
            tokenIsAllowed(_token),
            "Token is currently not supported/allowed"
        );
        // transferFrom() [ERC20] because TokenFarm doesn't own the token
        // transferFrom(sender, *this TokenFarm contract*, amount)
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        updateUniqueTokensStaked(msg.sender, _token);
        stakingBalance[_token][msg.sender] += _amount;
        if (uniqueTokensStaked[msg.sender] == 1) {
            stakers.push(msg.sender);
        }
    }

    // UNSTAKE TOKENS
    function unstakeTokens(address _token) public {
        uint256 balance = stakingBalance[_token][msg.sender];
        require(balance > 0, "Staking balanace cannot be 0");
        IERC20(_token).transfer(msg.sender, balance);
        stakingBalance[_token][msg.sender] = 0;
        uniqueTokensStaked[msg.sender] -= 1;
    }

    // ISSUE TOKENS
    function issueTokens() public onlyOwner {
        // Issue tokens to all stakers
        for (
            uint256 stakersIndex = 0;
            stakersIndex < stakers.length;
            stakersIndex++
        ) {
            address recipient = stakers[stakersIndex];
            uint256 userTotalValue = getUserTotalValue(recipient);
            // send them a token reward [can use transfer() here because this contract own DAPP]
            // based on their total value
            dappToken.transfer(recipient, userTotalValue);
        }
    }

    // ADD ALLOWED TOKENS
    function addAllowedTokens(address _token) public onlyOwner {
        allowedTokens.push(_token);
    }

    // GET VALUE
    function getUserTotalValue(address _user) public view returns (uint256) {
        uint256 totalValue = 0;
        require(uniqueTokensStaked[_user] > 0, "No tokens staked!");
        for (
            uint256 allowedTokensIndex = 0;
            allowedTokensIndex < allowedTokens.length;
            allowedTokensIndex++
        ) {
            totalValue += getUserSingleTokenValue(
                _user,
                allowedTokens[allowedTokensIndex]
            );
        }
        return totalValue;
    }

    function updateUniqueTokensStaked(address _user, address _token) internal {
        if (stakingBalance[_token][_user] <= 0) {
            uniqueTokensStaked[_user] += 1;
        }
    }

    function setPriceFeedContract(
        address _token,
        address _priceFeed
    ) public onlyOwner {
        tokenPriceFeedMapping[_token] = _priceFeed;
    }

    function getUserSingleTokenValue(
        address _user,
        address _token
    ) public view returns (uint256) {
        if (uniqueTokensStaked[_user] <= 0) {
            return 0;
        }
        // price of the token * stakingBalance[_token][_user]
        (uint256 price, uint256 decimals) = getTokenValue(_token);
        // 10000000000000000000 ETH (in Gwei)
        // ETH/USD -> 200000000000
        // 10 * 2000 = 20000
        return ((stakingBalance[_token][_user] * price) / (10 ** decimals));
    }

    function getTokenValue(
        address _token
    ) public view returns (uint256, uint256) {
        // chainlink priceFeedAddress
        address priceFeedAddress = tokenPriceFeedMapping[_token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            priceFeedAddress
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint256 decimals = priceFeed.decimals();
        return (uint256(price), decimals);
    }

    function tokenIsAllowed(address _token) public view returns (bool) {
        for (
            uint256 allowedTokensIndex = 0;
            allowedTokensIndex < allowedTokens.length;
            allowedTokensIndex++
        ) {
            if (allowedTokens[allowedTokensIndex] == _token) {
                return true;
            }
        }
        return false;
    }
}
