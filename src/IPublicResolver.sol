// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPublicResolver {
    function linkDomainToAddress(bytes32 domainHash, address owner) external;

    function setPrimaryDomain(address owner, bytes32 domainHash) external;

    function resolveDomainToAddress(
        bytes32 domainHash
    ) external view returns (address);

    function primaryDomain(address owner) external view returns (bytes32);

    function resolveAddressToDomain(
        address owner
    ) external view returns (bytes32);

    function resolveAddressToFullDomain(
        address owner
    ) external view returns (string memory);
}
