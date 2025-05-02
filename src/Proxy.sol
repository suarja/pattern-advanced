// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title ProxyVote
 * @dev Proxy contract that delegates calls to a voting implementation contract.
 * Uses OpenZeppelin's ERC1967Proxy for UUPS upgradeability pattern.
 */
contract ProxyVote is ERC1967Proxy {
    /**
     * @dev Constructor that sets up the proxy with an initial implementation and initialization data.
     * @param implementation Address of the initial implementation contract
     * @param data Initialization data to be passed to the implementation
     */
    constructor(address implementation, bytes memory data) ERC1967Proxy(implementation, data) {}

    /**
     * @dev Returns the current implementation address.
     * @return The address of the current implementation contract
     */
    function getImplementation() public view returns (address) {
        return _implementation();
    }
}
