// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import OpenZeppelin Contracts for Ownership and Security
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title FeeReceiver
 * @dev A contract to receive and manage fees from domain registrations and renewals.
 */
contract FeeReceiver is Ownable, ReentrancyGuard {
    // Events to log incoming funds and withdrawals
    event FundsReceived(address indexed sender, uint256 amount);
    event FundsWithdrawn(address indexed receiver, uint256 amount);

    /**
     * @dev Constructor that sets the initial owner.
     * @param initialOwner The address of the initial owner.
     */
    constructor(address initialOwner) Ownable(initialOwner) ReentrancyGuard() {
        require(
            initialOwner != address(0),
            "Initial owner cannot be zero address"
        );
    }

    /**
     * @dev Emitted when the contract receives funds without data.
     */
    receive() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }

    /**
     * @dev Emitted when the contract receives funds with data.
     */
    fallback() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }

    /**
     * @dev Allows the owner to withdraw a specified amount of funds to a designated address.
     * @param to The address to receive the withdrawn funds.
     * @param amount The amount of funds to withdraw (in wei).
     */
    function withdraw(
        address payable to,
        uint256 amount
    ) external onlyOwner nonReentrant {
        require(to != address(0), "Invalid recipient address");
        require(
            address(this).balance >= amount,
            "Insufficient funds in contract"
        );

        // Transfer the specified amount to the recipient
        (bool success, ) = to.call{value: amount}("");
        require(success, "Withdrawal failed");

        emit FundsWithdrawn(to, amount);
    }

    /**
     * @dev Allows the owner to withdraw all available funds to a designated address.
     * @param to The address to receive the withdrawn funds.
     */
    function withdrawAll(address payable to) external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds available for withdrawal");
        require(to != address(0), "Invalid recipient address");

        // Transfer the entire balance to the recipient
        (bool success, ) = to.call{value: balance}("");
        require(success, "Withdrawal failed");

        emit FundsWithdrawn(to, balance);
    }

    /**
     * @dev Returns the current balance of the contract.
     * @return The balance of the contract in wei.
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
