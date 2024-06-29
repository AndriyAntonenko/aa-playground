// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { PackedUserOperation } from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import { UserOperationLib } from "@account-abstraction/contracts/core/UserOperationLib.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { Counter } from "../src/mocks/Counter.sol";

import { EntryPoint } from "../src/EntryPoint.sol";
import { Paymaster } from "../src/Paymaster.sol";
import { AccountFactory, AbstractedAccount } from "../src/Account.sol";
import { Deploy } from "../script/Deploy.s.sol";
import { CreateUtil } from "./utils/CreateUtil.sol";

contract AccountTest is Test {
  Counter public counter;
  Account public OWNER = makeAccount("OWNER");
  address public immutable SPONSOR = makeAddr("SPONSOR");
  address public immutable BENEFICIARY = makeAddr("BENEFICIARY");
  uint256 public constant SPONSOR_BALANCE = 100 ether;

  Deploy public deployer;
  AccountFactory public accountFactory;
  EntryPoint public entryPoint;
  Paymaster public paymaster;

  function setUp() public {
    deployer = new Deploy();
    counter = new Counter();
    (accountFactory, entryPoint, paymaster) = deployer.deploy();
  }

  function testUserOp_succesfull() public {
    address sender = CreateUtil.contractAddressFrom(address(accountFactory), vm.getNonce(address(accountFactory)));

    uint256 maxFeePerGas = 10 gwei;
    uint256 maxPriorityFeePerGas = 5 gwei;
    bytes32 gasFees = bytes32((maxPriorityFeePerGas << 128) | maxFeePerGas);

    uint256 preVerificationGas = 50_000;
    uint256 verificationGasLimit = 1_000_000;
    uint256 callGasLimit = 200_000;
    bytes32 accountGasLimits = bytes32((verificationGasLimit << 128) | callGasLimit);

    // accountFactory + calldata
    bytes memory initCode = abi.encodePacked(
      address(accountFactory), abi.encodeWithSelector(AccountFactory.createAccount.selector, OWNER.addr)
    );

    bytes memory callData = abi.encodeWithSelector(
      AbstractedAccount.execute.selector,
      address(counter),
      0,
      abi.encodeWithSelector(Counter.increment.selector, sender)
    );

    uint128 paymasterVerificationGasLimit = 100_000;
    uint128 paymasterPostOpGasLimit = 100_000;

    PackedUserOperation memory userOp = PackedUserOperation({
      nonce: entryPoint.getNonce(sender, 0),
      sender: sender,
      signature: "",
      paymasterAndData: _encodePaymasterAndData(
        address(paymaster), paymasterVerificationGasLimit, paymasterPostOpGasLimit
      ),
      gasFees: gasFees,
      preVerificationGas: preVerificationGas,
      accountGasLimits: accountGasLimits,
      initCode: initCode,
      callData: callData
    });

    bytes memory signature = this._getSignature(OWNER, userOp);
    userOp.signature = signature;

    PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
    userOps[0] = userOp;

    vm.deal(SPONSOR, SPONSOR_BALANCE);
    vm.prank(SPONSOR);
    entryPoint.depositTo{ value: 1 ether }(address(paymaster));
    entryPoint.handleOps(userOps, payable(BENEFICIARY));

    assertEq(counter.s_counts(sender), 1);
    assertEq(entryPoint.balanceOf(address(paymaster)) > 0, true);
    assertEq(entryPoint.balanceOf(sender), 0);
  }

  function _getSignature(
    Account calldata _account,
    PackedUserOperation calldata _userOp
  )
    public
    view
    returns (bytes memory)
  {
    bytes32 hash = entryPoint.getUserOpHash(_userOp);
    bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(hash);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_account.key, ethSignedHash);
    bytes memory signature = new bytes(65);
    assembly {
      mstore(add(signature, 32), r)
      mstore(add(signature, 64), s)
      mstore8(add(signature, 96), v)
    }
    return signature;
  }

  function _encodePaymasterAndData(
    address _paymaster,
    uint128 _paymasterVerificationGasLimit,
    uint128 _paymasterPostOpGasLimit
  )
    internal
    pure
    returns (bytes memory)
  {
    bytes memory result = new bytes(52);
    assembly {
      mstore(add(result, 32), shl(96, _paymaster))
      mstore(add(result, 52), shl(128, _paymasterVerificationGasLimit))
      mstore(add(result, 68), shl(128, _paymasterPostOpGasLimit))
    }
    return result;
  }
}
