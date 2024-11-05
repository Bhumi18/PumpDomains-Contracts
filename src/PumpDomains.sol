// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Counters.sol"; // Use the custom counter
import "./IPublicResolver.sol";
import "./DomainRecords.sol";

// import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; // Optional: For reentrancy protection

contract PumpDomains is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    // Unique token ID counter for NFTs
    Counters.Counter private _tokenIds;

    // Domain structure
    struct Domain {
        address resolver;
        uint256 expires;
        string name; // Store the original domain name
    }

    // Mapping from domain name hash to domain details
    mapping(bytes32 => Domain) public domains;

    // Mapping from domain name hash to tokenId (ERC721 token)
    mapping(bytes32 => uint256) public domainToTokenId;

    // Reverse mapping: tokenId to domain hash
    mapping(uint256 => bytes32) public tokenIdToDomainHash;

    // TLD for the contract (e.g., .trx)
    string public tld;

    // Domain expiration period (in seconds)
    uint256 public domainExpirationPeriod = 365 days;

    // Pricing for different domain lengths (in TRX)
    uint256 public price3Letters = 10 * 1e18; // 10 TRX
    uint256 public price4Letters = 5 * 1e18; // 5 TRX
    uint256 public price5PlusLetters = 3 * 1e18; // 3 TRX

    // Reference to the public resolver contract
    IPublicResolver public publicResolver;

    // Fee receiver address
    address payable public feeReceiver;

    DomainRecords public domainRecords;

    // Events for domain activities
    event DomainRegistered(
        bytes32 indexed domain,
        address indexed owner,
        uint256 tokenId,
        uint256 expires
    );
    event ResolverSet(bytes32 indexed domain, address indexed resolver);
    event DomainRenewed(
        bytes32 indexed domain,
        address indexed owner,
        uint256 newExpires
    );

    // Constructor to set the name, symbol, TLD, resolver address, and fee receiver
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _tld,
        address _resolverAddress,
        address payable _feeReceiver,
        address _domainRecordsAddress
    ) ERC721(_name, _symbol) Ownable(msg.sender) {
        tld = _tld;
        publicResolver = IPublicResolver(_resolverAddress); // Use the interface
        feeReceiver = _feeReceiver; // Set the fee receiver
        domainRecords = DomainRecords(_domainRecordsAddress);
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

    // Modifier to ensure the caller is the NFT owner of a domain
    modifier onlyDomainOwner(bytes32 domainHash) {
        require(
            ownerOf(domainToTokenId[domainHash]) == msg.sender,
            "Not the domain owner"
        );
        _;
    }

    // Register a domain, mint the ERC721 token, set ownership, expiration, and resolver
    function registerDomain(string memory name) external payable {
        name = toLowerCase(name); // Convert to lowercase
        bytes32 domainHash = generateDomainHash(name);
        require(domainToTokenId[domainHash] == 0, "Domain already registered");

        // Calculate price based on domain length
        uint256 domainPrice = getDomainPrice(name);
        require(
            msg.value >= domainPrice,
            "Insufficient TRX sent for domain registration"
        );

        // Forward the domainPrice to the feeReceiver
        (bool sent, ) = feeReceiver.call{value: domainPrice}("");
        require(sent, "Failed to send fee to feeReceiver");

        // Refund excess payment if any
        if (msg.value > domainPrice) {
            (bool refundSent, ) = msg.sender.call{
                value: msg.value - domainPrice
            }("");
            require(refundSent, "Failed to refund excess payment");
        }

        // Mint NFT for the new domain
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        // Mint the NFT and transfer ownership to the caller
        _safeMint(msg.sender, newTokenId);
        domainToTokenId[domainHash] = newTokenId;
        tokenIdToDomainHash[newTokenId] = domainHash;

        // Set domain information with an expiration date
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

    // Function to get the price of a domain based on its length
    function getDomainPrice(string memory name) public view returns (uint256) {
        uint256 length = bytes(name).length;

        if (length == 3) {
            return price3Letters;
        } else if (length == 4) {
            return price4Letters;
        } else if (length >= 5) {
            return price5PlusLetters;
        } else {
            revert("Domain name is too short");
        }
    }

    function checkOwnership(
        string memory domainName
    ) external view returns (bool) {
        bytes32 domainHash = generateDomainHash(toLowerCase(domainName));
        uint256 tokenId = domainToTokenId[domainHash];
        return ownerOf(tokenId) == msg.sender;
    }

    // Renew an existing domain by extending its expiration
    function renewDomain(
        string memory name
    ) external payable onlyDomainOwner(generateDomainHash(toLowerCase(name))) {
        name = toLowerCase(name); // Convert to lowercase
        bytes32 domainHash = generateDomainHash(name);

        // Calculate renewal price based on domain length
        uint256 renewalPrice = getDomainPrice(name);
        require(
            msg.value >= renewalPrice,
            "Insufficient TRX sent for domain renewal"
        );

        // Forward the renewalPrice to the feeReceiver
        (bool sent, ) = feeReceiver.call{value: renewalPrice}("");
        require(sent, "Failed to send fee to feeReceiver");

        // Refund excess payment if any
        if (msg.value > renewalPrice) {
            (bool refundSent, ) = msg.sender.call{
                value: msg.value - renewalPrice
            }("");
            require(refundSent, "Failed to refund excess payment");
        }

        // Extend the domain's expiration date
        domains[domainHash].expires += domainExpirationPeriod;

        emit DomainRenewed(domainHash, msg.sender, domains[domainHash].expires);
    }

    // Set or change the resolver for a domain
    function setResolver(
        string memory name,
        address resolver
    ) external onlyDomainOwner(generateDomainHash(toLowerCase(name))) {
        name = toLowerCase(name); // Convert to lowercase
        bytes32 domainHash = generateDomainHash(name);
        domains[domainHash].resolver = resolver;
        emit ResolverSet(domainHash, resolver); // Emit event for the new resolver
    }

    // Create a subdomain, mint an NFT for it, and assign the owner
    function createSubDomain(
        string memory parentName,
        string memory subName,
        address owner
    ) external onlyDomainOwner(generateDomainHash(toLowerCase(parentName))) {
        parentName = toLowerCase(parentName); // Convert to lowercase
        subName = toLowerCase(subName); // Convert to lowercase
        bytes32 parentHash = generateDomainHash(parentName);
        bytes32 subDomainHash = keccak256(
            abi.encodePacked(parentHash, subName)
        );

        require(
            domainToTokenId[subDomainHash] == 0,
            "Subdomain already exists"
        );

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

    // Get the resolver for a domain
    function getResolver(string memory name) external view returns (address) {
        bytes32 domainHash = generateDomainHash(toLowerCase(name)); // Convert to lowercase
        return domains[domainHash].resolver;
    }

    // Get the expiration date of a domain
    function getExpiration(string memory name) external view returns (uint256) {
        bytes32 domainHash = generateDomainHash(toLowerCase(name)); // Convert to lowercase
        return domains[domainHash].expires;
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

    // Generate a unique domain hash based on the name and TLD
    function generateDomainHash(
        string memory name
    ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(toLowerCase(name), ".", tld));
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

    // Set primary domain for the user
    function setPrimaryDomain(string memory name) external {
        bytes32 domainHash = generateDomainHash(toLowerCase(name));
        require(domainToTokenId[domainHash] != 0, "Domain does not exist"); // Check if the domain is registered
        require(
            ownerOf(domainToTokenId[domainHash]) == msg.sender,
            "Not the domain owner"
        ); // Check ownership
        publicResolver.setPrimaryDomain(msg.sender, domainHash); // Call to set primary domain using the interface
    }
}
