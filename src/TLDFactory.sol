// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PumpDomains.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TLDFactory is Ownable {
    struct Config {
        address resolver;
        address domainRecords;
        address payable feeReceiver;
        uint256 fee;
    }
    Config public config;

    mapping(string => address) private tlds;

    event TLDDeployed(
        address indexed creator,
        address indexed tldAddress,
        string indexed tldName
    );

    constructor(
        address _resolver,
        address _domainRecords,
        address payable _feeReceiver,
        uint256 _fee
    ) Ownable(msg.sender) {
        require(
            _resolver != address(0) &&
                _feeReceiver != address(0) &&
                _domainRecords != address(0),
            "Invalid address"
        );

        config = Config({
            resolver: _resolver,
            domainRecords: _domainRecords,
            feeReceiver: _feeReceiver,
            fee: _fee
        });
    }

    // Deploy a new PumpDomains contract for a specific TLD and collect a fee
    function deployTLD(
        string memory name,
        string memory symbol,
        string memory tld
    ) external payable returns (address) {
        require(tlds[tld] == address(0), "TLD already exists");
        require(msg.value == config.fee, "Incorrect TLD creation fee");

        // Forward the TLD creation fee to the feeReceiver
        (bool sent, ) = config.feeReceiver.call{value: msg.value}("");
        require(sent, "Fee transfer failed");

        // Create a new PumpDomains contract instance
        PumpDomains newTLD = new PumpDomains(
            name,
            symbol,
            tld,
            config.resolver,
            config.feeReceiver,
            config.domainRecords
        );

        tlds[tld] = address(newTLD);
        newTLD.transferOwnership(msg.sender);

        emit TLDDeployed(msg.sender, address(newTLD), tld);

        return address(newTLD);
    }

    // Allow the fee receiver to withdraw any accumulated funds
    function withdraw() external {
        require(msg.sender == config.feeReceiver, "Not authorized");
        (bool success, ) = config.feeReceiver.call{
            value: address(this).balance
        }("");
        require(success, "Withdrawal failed");
    }

    // Get the address of a TLD contract
    function getTLDAddress(
        string calldata tld
    ) external view returns (address) {
        return tlds[tld];
    }

    function setConfig(
        address _resolver,
        address _domainRecords,
        address payable _feeReceiver,
        uint256 _fee
    ) external onlyOwner {
        config = Config({
            resolver: _resolver,
            domainRecords: _domainRecords,
            feeReceiver: _feeReceiver,
            fee: _fee
        });
    }
}
