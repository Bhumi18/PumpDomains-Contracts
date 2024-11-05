// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PumpDomains.sol";

contract TLDFactory {
    // Event emitted when a new TLD is deployed
    event TLDDeployed(
        address indexed creator,
        address indexed tldAddress,
        string tldName
    );

    // Mapping to store deployed TLD contracts
    mapping(string => address) public tldContracts;

    // Static public resolver address
    address public publicResolver;
    address public domainRecordsAddress;

    // Fee for creating a TLD
    uint256 public constant TLD_CREATION_FEE = 50 * 1e18;

    // Address to receive the fees (owner of the contract)
    address payable public feeReceiver;

    // Constructor to set the public resolver address and fee receiver (owner)
    constructor(
        address _publicResolver,
        address payable _feeReceiver,
        address _domainRecordsAddress
    ) {
        publicResolver = _publicResolver;
        feeReceiver = _feeReceiver;
        domainRecordsAddress = _domainRecordsAddress;
    }

    // Deploy a new PumpDomains contract for a specific TLD and collect a fee
    function deployTLD(
        string memory name,
        string memory symbol,
        string memory tld
    ) external payable returns (address) {
        require(tldContracts[tld] == address(0), "TLD already exists");
        require(
            msg.value >= TLD_CREATION_FEE,
            "Insufficient funds sent for TLD creation"
        );

        // Forward the TLD creation fee to the feeReceiver
        (bool feeSent, ) = feeReceiver.call{value: msg.value}("");
        require(feeSent, "Failed to send TLD creation fee to feeReceiver");

        // Create a new PumpDomains contract instance with the predefined public resolver address and feeReceiver
        PumpDomains newTLD = new PumpDomains(
            name,
            symbol,
            tld,
            publicResolver,
            feeReceiver,
            domainRecordsAddress
        );

        // Store the address of the newly deployed TLD contract
        tldContracts[tld] = address(newTLD);

        // Transfer ownership of the new contract to the sender
        newTLD.transferOwnership(msg.sender);

        emit TLDDeployed(msg.sender, address(newTLD), tld);

        return address(newTLD);
    }

    // Allow the owner to withdraw any accumulated funds
    function withdrawFunds() external {
        require(
            msg.sender == feeReceiver,
            "Only the fee receiver can withdraw funds"
        );
        (bool success, ) = feeReceiver.call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }

    // Get the address of a TLD contract
    function getTLDAddress(string memory tld) external view returns (address) {
        return tldContracts[tld];
    }
}
