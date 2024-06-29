// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { PackedUserOperation } from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import { UserOperationLib } from "@account-abstraction/contracts/core/UserOperationLib.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { Counter } from "../src/mocks/Counter.sol";

import { EntryPoint } from "../src/EntryPoint.sol";
import { Paymaster } from "../src/Paymaster.sol";
import { AbstractedAccount } from "../src/Account.sol";
import { AccountFactory } from "../src/AccountFactory.sol";
import { Deploy } from "../script/Deploy.s.sol";

contract AccountTest is Test {
  Counter public counter;
  Account public PAYMASTER_SIGNER = makeAccount("PAYMASTER_SIGNER");
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
    (accountFactory, entryPoint, paymaster) = deployer.deploy(PAYMASTER_SIGNER.addr);
  }

  function testUserOp_succesfull() public {
    uint256 maxFeePerGas = 10 gwei;
    uint256 maxPriorityFeePerGas = 5 gwei;
    bytes32 gasFees = bytes32((maxPriorityFeePerGas << 128) | maxFeePerGas);
    uint256 preVerificationGas = 50_000;
    uint256 verificationGasLimit = 1_000_000;
    uint256 callGasLimit = 200_000;
    bytes32 accountGasLimits = bytes32((verificationGasLimit << 128) | callGasLimit);

    // accountFactory + calldata
    bytes32 salt = bytes32(uint256(0));
    address sender = accountFactory.predictAccountAddress(OWNER.addr, salt);
    bytes memory initCode = abi.encodePacked(
      address(accountFactory), abi.encodeWithSelector(AccountFactory.createAccount.selector, OWNER.addr, salt)
    );

    bytes memory callData = abi.encodeWithSelector(
      AbstractedAccount.execute.selector,
      address(counter),
      0,
      abi.encodeWithSelector(Counter.increment.selector, sender)
    );

    uint128 paymasterVerificationGasLimit = 1_000_000;
    uint128 paymasterPostOpGasLimit = 0;

    console.logBytes(
      _encodePaymasterWithoutData(address(paymaster), paymasterVerificationGasLimit, paymasterPostOpGasLimit)
    );
    PackedUserOperation memory userOp = PackedUserOperation({
      nonce: entryPoint.getNonce(sender, 0),
      sender: sender,
      signature: "",
      paymasterAndData: _encodePaymasterWithoutData(
        address(paymaster), paymasterVerificationGasLimit, paymasterPostOpGasLimit
      ),
      gasFees: gasFees,
      preVerificationGas: preVerificationGas,
      accountGasLimits: accountGasLimits,
      initCode: initCode,
      callData: callData
    });

    uint48 validUntil = uint48(block.timestamp + 1 minutes);
    uint48 validAfter = uint48(block.timestamp);
    bytes memory paymasterSignature =
      this._getPaymasterSignatureForUserOp(PAYMASTER_SIGNER, userOp, validUntil, validAfter);

    bytes memory paymasterAndData = _encodePaymasterAndData(
      address(paymaster),
      paymasterVerificationGasLimit,
      paymasterPostOpGasLimit,
      validUntil,
      validAfter,
      paymasterSignature
    );

    userOp.paymasterAndData = paymasterAndData;

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

  /*//////////////////////////////////////////////////////////////
                              HELPERS
  //////////////////////////////////////////////////////////////*/

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

  function _getPaymasterSignatureForUserOp(
    Account calldata _account,
    PackedUserOperation calldata _userOp,
    uint48 _validUntil,
    uint48 _validAfter
  )
    public
    view
    returns (bytes memory)
  {
    bytes32 hash = paymaster.getHash(_userOp, _validUntil, _validAfter);
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
    uint128 _paymasterPostOpGasLimit,
    uint48 _validUntil,
    uint48 _validAfter,
    bytes memory _signature
  )
    internal
    pure
    returns (bytes memory)
  {
    bytes memory withoutData =
      _encodePaymasterWithoutData(_paymaster, _paymasterVerificationGasLimit, _paymasterPostOpGasLimit);
    return abi.encodePacked(withoutData, _validUntil, _validAfter, _signature);
  }

  function _encodePaymasterWithoutData(
    address _paymaster,
    uint128 _paymasterVerificationGasLimit,
    uint128 _paymasterPostOpGasLimit
  )
    internal
    pure
    returns (bytes memory)
  {
    bytes32 result = bytes32((uint256(_paymasterVerificationGasLimit) << 128) | uint256(_paymasterPostOpGasLimit));
    return abi.encodePacked(_paymaster, result);
  }
}
