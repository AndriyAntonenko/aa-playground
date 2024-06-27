// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IAccount } from "@account-abstraction/contracts/interfaces/IAccount.sol";
import { PackedUserOperation } from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract AbstractedAccount is IAccount, Ownable {
  uint256 public s_count;

  constructor(address _owner) Ownable(_owner) { }

  function validateUserOp(
    PackedUserOperation calldata,
    bytes32,
    uint256
  )
    external
    pure
    returns (uint256 validationData)
  {
    return 0; // allow all operations
  }

  function execute() external {
    s_count++;
  }
}

contract AccountFactory {
  function createAccount(address _owner) external returns (address) {
    AbstractedAccount acc = new AbstractedAccount(_owner);
    return address(acc);
  }
}
