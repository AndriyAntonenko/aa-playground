// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract Counter {
  mapping(address => uint256) public s_counts;

  function increment(address _account) public {
    s_counts[_account]++;
  }
}
