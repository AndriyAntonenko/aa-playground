// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BasePaymaster } from "@account-abstraction/contracts/core/BasePaymaster.sol";
import { PackedUserOperation } from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import { IEntryPoint } from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { _packValidationData } from "@account-abstraction/contracts/core/Helpers.sol";
import { UserOperationLib } from "@account-abstraction/contracts/core/UserOperationLib.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/// @title Paymaster
/// @dev Paymaster contract to validate user operations with a signature
contract Paymaster is BasePaymaster {
  using UserOperationLib for PackedUserOperation;

  error Paymaster__InvalidSignature();

  address public immutable i_verifyingSigner;

  uint256 private constant VALID_TIMESTAMP_OFFSET = PAYMASTER_DATA_OFFSET;
  uint256 private constant SIGNATURE_OFFSET = VALID_TIMESTAMP_OFFSET + 12;

  constructor(IEntryPoint _entryPoint, address _verifyingSigner) BasePaymaster(_entryPoint) {
    i_verifyingSigner = _verifyingSigner;
  }

  function getHash(
    PackedUserOperation calldata userOp,
    uint48 validUntil,
    uint48 validAfter
  )
    public
    view
    returns (bytes32)
  {
    //can't use userOp.hash(), since it contains also the paymasterAndData itself.
    address sender = userOp.getSender();
    return keccak256(
      abi.encode(
        sender,
        userOp.nonce,
        keccak256(userOp.initCode),
        keccak256(userOp.callData),
        userOp.accountGasLimits,
        uint256(bytes32(userOp.paymasterAndData[PAYMASTER_VALIDATION_GAS_OFFSET:PAYMASTER_DATA_OFFSET])),
        userOp.preVerificationGas,
        userOp.gasFees,
        block.chainid,
        address(this),
        validUntil,
        validAfter
      )
    );
  }

  function _validatePaymasterUserOp(
    PackedUserOperation calldata userOp,
    bytes32,
    uint256
  )
    internal
    view
    override(BasePaymaster)
    returns (bytes memory context, uint256 validationData)
  {
    (uint48 validUntil, uint48 validAfter, bytes calldata signature) = _parsePaymasterData(userOp.paymasterAndData);

    if (signature.length != 64 && signature.length != 65) {
      revert Paymaster__InvalidSignature();
    }

    bytes32 hash = MessageHashUtils.toEthSignedMessageHash(getHash(userOp, validUntil, validAfter));
    if (i_verifyingSigner != ECDSA.recover(hash, signature)) {
      return ("", _packValidationData(true, validUntil, validAfter));
    }

    return ("", _packValidationData(false, validUntil, validAfter));
  }

  function _parsePaymasterData(bytes calldata paymasterData)
    internal
    pure
    returns (uint48 validUntil, uint48 validAfter, bytes calldata signature)
  {
    bytes memory borders = paymasterData[VALID_TIMESTAMP_OFFSET:SIGNATURE_OFFSET];
    validUntil = uint48(bytes6(borders));
    validAfter = uint48(uint96(bytes12(borders)));
    signature = paymasterData[SIGNATURE_OFFSET:];
  }
}
