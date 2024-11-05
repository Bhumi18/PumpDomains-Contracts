// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PublicResolver {
    // Mapping from domain (hash) to the address that owns the domain
    mapping(bytes32 => address) public domainToAddress;

    // Mapping from address to primary domain hash
    mapping(address => bytes32) public primaryDomain;

    // Event emitted when a primary domain is set
    event PrimaryDomainSet(address indexed owner, bytes32 indexed domainHash);

    // Event emitted when a domain is linked to an address
    event DomainLinked(bytes32 indexed domainHash, address indexed owner);

    // Function to link a domain to an address (called from the TLD contract)
    function linkDomainToAddress(bytes32 domainHash, address owner) external {
        domainToAddress[domainHash] = owner;
        emit DomainLinked(domainHash, owner);
    }

    // Function to set a primary domain for an address
    function setPrimaryDomain(address owner, bytes32 domainHash) external {
        require(owner != address(0), "Owner address cannot be zero.");
        require(
            domainToAddress[domainHash] == owner,
            "Provided owner is not the domain owner."
        );
        primaryDomain[owner] = domainHash;
        emit PrimaryDomainSet(owner, domainHash);
    }

    // Function to resolve a domain to an address
    function resolveDomainToAddress(
        bytes32 domainHash
    ) external view returns (address) {
        address owner = domainToAddress[domainHash];
        require(owner != address(0), "Domain does not exist");
        return owner;
    }

    // Function to resolve an address to their primary domain
    function resolveAddressToDomain(
        address owner
    ) external view returns (bytes32) {
        bytes32 primaryDomainHash = primaryDomain[owner];
        require(
            primaryDomainHash != bytes32(0),
            "No primary domain set for this address"
        );
        return primaryDomainHash;
    }

    // Function to resolve an address to the corresponding domain name
    function resolveAddressToFullDomain(
        address owner
    ) external view returns (string memory) {
        bytes32 primaryDomainHash = primaryDomain[owner];
        require(
            primaryDomainHash != bytes32(0),
            "No primary domain set for this address"
        );
        return string(abi.encodePacked(primaryDomainHash)); // Change this according to your domain name generation logic
    }
}
