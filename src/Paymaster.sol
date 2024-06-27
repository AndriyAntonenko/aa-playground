// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IPaymaster } from "@account-abstraction/contracts/interfaces/IPaymaster.sol";
import { PackedUserOperation } from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";

contract Paymaster is IPaymaster {
  function validatePaymasterUserOp(
    PackedUserOperation calldata,
    bytes32,
    uint256
  )
    external
    pure
    returns (bytes memory context, uint256 validationData)
  {
    context = new bytes(0);
    validationData = 0; // valid
  }

  function postOp(PostOpMode, bytes calldata, uint256, uint256) external { }
}
