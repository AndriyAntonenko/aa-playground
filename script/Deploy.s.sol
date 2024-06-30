// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script } from "forge-std/Script.sol";
import { IEntryPoint } from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { EntryPoint } from "../src/EntryPoint.sol";
import { AccountFactory } from "../src/AccountFactory.sol";
import { Paymaster } from "../src/Paymaster.sol";

contract Deploy is Script {
  function run() public {
    address paymasterSigner = vm.envAddress("PAYMASTER_SIGNER");
    address entryPoint = vm.envAddress("ENTRY_POINT"); // entry point suported by bundeler

    vm.startBroadcast();
    deployWithExternalEntryPoint(payable(entryPoint), paymasterSigner);
    vm.stopBroadcast();
  }

  function deployWithExternalEntryPoint(address payable _entryPoint, address _paymasterSigner) public {
    IEntryPoint entryPoint = IEntryPoint(_entryPoint);
    new AccountFactory(entryPoint);
    new Paymaster(entryPoint, _paymasterSigner);
  }

  function deploy(address _paymasterSigner) public returns (AccountFactory, EntryPoint, Paymaster) {
    EntryPoint entryPoint = new EntryPoint();
    AccountFactory accountFactory = new AccountFactory(entryPoint);
    Paymaster paymaster = new Paymaster(entryPoint, _paymasterSigner);
    return (accountFactory, entryPoint, paymaster);
  }
}
