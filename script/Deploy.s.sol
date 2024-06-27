// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script } from "forge-std/Script.sol";
import { EntryPoint } from "../src/EntryPoint.sol";
import { AccountFactory } from "../src/Account.sol";
import { Paymaster } from "../src/Paymaster.sol";

contract Deploy is Script {
  function run() public {
    vm.startBroadcast();
    deploy();
    vm.stopBroadcast();
  }

  function deploy() public returns (AccountFactory, EntryPoint, Paymaster) {
    AccountFactory accountFactory = new AccountFactory();
    EntryPoint entryPoint = new EntryPoint();
    Paymaster paymaster = new Paymaster();
    return (accountFactory, entryPoint, paymaster);
  }
}
