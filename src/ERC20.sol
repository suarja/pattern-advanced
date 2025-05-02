// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MyToken
 * @dev Simple ERC20 token implementation with minting capability.
 * Used for governance rights in the MyGovernor contract.
 */
contract MyToken is ERC20, Ownable {
    /**
     * @dev Constructor that sets name and symbol for the token.
     * Initializes with "MyToken" as name and "MTK" as symbol.
     */
    constructor() ERC20("MyToken", "MTK") Ownable(msg.sender) {}

    /**
     * @dev Creates `amount` tokens and assigns them to `to`.
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     *
     * Note: In a production environment, this function should be
     * restricted to privileged roles (e.g., with Ownable).
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
