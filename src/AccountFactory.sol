// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IEntryPoint } from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

import { AbstractedAccount } from "./Account.sol";

contract AccountFactory {
  IEntryPoint public immutable i_entryPoint;

  constructor(IEntryPoint _entryPoint) {
    i_entryPoint = _entryPoint;
  }

  /// @notice this method creates a new AbstractedAccount contract using CREATE2
  /// @dev CREATE2 is necessary, because we want to have fully predictable calls for bundler estimations
  /// @param _owner - owner of the new account
  /// @param _salt - salt for CREATE2
  function createAccount(address _owner, bytes32 _salt) external returns (address) {
    bytes memory bytecode =
      abi.encodePacked(type(AbstractedAccount).creationCode, abi.encode(_owner), abi.encode(i_entryPoint));

    address accountAddress = _getAccountAddress(_salt, keccak256(bytecode));
    if (accountAddress.code.length > 0) {
      return accountAddress;
    }

    return Create2.deploy(0, _salt, bytecode);
  }

  function predictAccountAddress(address _owner, bytes32 _salt) external view returns (address) {
    bytes memory bytecode =
      abi.encodePacked(type(AbstractedAccount).creationCode, abi.encode(_owner), abi.encode(i_entryPoint));
    return Create2.computeAddress(_salt, keccak256(bytecode));
  }

  function _getAccountAddress(bytes32 _salt, bytes32 _bytecodeHash) internal view returns (address) {
    return Create2.computeAddress(_salt, _bytecodeHash);
  }
}
