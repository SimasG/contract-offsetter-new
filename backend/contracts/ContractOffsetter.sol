// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "hardhat/console.sol";
// ** Still don't understand why we use "SafeERC20.sol"
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// ** Not sure why we use the upgradeable version
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./toucan_contracts/IToucanContractRegistry.sol";

contract ContractOffsetter is OwnableUpgradeable {
    using SafeERC20 for IERC20;

    // All in Mumbai
    address public bctAddress = 0xf2438A14f668b1bbA53408346288f3d7C71c10a1;
    // ** Figure out the exact function of the 'contractRegistry'
    address public contractRegistry = 0x6739D490670B2710dc7E79bB12E455DE33EE1cb6;
    // user address => (token contract address => amount)
    mapping(address => mapping(address => uint256)) public balances;
    // user/contract => nonce of last offset
    mapping(address => uint256) public lastOffsetNonce;
    // user => amount they've offset in total
    mapping(address => uint256) public overallOffsetAmount;

    // 'erc20Address' can technically either be BCT or TCO2
    // ** Not sure how TCO2 can be deposited unless you're the party that tokenized off-chain CCs
    event Deposited(address depositor, address erc20Address, uint256 amountDeposited);

    event Redeemed(address redeemer, address receivedTCO2, uint256 amountRedeemed);

    // ** Can we only offset TCO2 (& not also BCT)?
    // ** Is `offsetAddress` a transaction hash (not sure if it can be considered address)?
    event Offset(
        address offsetter,
        address retiredTCO2,
        uint256 amountOffset,
        address offsetAddress,
        uint256 latestOffsetNonce
    );

    // @description you can use this to change the TCO2 contracts registry if needed (it's currently hard-coded)
    // @param _address the contract registry to use
    function setToucanContractRegistry(address _address) public virtual onlyOwner {
        contractRegistry = _address;
    }

    // @description checks if token to be deposited is eligible for this pool
    // @param _erc20Address address to be checked
    // 'private' -> only this contract can run this func
    function checkTokenEligibility(address _erc20Address) private view returns (bool) {
        // check if the token is a TCO2 token
        // ** How is the contract interface enough to achieve this functionality?
        // ** Why aren't we importing & using `ToucanContractRegistry` instead?
        bool isToucanContract = IToucanContractRegistry(contractRegistry).checkERC20(_erc20Address);

        if (isToucanContract) return true;

        // check if token is BCT
        if (bctAddress == _erc20Address) return true;

        // if nothing matches, return false
        return false;
    }

    // @description deposit tokens from use to this contract
    // @param _erc20Address token to be deposited
    // @param _amount amount to be deposited
    function deposit(address _erc20Address, uint256 _amount) public {
        bool eligibility = checkTokenEligibility(_erc20Address);
        require(eligibility, "Can't deposit this token");

        // use token's contract to do a safe transfer from the user to this contract
        // the user has to approve this in the frontend

        // ** What's the difference between 'safeTransfer' & 'safeTransferFrom'?
        // ** 'address(this)' & 'contractRegistry' are the same, right?
        IERC20(_erc20Address).safeTransferFrom(msg.sender, address(this), _amount);

        console.log("address(this):", address(this));
        console.log("contractRegistry:", contractRegistry);

        // add amount of said token to balance of this user in this contract
        balances[msg.sender][address(this)] += _amount;

        emit Deposited(msg.sender, _erc20Address, _amount);
    }

    // @description redeems some BCT from contract balance for a chosen TCO2 token
    // @param _desiredTCO2 the address of the TCO2 you want to receive
    // @param _amount the amount of BCT you want to redeem for TCO2
}
