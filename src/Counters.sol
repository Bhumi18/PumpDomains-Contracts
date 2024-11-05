// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Counters {
    struct Counter {
        uint256 value; // Counter value
    }

    // Function to increment the counter
    function increment(Counter storage counter) internal {
        counter.value += 1;
    }

    // Function to get the current value of the counter
    function current(Counter storage counter) internal view returns (uint256) {
        return counter.value;
    }

    // Function to reset the counter
    function reset(Counter storage counter) internal {
        counter.value = 0;
    }
}
