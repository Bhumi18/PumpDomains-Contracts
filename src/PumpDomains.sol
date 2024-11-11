// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Counters.sol"; // Use the custom counter
import "./IPublicResolver.sol";
import "./DomainRecords.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error DomainAlreadyRegistered();
error InsufficientPayment();
error TransferFailed();
error InvalidDomainLength();
error NotDomainOwner();
error DomainNotFound();
error Unauthorized();

contract PumpDomains is ERC721URIStorage, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    // Events
    event DomainRegistered(
        bytes32 indexed domain,
        address indexed owner,
        uint256 tokenId,
        uint256 expires
    );
    event DomainRenewed(
        bytes32 indexed domain,
        address indexed owner,
        uint256 newExpires
    );
    event ResolverSet(bytes32 indexed domain, address indexed resolver);

    struct Domain {
        address resolver;
        uint256 expires;
        string name; // Store the original domain name
    }

    // Storage
    string public tld; // TLD for the contract (e.g., .trx)
    uint256 public domainExpirationPeriod = 365 days;
    Counters.Counter private _tokenIds;

    // Mapping from domain name hash to domain details
    mapping(bytes32 => Domain) public domains;

    // Mapping from domain name hash to tokenId (ERC721 token)
    mapping(bytes32 => uint256) public domainToTokenId;

    // Reverse mapping: tokenId to domain hash
    mapping(uint256 => bytes32) public tokenIdToDomainHash;

    // Dynamic pricing structure
    struct PriceConfig {
        uint256 length;
        uint256 price;
    }

    PriceConfig[] public priceConfigs;
    address payable public feeReceiver;
    IPublicResolver public publicResolver;
    DomainRecords public domainRecords;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _tld,
        address _resolverAddress,
        address payable _feeReceiver,
        address _domainRecordsAddress
    ) ERC721(_name, _symbol) Ownable(msg.sender) {
        tld = _tld;
        publicResolver = IPublicResolver(_resolverAddress);
        feeReceiver = _feeReceiver;
        domainRecords = DomainRecords(_domainRecordsAddress);

        // Initialize default price configs
        priceConfigs.push(PriceConfig(3, 10 ether));
        priceConfigs.push(PriceConfig(4, 5 ether));
        priceConfigs.push(PriceConfig(5, 3 ether));
    }

    // Register a domain, mint the ERC721 token, set ownership, expiration, and resolver
    function registerDomain(string memory name) external payable nonReentrant {
        name = toLowerCase(name); // Convert to lowercase
        bytes32 domainHash = generateDomainHash(name);
        if (domainToTokenId[domainHash] != 0) revert DomainAlreadyRegistered();

        uint256 domainPrice = getDomainPrice(name);
        if (msg.value < domainPrice) revert InsufficientPayment();

        // Forward the domainPrice to the feeReceiver
        (bool sent, ) = feeReceiver.call{value: domainPrice}("");
        if (!sent) revert TransferFailed();

        // Refund excess payment if any
        if (msg.value > domainPrice) {
            (bool refundSent, ) = msg.sender.call{
                value: msg.value - domainPrice
            }("");
            if (!refundSent) revert TransferFailed();
        }

        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        // Register domain
        _safeMint(msg.sender, newTokenId);
        domainToTokenId[domainHash] = newTokenId;
        tokenIdToDomainHash[newTokenId] = domainHash;

        uint256 registrationDate = block.timestamp;
        uint256 expirationDate = registrationDate + domainExpirationPeriod;

        domains[domainHash] = Domain({
            resolver: msg.sender,
            expires: expirationDate,
            name: name
        });

        // Link the domain to the user's address in the public resolver
        publicResolver.linkDomainToAddress(domainHash, msg.sender);

        // Record the domain in the DomainRecords contract with all necessary details, including the factory address
        domainRecords.recordDomain(
            string(abi.encodePacked(name, ".", tld)), // Full domain name
            msg.sender, // Owner
            registrationDate, // Registration date
            expirationDate, // Expiration date
            domainPrice, // Registration price
            address(this) // Pass the current contract address as the factory address
        );

        emit DomainRegistered(
            domainHash,
            msg.sender,
            newTokenId,
            domains[domainHash].expires
        );
        emit ResolverSet(domainHash, msg.sender);
    }

    // Renew an existing domain by extending its expiration
    function renewDomain(string memory name) external payable nonReentrant {
        name = toLowerCase(name); // Convert to lowercase
        bytes32 domainHash = generateDomainHash(name);

        if (ownerOf(domainToTokenId[domainHash]) != msg.sender)
            revert NotDomainOwner();

        uint256 renewalPrice = getDomainPrice(name);
        if (msg.value < renewalPrice) revert InsufficientPayment();

        (bool sent, ) = feeReceiver.call{value: renewalPrice}("");
        if (!sent) revert TransferFailed();

        // Refund excess payment if any
        if (msg.value > renewalPrice) {
            (bool refundSent, ) = msg.sender.call{
                value: msg.value - renewalPrice
            }("");
            if (!refundSent) revert TransferFailed();
        }

        domains[domainHash].expires += domainExpirationPeriod;
        emit DomainRenewed(domainHash, msg.sender, domains[domainHash].expires);
    }

    // Set primary domain for the user
    function setPrimaryDomain(string memory name) external {
        bytes32 domainHash = generateDomainHash(toLowerCase(name));
        if (domainToTokenId[domainHash] == 0) revert DomainNotFound();
        if (ownerOf(domainToTokenId[domainHash]) != msg.sender)
            revert NotDomainOwner();
        publicResolver.setPrimaryDomain(msg.sender, domainHash); // Call to set primary domain using the interface
    }

    // Set or change the resolver for a domain
    function setResolver(string memory name, address resolver) external {
        name = toLowerCase(name); // Convert to lowercase
        bytes32 domainHash = generateDomainHash(name);
        if (ownerOf(domainToTokenId[domainHash]) != msg.sender)
            revert NotDomainOwner();
        domains[domainHash].resolver = resolver;
        emit ResolverSet(domainHash, resolver); // Emit event for the new resolver
    }

    function setPriceConfig(uint256 length, uint256 price) external onlyOwner {
        bool found = false;
        for (uint256 i = 0; i < priceConfigs.length; i++) {
            if (priceConfigs[i].length == length) {
                priceConfigs[i].price = price;
                found = true;
                break;
            }
        }
        if (!found) {
            priceConfigs.push(PriceConfig(length, price));
        }
    }

    function getDomainPrice(string memory name) public view returns (uint256) {
        uint256 length = bytes(name).length;
        for (uint256 i = 0; i < priceConfigs.length; i++) {
            if (length == priceConfigs[i].length) {
                return priceConfigs[i].price;
            }
        }
        revert InvalidDomainLength();
    }

    // Generate a unique domain hash based on the name and TLD
    function generateDomainHash(
        string memory name
    ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(toLowerCase(name), ".", tld));
    }

    // Helper function to convert a string to lowercase
    function toLowerCase(
        string memory str
    ) internal pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint256 i = 0; i < bStr.length; i++) {
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }

    // Get the expiration date of a domain
    function getExpiration(string memory name) external view returns (uint256) {
        bytes32 domainHash = generateDomainHash(toLowerCase(name)); // Convert to lowercase
        return domains[domainHash].expires;
    }

    // Get the resolver for a domain
    function getResolver(string memory name) external view returns (address) {
        bytes32 domainHash = generateDomainHash(toLowerCase(name)); // Convert to lowercase
        return domains[domainHash].resolver;
    }

    function checkOwnership(
        string memory domainName
    ) external view returns (bool) {
        bytes32 domainHash = generateDomainHash(toLowerCase(domainName));
        uint256 tokenId = domainToTokenId[domainHash];
        return ownerOf(tokenId) == msg.sender;
    }

    // Create a subdomain, mint an NFT for it, and assign the owner
    function createSubDomain(
        string memory parentName,
        string memory subName,
        address owner
    ) external {
        parentName = toLowerCase(parentName); // Convert to lowercase
        bytes32 parentHash = generateDomainHash(parentName);

        if (ownerOf(domainToTokenId[parentHash]) != msg.sender)
            revert NotDomainOwner();

        subName = toLowerCase(subName); // Convert to lowercase
        bytes32 subDomainHash = keccak256(
            abi.encodePacked(parentHash, subName)
        );

        if (domainToTokenId[subDomainHash] != 0)
            revert DomainAlreadyRegistered();

        _tokenIds.increment();
        uint256 newSubTokenId = _tokenIds.current();

        _safeMint(owner, newSubTokenId);

        domainToTokenId[subDomainHash] = newSubTokenId;
        tokenIdToDomainHash[newSubTokenId] = subDomainHash;

        domains[subDomainHash] = Domain(
            owner,
            block.timestamp + domainExpirationPeriod,
            subName
        );

        // Link the subdomain to the user's address in the public resolver
        publicResolver.linkDomainToAddress(subDomainHash, owner);

        emit DomainRegistered(
            subDomainHash,
            owner,
            newSubTokenId,
            domains[subDomainHash].expires
        );
    }

    // Get the full domain name (name + TLD) from the hash
    function getDomainName(
        bytes32 domainHash
    ) external view returns (string memory) {
        require(
            domains[domainHash].expires > block.timestamp,
            "Domain does not exist or has expired"
        );
        return string(abi.encodePacked(domains[domainHash].name, ".", tld));
    }

    // Burn a domain's token (for use cases like expiring domains)
    function burnDomain(string memory name) external onlyOwner {
        bytes32 domainHash = generateDomainHash(toLowerCase(name));
        uint256 tokenId = domainToTokenId[domainHash];
        require(tokenId != 0, "Domain does not exist");

        _burn(tokenId);
        delete domainToTokenId[domainHash];
        delete tokenIdToDomainHash[tokenId];
        delete domains[domainHash];
    }

    // Set the token URI for an NFT
    function setTokenURI(uint256 tokenId, string memory _tokenURI) external {
        require(
            msg.sender == ownerOf(tokenId) ||
                msg.sender == getApproved(tokenId) ||
                isApprovedForAll(ownerOf(tokenId), msg.sender),
            "Not approved or owner"
        );
        _setTokenURI(tokenId, _tokenURI);
    }
}
