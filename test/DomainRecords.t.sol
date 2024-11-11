// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";

import "../src/DomainRecords.sol";
import "../src/TLDFactory.sol";

contract DomainRecordsTest is Test {
    DomainRecords private domainRecords;
    TLDFactory private tldfactory;

    address user = vm.envAddress("USER");
    string nameWithTld = "bhumiCTB";
    address owner = user;
    uint256 registrationDate = 1657675200; // Example timestamp
    uint256 expirationDate = 1689211200; // Example timestamp
    uint256 registrationPrice = 1 ether;
    address factoryAddress;

    function setUp() public {
        domainRecords = new DomainRecords();
        tldfactory = new TLDFactory(
            user,
            payable(user),
            address(domainRecords)
        );
        factoryAddress = address(tldfactory);
    }
}
