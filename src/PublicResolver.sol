// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PublicResolver {
    // Mapping from domain (hash) to the address that owns the domain
    mapping(bytes32 => address) private domainToAddress;

    // Mapping from address to primary domain hash
    mapping(address => bytes32) private primaryDomain;

    // Events
    event PrimaryDomainSet(address indexed owner, bytes32 indexed domainHash);
    event DomainLinked(bytes32 indexed domainHash, address indexed owner);

    /**
     * @dev Links a domain to an address. Can only be called from the TLD contract.
     * @param domainHash The hash of the domain.
     * @param owner The owner address of the domain.
     */
    function linkDomainToAddress(bytes32 domainHash, address owner) external {
        require(owner != address(0), "Owner address cannot be zero");
        domainToAddress[domainHash] = owner;
        emit DomainLinked(domainHash, owner);
    }

    /**
     * @dev Sets a primary domain for a specified address.
     * @param owner The address to set the primary domain for.
     * @param domainHash The hash of the domain to set as primary.
     */
    function setPrimaryDomain(address owner, bytes32 domainHash) external {
        require(owner != address(0), "Owner cannot be zero address");
        require(domainToAddress[domainHash] == owner, "Not the domain owner");

        primaryDomain[owner] = domainHash;
        emit PrimaryDomainSet(owner, domainHash);
    }

    /**
     * @dev Resolves a domain hash to the owner address.
     * @param domainHash The hash of the domain.
     * @return The address associated with the domain hash.
     */
    function resolveDomainToAddress(
        bytes32 domainHash
    ) external view returns (address) {
        address owner = domainToAddress[domainHash];
        require(owner != address(0), "Domain not linked");
        return owner;
    }

    /**
     * @dev Resolves an address to their primary domain hash.
     * @param owner The address whose primary domain to resolve.
     * @return The primary domain hash associated with the address.
     */
    function resolveAddressToDomain(
        address owner
    ) external view returns (bytes32) {
        bytes32 domainHash = primaryDomain[owner];
        require(domainHash != bytes32(0), "Primary domain not set");
        return domainHash;
    }

    /**
     * @dev Resolves an address to their primary domain as a string (full domain).
     * @param owner The address whose primary domain to resolve.
     * @return The primary domain as a string.
     */
    function resolveAddressToFullDomain(
        address owner
    ) external view returns (string memory) {
        bytes32 domainHash = primaryDomain[owner];
        require(domainHash != bytes32(0), "Primary domain not set");
        return string(abi.encodePacked(domainHash)); // Modify if necessary for full domain name
    }
}
