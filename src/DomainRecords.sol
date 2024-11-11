// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DomainRecords {
    // Struct to store detailed information about a registered domain
    struct RegisteredDomain {
        string nameWithTld; // Full domain name with TLD
        address owner; // Owner's address
        uint256 registrationDate; // Registration timestamp
        uint256 expirationDate; // Expiration timestamp
        uint256 registrationPrice; // Price paid for registration
    }

    // Array to store all registered domains
    RegisteredDomain[] private registeredDomains;

    // Mapping from factory address to the array of registered domain indices
    mapping(address => uint256[]) private domainsByFactory;

    // Mapping from owner address to the array of registered domain indices
    mapping(address => uint256[]) private domainsByOwner;

    // Event for when a domain is added to the records
    event DomainRecorded(
        string indexed nameWithTld, // Index the domain name for easier searching in logs
        address indexed owner,
        uint256 registrationDate,
        uint256 expirationDate,
        uint256 registrationPrice,
        address indexed factoryAddress
    );

    // Function to add a domain record
    function recordDomain(
        string calldata nameWithTld,
        address owner,
        uint256 registrationDate,
        uint256 expirationDate,
        uint256 registrationPrice,
        address factoryAddress
    ) external {
        // Cache length for gas optimization
        uint256 domainIndex = registeredDomains.length;

        // Add the new domain directly to storage array to save gas
        registeredDomains.push(
            RegisteredDomain({
                nameWithTld: nameWithTld,
                owner: owner,
                registrationDate: registrationDate,
                expirationDate: expirationDate,
                registrationPrice: registrationPrice
            })
        );

        // Store references to the domain index
        domainsByFactory[factoryAddress].push(domainIndex);
        domainsByOwner[owner].push(domainIndex);

        emit DomainRecorded(
            nameWithTld,
            owner,
            registrationDate,
            expirationDate,
            registrationPrice,
            factoryAddress
        );
    }

    // Optimized function to get all registered domains
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
        uint256[] storage indices = domainsByFactory[factoryAddress];
        uint256 length = indices.length;
        RegisteredDomain[] memory domainsForFactory = new RegisteredDomain[](
            length
        );

        for (uint256 i = 0; i < length; ++i) {
            domainsForFactory[i] = registeredDomains[indices[i]];
        }

        return domainsForFactory;
    }

    // Function to get all registered domains for a specific owner address
    function getDomainsByOwner(
        address owner
    ) external view returns (RegisteredDomain[] memory) {
        uint256[] storage indices = domainsByOwner[owner];
        uint256 length = indices.length;
        RegisteredDomain[] memory domainsForOwner = new RegisteredDomain[](
            length
        );

        for (uint256 i = 0; i < length; ++i) {
            domainsForOwner[i] = registeredDomains[indices[i]];
        }

        return domainsForOwner;
    }
}
