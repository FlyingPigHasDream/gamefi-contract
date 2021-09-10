// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.7.3;


interface IChainlink {
  function latestAnswer() external view returns (int256);
}