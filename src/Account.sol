// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseAccount } from "@account-abstraction/contracts/core/BaseAccount.sol";
import { IEntryPoint } from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { PackedUserOperation } from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import { SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS } from "@account-abstraction/contracts/core/Helpers.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

/// @title AbstractedAccount
/// @dev actually it's mostly a copy of the SimepleAccount, provided by the account-abstraction package
contract AbstractedAccount is BaseAccount, Ownable {
  error AbstractedAccount__InvalidCaller();
  error AbstractedAccount__BatchParamsMismatch();

  IEntryPoint public immutable i_entryPoint;

  constructor(address _owner, IEntryPoint _entryPoint) Ownable(_owner) {
    i_entryPoint = _entryPoint;
  }

  modifier onlyOwnerOrSelf() {
    if (msg.sender != owner() && msg.sender != address(this)) {
      revert AbstractedAccount__InvalidCaller();
    }
    _;
  }

  modifier onlyEntryPointOrOwner() {
    if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
      revert AbstractedAccount__InvalidCaller();
    }
    _;
  }

  function entryPoint() public view override returns (IEntryPoint) {
    return i_entryPoint;
  }

  /// @notice execute a transaction (called directry from owner, or by the entryPoint)
  /// @param _target - address of the contract to call
  /// @param _value - value to send
  /// @param _func - calldata to send
  function execute(address _target, uint256 _value, bytes memory _func) external onlyEntryPointOrOwner {
    _call(_target, _value, _func);
  }

  /// @notice execute a sequence of transactions (called directry from owner, or by the entryPoint)
  /// @dev _values could be empty if all transactions are valueless, this is save gas for trivial calls
  /// @param _targets - addresses of the contracts to call
  /// @param _values - values to send
  /// @param _funcs - calldata to send
  function executeBatch(
    address[] calldata _targets,
    uint256[] calldata _values,
    bytes[] calldata _funcs
  )
    external
    onlyEntryPointOrOwner
  {
    if (_values.length == 0 && _funcs.length != _targets.length) {
      revert AbstractedAccount__BatchParamsMismatch();
    }
    if (_values.length != 0 && _funcs.length != _targets.length && _funcs.length != _values.length) {
      revert AbstractedAccount__BatchParamsMismatch();
    }

    if (_values.length == 0) {
      for (uint256 i = 0; i < _targets.length; i++) {
        _call(_targets[i], 0, _funcs[i]);
      }
      return;
    }

    for (uint256 i = 0; i < _targets.length; i++) {
      _call(_targets[i], _values[i], _funcs[i]);
    }
  }

  /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  function _validateSignature(
    PackedUserOperation calldata userOp,
    bytes32 userOpHash
  )
    internal
    virtual
    override
    returns (uint256 validationData)
  {
    bytes32 hash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
    address signer = ECDSA.recover(hash, userOp.signature);
    if (owner() != signer) {
      return SIG_VALIDATION_FAILED;
    }
    return SIG_VALIDATION_SUCCESS;
  }

  function _call(address _target, uint256 _value, bytes memory _data) internal {
    (bool success, bytes memory result) = _target.call{ value: _value }(_data);
    if (!success) {
      assembly {
        revert(add(result, 32), mload(result))
      }
    }
  }

  /*//////////////////////////////////////////////////////////////
                          DEPOSIT FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @notice check current account deposit in entryPoint
  function getDeposit() public view returns (uint256) {
    return entryPoint().balanceOf(address(this));
  }

  /// @notice deposit more funds for this account to entryPoint
  function addDeposit() public payable {
    entryPoint().depositTo{ value: msg.value }(address(this));
  }

  /// @notice withdraw funds from entryPoint to this withdrawAddress
  /// @param _withdrawAddress - address to withdraw funds to
  /// @param _amount - amount to withdraw
  function withdrawDepositTo(address payable _withdrawAddress, uint256 _amount) public onlyOwnerOrSelf {
    entryPoint().withdrawTo(_withdrawAddress, _amount);
  }
}
