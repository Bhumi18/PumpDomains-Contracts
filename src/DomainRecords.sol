// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DomainRecords {
    // Struct to store detailed information about a registered domain
    struct RegisteredDomain {
        string nameWithTld; // Full domain name with TLD
        address owner; // Owner's address
        uint256 registrationDate; // Timestamp of registration
        uint256 expirationDate; // Expiration date
        uint256 registrationPrice; // Price paid for registration
    }

    // Array to store all registered domains
    RegisteredDomain[] public registeredDomains;

    // Mapping from factory address to the array of registered domain indices
    mapping(address => uint256[]) public domainsByFactory;

    // Mapping from owner address to the array of registered domain indices
    mapping(address => uint256[]) public domainsByOwner;

    // Event for when a domain is added to the records
    event DomainRecorded(
        string nameWithTld,
        address indexed owner,
        uint256 registrationDate,
        uint256 expirationDate,
        uint256 registrationPrice,
        address indexed factoryAddress // Include factory address in the event
    );

    // Function to add a domain record
    function recordDomain(
        string memory nameWithTld,
        address owner,
        uint256 registrationDate,
        uint256 expirationDate,
        uint256 registrationPrice,
        address factoryAddress // Accept factory address
    ) external {
        registeredDomains.push(
            RegisteredDomain({
                nameWithTld: nameWithTld,
                owner: owner,
                registrationDate: registrationDate,
                expirationDate: expirationDate,
                registrationPrice: registrationPrice
            })
        );

        // Link the registered domain index to the factory address
        domainsByFactory[factoryAddress].push(registeredDomains.length - 1);

        // Link the registered domain index to the owner's address
        domainsByOwner[owner].push(registeredDomains.length - 1);

        emit DomainRecorded(
            nameWithTld,
            owner,
            registrationDate,
            expirationDate,
            registrationPrice,
            factoryAddress
        );
    }

    // Function to get all registered domains
    function getAllRegisteredDomains()
        external
        view
        returns (RegisteredDomain[] memory)
    {
        return registeredDomains;
    }

    // Function to get a specific domain by index
    function getDomainByIndex(
        uint256 index
    ) external view returns (RegisteredDomain memory) {
        require(index < registeredDomains.length, "Index out of bounds");
        return registeredDomains[index];
    }

    // Function to get all registered domains for a specific factory address
    function getDomainsByFactory(
        address factoryAddress
    ) external view returns (RegisteredDomain[] memory) {
        uint256[] memory indices = domainsByFactory[factoryAddress];
        RegisteredDomain[] memory domainsForFactory = new RegisteredDomain[](
            indices.length
        );

        for (uint256 i = 0; i < indices.length; i++) {
            domainsForFactory[i] = registeredDomains[indices[i]];
        }

        return domainsForFactory;
    }

    // Function to get all registered domains for a specific owner address
    function getDomainsByOwner(
        address owner
    ) external view returns (RegisteredDomain[] memory) {
        uint256[] memory indices = domainsByOwner[owner];
        RegisteredDomain[] memory domainsForOwner = new RegisteredDomain[](
            indices.length
        );

        for (uint256 i = 0; i < indices.length; i++) {
            domainsForOwner[i] = registeredDomains[indices[i]];
        }

        return domainsForOwner;
    }
}
