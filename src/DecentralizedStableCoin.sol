// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {EIP3009} from "./EIP3009.sol";
import {EIP2612} from "./EIP2612.sol";
import {Pausable} from "./Pausable.sol";
import {AbstractStableCoinV1} from "./AbstractStableCoinV1.sol";
import {Ownable} from "./Ownable.sol";
import {EIP712} from "./libraries/EIP712.sol";

/*
 * @title: DecentralizedStableCoin
 * @author: nate
 * Collateral: Exogenous (ETH & BTC)
 * Minting: Algorithmic
 * Relative Stability: Pegged to USD
 *
 * This is the contract meant to be governed by DSCEngine.
 * This contract is just the ERC20 implementation of our stablecoin system.
 */
contract DecentralizedStableCoin is
    AbstractStableCoinV1,
    Pausable,
    Ownable,
    EIP3009,
    EIP2612
{
    error DecentralizedStableCoin_MustBeMoreThanZero();
    error DecentralizedStableCoin_BurnAmountExceedsBalance();
    error DecentralizedStableCoin_NotZeroAddress();

    uint8 public decimals;
    string public name;
    string public symbol;
    string public currency;
    bool internal initialized;
    mapping(address account => uint256) private _balances;
    mapping(address account => mapping(address spender => uint256))
        private _allowances;
    uint256 internal totalSupply_ = 0;

    event Mint(address indexed minter, address indexed to, uint256 amount);
    event Burn(address indexed burner, uint256 amount);

    /**
     * @notice Initializes the fiat token contract.
     * @param tokenName       The name of the fiat token.
     * @param tokenSymbol     The symbol of the fiat token.
     * @param tokenCurrency   The fiat currency that the token represents.
     * @param tokenDecimals   The number of decimals that the token uses.
     * @param newPauser       The pauser address for the fiat token.
     * @param newOwner        The owner of the fiat token.
     */
    function initialize(
        string memory tokenName,
        string memory tokenSymbol,
        string memory tokenCurrency,
        uint8 tokenDecimals,
        address newPauser,
        address newOwner
    ) public {
        require(!initialized, "FiatToken: contract is already initialized");
        require(
            newPauser != address(0),
            "FiatToken: new pauser is the zero address"
        );
        require(
            newOwner != address(0),
            "FiatToken: new owner is the zero address"
        );

        name = tokenName;
        symbol = tokenSymbol;
        currency = tokenCurrency;
        decimals = tokenDecimals;
        pauser = newPauser;
        setOwner(newOwner);
        initialized = true;
    }

    /**
     * @notice Gets the totalSupply of the token.
     * @return The totalSupply of the token.
     */
    function totalSupply() external view override returns (uint256) {
        return totalSupply_;
    }

    /**
     * @notice Gets the token balance of an account.
     * @param account  The address to check.
     * @return balance The token balance of the account.
     */
    function balanceOf(
        address account
    ) external view override returns (uint256) {
        return _balanceOf(account);
    }

    /**
     * @notice Sets a token allowance for a spender to spend on behalf of the caller.
     * @param spender The spender's address.
     * @param value   The allowance amount.
     * @return True if the operation was successful.
     */
    function approve(
        address spender,
        uint256 value
    ) external virtual override whenNotPaused returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function _approve(
        address owner,
        address spender,
        uint256 value
    ) internal override {
        require(
            spender != address(0),
            "DecentralizedStableCoin: approve to the zero address"
        );
        require(
            owner != address(0),
            "DecentralizedStableCoin: approve from the zero address"
        );
        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @notice Transfers tokens from an address to another by spending the caller's allowance.
     * @dev The caller must have some token allowance on the payer's tokens.
     * @param from  Payer's address.
     * @param to    Payee's address.
     * @param value Transfer amount.
     * @return True if the operation was successful.
     */
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override whenNotPaused returns (bool) {
        require(
            value <= _allowances[from][msg.sender],
            "ERC20: transfer amount exceeds allowance"
        );
        _transfer(from, to, value);
        _allowances[from][msg.sender] = _allowances[from][msg.sender] - value;
        return true;
    }

    /**
     * @notice Transfers tokens from the caller.
     * @param to    Payee's address.
     * @param value Transfer amount.
     * @return True if the operation was successful.
     */
    function transfer(
        address to,
        uint256 value
    ) external override whenNotPaused returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev Internal function to process transfers.
     * @param from  Payer's address.
     * @param to    Payee's address.
     * @param value Transfer amount.
     */
    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(
            value <= _balanceOf(from),
            "ERC20: transfer amount exceeds balance"
        );

        _setBalance(from, _balanceOf(from) - value);
        _setBalance(to, _balanceOf(to) + value);
        emit Transfer(from, to, value);
    }

    function burn(uint256 _amount) public override whenNotPaused onlyOwner {
        uint256 balance = _balanceOf(msg.sender);
        if (_amount <= 0) revert DecentralizedStableCoin_MustBeMoreThanZero();
        if (balance < _amount)
            revert DecentralizedStableCoin_BurnAmountExceedsBalance();
        totalSupply_ = totalSupply_ - (_amount);
        _setBalance(msg.sender, balance - _amount);
        emit Burn(msg.sender, _amount);
        emit Transfer(msg.sender, address(0), _amount);
    }

    function mint(
        address _to,
        uint256 _amount
    ) external onlyOwner whenNotPaused returns (bool) {
        if (_to == address(0)) revert DecentralizedStableCoin_NotZeroAddress();
        if (_amount <= 0) revert DecentralizedStableCoin_MustBeMoreThanZero();
        totalSupply_ = totalSupply_ + _amount;
        _setBalance(_to, _balanceOf(_to) + _amount);
        emit Mint(msg.sender, _to, _amount);
        emit Transfer(address(0), _to, _amount);
        return true;
    }

    /**
     * @dev Internal function to get the current chain id.
     * @return The current chain id.
     */
    function _chainId() internal view returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }

    function _domainSeparator() internal view returns (bytes32) {
        return EIP712.makeDomainSeparator(name, "1", _chainId());
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        bytes memory signature
    ) external {
        _permit(owner, spender, value, deadline, signature);
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override whenNotPaused {
        _permit(owner, spender, value, deadline, v, r, s);
    }

    /**
     * @notice Execute a transfer with a signed authorization
     * @dev EOA wallet signatures should be packed in the order of r, s, v.
     * @param from          Payer's address (Authorizer)
     * @param to            Payee's address
     * @param value         Amount to be transferred
     * @param validAfter    The time after which this is valid (unix time)
     * @param validBefore   The time before which this is valid (unix time)
     * @param nonce         Unique nonce
     * @param signature     Signature bytes signed by an EOA wallet or a contract wallet
     */
    function transferWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        bytes memory signature
    ) external override whenNotPaused {
        _transferWithAuthorization(
            from,
            to,
            value,
            validAfter,
            validBefore,
            nonce,
            signature
        );
    }

    /**
     * @notice Receive a transfer with a signed authorization from the payer
     * @dev This has an additional check to ensure that the payee's address
     * matches the caller of this function to prevent front-running attacks.
     * EOA wallet signatures should be packed in the order of r, s, v.
     * @param from          Payer's address (Authorizer)
     * @param to            Payee's address
     * @param value         Amount to be transferred
     * @param validAfter    The time after which this is valid (unix time)
     * @param validBefore   The time before which this is valid (unix time)
     * @param nonce         Unique nonce
     * @param signature     Signature bytes signed by an EOA wallet or a contract wallet
     */
    function receiveWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        bytes memory signature
    ) external whenNotPaused {
        _receiveWithAuthorization(
            from,
            to,
            value,
            validAfter,
            validBefore,
            nonce,
            signature
        );
    }

    /**
     * @notice Attempt to cancel an authorization
     * @dev Works only if the authorization is not yet used.
     * EOA wallet signatures should be packed in the order of r, s, v.
     * @param authorizer    Authorizer's address
     * @param nonce         Nonce of the authorization
     * @param signature     Signature bytes signed by an EOA wallet or a contract wallet
     */
    function cancelAuthorization(
        address authorizer,
        bytes32 nonce,
        bytes memory signature
    ) external whenNotPaused {
        _cancelAuthorization(authorizer, nonce, signature);
    }

    /**
     * @dev Helper method that sets the balance of an account.
     * @param _account The address of the account.
     * @param _balance The new token balance of the account.
     */
    function _setBalance(address _account, uint256 _balance) internal virtual {
        _balances[_account] = _balance;
    }

    /**
     * @dev Helper method to obtain the balance of an account.
     * @param _account  The address of the account.
     * @return          The token balance of the account.
     */
    function _balanceOf(
        address _account
    ) internal view virtual returns (uint256) {
        return _balances[_account];
    }

    /**
     * @notice Gets the remaining amount of tokens a spender is allowed to transfer on
     * behalf of the token owner.
     * @param owner   The token owner's address.
     * @param spender The spender's address.
     * @return The remaining allowance.
     */
    function allowance(
        address owner,
        address spender
    ) external view override returns (uint256) {
        return _allowances[owner][spender];
    }
}
