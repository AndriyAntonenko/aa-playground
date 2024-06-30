// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IEntryPoint } from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";

import { AbstractedAccount } from "./Account.sol";

/// @title AccountFactory
/// @dev Factory contract to create new AbstractedAccount contracts. It uses CREATE2 to have fully predictable calls for
/// bundler estimations
contract AccountFactory {
  error Create2FailedDeployment();
  error Create2EmptyBytecode();

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

    return _deploy(0, _salt, bytecode);
  }

  function predictAccountAddress(address _owner, bytes32 _salt) external view returns (address) {
    bytes memory bytecode =
      abi.encodePacked(type(AbstractedAccount).creationCode, abi.encode(_owner), abi.encode(i_entryPoint));
    return _computeAddress(_salt, keccak256(bytecode));
  }

  function _getAccountAddress(bytes32 _salt, bytes32 _bytecodeHash) internal view returns (address) {
    return _computeAddress(_salt, _bytecodeHash);
  }

  /*//////////////////////////////////////////////////////////////
                          CREATE2 FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @dev Deploys a contract using `CREATE2`. The address where the contract
   * will be deployed can be known in advance via {computeAddress}.
   *
   * The bytecode for a contract can be obtained from Solidity with
   * `type(contractName).creationCode`.
   *
   * Requirements:
   *
   * - `bytecode` must not be empty.
   * - `salt` must have not been used for `bytecode` already.
   * - the factory must have a balance of at least `amount`.
   * - if `amount` is non-zero, `bytecode` must have a `payable` constructor.
   */
  function _deploy(uint256 amount, bytes32 salt, bytes memory bytecode) internal returns (address addr) {
    if (bytecode.length == 0) {
      revert Create2EmptyBytecode();
    }
    /// @solidity memory-safe-assembly
    assembly {
      addr := create2(amount, add(bytecode, 0x20), mload(bytecode), salt)
    }
    if (addr == address(0)) {
      revert Create2FailedDeployment();
    }
  }

  /**
   * @dev Returns the address where a contract will be stored if deployed via {deploy}. Any change in the
   * `bytecodeHash` or `salt` will result in a new destination address.
   */
  function _computeAddress(bytes32 salt, bytes32 bytecodeHash) internal view returns (address) {
    return _computeAddress(salt, bytecodeHash, address(this));
  }

  /**
   * @dev Returns the address where a contract will be stored if deployed via {deploy} from a contract located at
   * `deployer`. If `deployer` is this contract's address, returns the same value as {computeAddress}.
   */
  function _computeAddress(bytes32 salt, bytes32 bytecodeHash, address deployer) internal pure returns (address addr) {
    /// @solidity memory-safe-assembly
    assembly {
      let ptr := mload(0x40) // Get free memory pointer

      // |                   | ↓ ptr ...  ↓ ptr + 0x0B (start) ...  ↓ ptr + 0x20 ...  ↓ ptr + 0x40 ...   |
      // |-------------------|---------------------------------------------------------------------------|
      // | bytecodeHash      |                                                        CCCCCCCCCCCCC...CC |
      // | salt              |                                      BBBBBBBBBBBBB...BB                   |
      // | deployer          | 000000...0000AAAAAAAAAAAAAAAAAAA...AA                                     |
      // | 0xFF              |            FF                                                             |
      // |-------------------|---------------------------------------------------------------------------|
      // | memory            | 000000...00FFAAAAAAAAAAAAAAAAAAA...AABBBBBBBBBBBBB...BBCCCCCCCCCCCCC...CC |
      // | keccak(start, 85) |            ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑ |

      mstore(add(ptr, 0x40), bytecodeHash)
      mstore(add(ptr, 0x20), salt)
      mstore(ptr, deployer) // Right-aligned with 12 preceding garbage bytes
      let start := add(ptr, 0x0b) // The hashed data starts at the final garbage byte which we will set to 0xff
      mstore8(start, 0xff)
      addr := keccak256(start, 85)
    }
  }
}
