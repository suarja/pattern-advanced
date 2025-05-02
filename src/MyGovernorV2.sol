// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {MyGovernor} from "./MyGovernor.sol";

/**
 * @title MyGovernorV2
 * @dev Upgraded version of MyGovernor with additional features.
 * Demonstrates the upgradeability pattern by adding new functionality.
 */
contract MyGovernorV2 is MyGovernor {
    /* ========== NEW STATE VARIABLES ========== */

    uint256 public constant VERSION = 2;

    struct Challenge {
        string name;
        string description;
        uint256 deadline;
        bool completed;
    }

    Challenge[] public challenges;

    /* ========== ENHANCED FUNCTIONALITY ========== */

    /**
     * @dev Returns the version of this implementation.
     * @return The current version number
     */
    function getVersion() public pure returns (uint256) {
        return VERSION;
    }

    /**
     * @dev Creates a new challenge.
     * @param _name Name of the challenge
     * @param _description Description of the challenge
     * @param _deadline Deadline for completing the challenge
     */
    function createChallenge(string memory _name, string memory _description, uint256 _deadline) public {
        challenges.push(Challenge({name: _name, description: _description, deadline: _deadline, completed: false}));
    }

    /**
     * @dev Gets a challenge by ID.
     * @param challengeId ID of the challenge
     * @return The challenge data
     */
    function getChallenge(uint256 challengeId) public view returns (Challenge memory) {
        return challenges[challengeId];
    }

    /**
     * @dev Enhanced canVote function that also considers challenge participation.
     * @param questId ID of the quest
     * @param voter Address of the potential voter
     * @return Whether the address can vote
     */
    function canVote(uint256 questId, address voter) public view override returns (bool) {
        bool baseCanVote = super.canVote(questId, voter);

        return baseCanVote || _hasCompletedAnyChallenge(voter);
    }

    /**
     * @dev Checks if a user has completed any challenge.
     * @param user Address to check
     * @return Whether the user has completed any challenge
     */
    function _hasCompletedAnyChallenge(address user) internal view returns (bool) {
        // Simplified implementation - in a real contract this would check user's challenge completions
        return false;
    }
}
