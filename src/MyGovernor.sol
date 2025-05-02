// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712Upgradeable} from "@openzeppelin-upgradeable/contracts/utils/cryptography/EIP712Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title MyGovernor
 * @dev Upgradeable governance contract that manages voting quests with signature verification.
 * Implements UUPS upgradeability pattern and EIP-712 for structured signatures.
 */
contract MyGovernor is EIP712Upgradeable, UUPSUpgradeable {
    /* ========== ERRORS ========== */
    error VoteNotAllowed();
    error SignatureExpired();
    error InvalidSignature();
    error InvalidNonce();
    error ZeroAddress();
    error AlreadyVoted();
    error NotDelegated();

    /* ========== TYPES ========== */
    enum Vote {
        None,
        Yes,
        No
    }

    struct Quest {
        string name;
        string description;
        uint256 reward;
        address owner;
        uint256 startTime;
        uint256 endTime;
        string[] options;
    }

    /* ========== CONSTANTS ========== */

    /* ========== STATE VARIABLES ========== */
    mapping(uint256 => mapping(address => Vote)) public votes;
    mapping(address => uint256) public nonces;
    mapping(address => mapping(uint256 => address)) public voteDelegates; // voter => questId => delegate

    string public name;
    Quest[] public quests;
    ERC20 public token;

    /* ========== EVENTS ========== */
    event VoteCast(uint256 indexed questId, address indexed voter, Vote vote);
    event VoteCastByDelegate(uint256 indexed questId, address indexed voter, address indexed delegate, Vote vote);
    event VoteDelegated(address indexed voter, address indexed delegate, uint256 indexed questId);
    event VoteDelegationRevoked(address indexed voter, address indexed delegate, uint256 indexed questId);

    /* ========== INITIALIZER ========== */
    /**
     * @dev Initializes the contract with a name and governance token.
     * @param _name Name of the governance system
     * @param _token ERC20 token used for governance rights
     */
    function init(string memory _name, ERC20 _token) public initializer onlyInitializing {
        require(bytes(name).length == 0, "Already initialized");
        name = _name;
        token = _token;
        __EIP712_init(_name, "1");
    }

    /* ========== QUEST MANAGEMENT ========== */
    /**
     * @dev Creates a new quest with voting options.
     * @param _name Name of the quest
     * @param description Description of the quest
     * @param reward Reward amount for the quest
     * @param options Array of voting options
     */
    function createQuest(string memory _name, string memory description, uint256 reward, string[] memory options)
        public
        virtual
    {
        quests.push(Quest(_name, description, reward, msg.sender, block.timestamp, block.timestamp + 10 days, options));
    }

    /**
     * @dev Retrieves a quest by its ID.
     * @param questId ID of the quest to retrieve
     * @return The quest data
     */
    function getQuest(uint256 questId) public view returns (Quest memory) {
        return quests[questId];
    }

    /* ========== DELEGATION FUNCTIONALITY ========== */
    /**
     * @dev Delegates voting rights for a specific quest to another address.
     * @param questId ID of the quest to delegate voting for
     * @param delegate Address to delegate voting rights to
     */
    function delegateVote(uint256 questId, address delegate) public {
        if (delegate == address(0)) {
            revert ZeroAddress();
        }
        if (votes[questId][msg.sender] != Vote.None) {
            revert AlreadyVoted();
        }

        voteDelegates[msg.sender][questId] = delegate;
        emit VoteDelegated(msg.sender, delegate, questId);
    }

    /**
     * @dev Revokes a voting delegation for a specific quest.
     * @param questId ID of the quest to revoke delegation for
     */
    function revokeDelegation(uint256 questId) public {
        require(voteDelegates[msg.sender][questId] != address(0), "No delegation exists");
        if (votes[questId][msg.sender] != Vote.None) {
            revert AlreadyVoted();
        }
        address delegate = voteDelegates[msg.sender][questId];
        voteDelegates[msg.sender][questId] = address(0);
        emit VoteDelegationRevoked(msg.sender, delegate, questId);
    }

    /**
     * @dev Checks if an address has delegated voting rights for a quest to another address.
     * @param voter Address of the voter
     * @param questId ID of the quest
     * @return The delegate address or zero address if not delegated
     */
    function getDelegateFor(address voter, uint256 questId) public view returns (address) {
        return voteDelegates[voter][questId];
    }

    /* ========== VOTING FUNCTIONALITY ========== */
    /**
     * @dev Checks if an address is eligible to vote on a quest.
     * @param questId ID of the quest
     * @param voter Address of the potential voter
     * @return Whether the address can vote
     */
    function canVote(uint256 questId, address voter) public view virtual returns (bool) {
        if (token.balanceOf(voter) == 0) {
            return false;
        }

        Quest storage quest = quests[questId];
        if (quest.owner == address(0) || quest.startTime > block.timestamp || block.timestamp > quest.endTime) {
            return false;
        }

        if (votes[questId][voter] != Vote.None) {
            return false;
        }

        return true;
    }

    /**
     * @dev Returns the voting power of an address for a quest.
     * Default implementation: 1 token = 1 voting power
     * @param questId ID of the quest
     * @param voter Address of the voter
     * @return The voting power as a uint256
     */
    function getVotingPower(uint256 questId, address voter) public view virtual returns (uint256) {
        return token.balanceOf(voter);
    }

    /**
     * @dev Standard voting function for direct voting.
     * @param questId ID of the quest to vote on
     * @param voteOption The vote choice
     */
    function castVote(uint256 questId, Vote voteOption) public {
        _castVote(questId, msg.sender, voteOption);
    }

    /**
     * @dev Vote on behalf of a delegated address
     * @param questId ID of the quest to vote on
     * @param voter Address of the voter who delegated rights
     * @param voteOption The vote choice
     */
    function castVoteByDelegate(uint256 questId, address voter, Vote voteOption) public {
        if (voteDelegates[voter][questId] != msg.sender) {
            revert NotDelegated();
        }
        if (!canVote(questId, voter)) {
            revert VoteNotAllowed();
        }

        votes[questId][voter] = voteOption;
        emit VoteCastByDelegate(questId, voter, msg.sender, voteOption);
    }
    
    /**
     * @dev Vote using a signed message (meta-transaction pattern)
     * @param questId ID of the quest to vote on
     * @param voter Address of the voter
     * @param voteOption The vote choice
     * @param deadline Timestamp after which the signature is no longer valid
     * @param signature The signature bytes
     */
    function castVoteBySig(uint256 questId, address voter, Vote voteOption, uint256 deadline, bytes calldata signature)
        public
    {
        if (block.timestamp > deadline) {
            revert SignatureExpired();
        }

        uint256 currentNonce = nonces[voter];
        if (!canVote(questId, voter)) {
            revert VoteNotAllowed();
        }

        bytes32 structHash =
            keccak256(abi.encode( questId, voter, uint8(voteOption), currentNonce, deadline));

        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signature);

        if (signer != voter) {
            revert InvalidSignature();
        }

        nonces[voter] = currentNonce + 1;

        votes[questId][voter] = voteOption;
        emit VoteCast(questId, voter, voteOption);
    }

    /**
     * @dev Internal function to handle vote casting
     * @param questId ID of the quest to vote on
     * @param voter Address of the voter
     * @param voteOption The vote choice
     */
    function _castVote(uint256 questId, address voter, Vote voteOption) internal {
        if (!canVote(questId, voter)) {
            revert VoteNotAllowed();
        }

        votes[questId][voter] = voteOption;
        emit VoteCast(questId, voter, voteOption);
    }

    /**
     * @dev Returns the name of the governance system.
     * @return The governance system name
     */
    function getName() public view returns (string memory) {
        return name;
    }

    /**
     * @dev Returns the current nonce for a voter
     * @param voter Address of the voter
     * @return The current nonce
     */
    function getNonce(address voter) public view returns (uint256) {
        return nonces[voter];
    }

    /* ========== UPGRADEABILITY ========== */
    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract.
     * @param newImplementation Address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyProxy {}

    /* ========== UTILS ========== */
    function getDomainSeparator() public view returns (bytes32) {
        return _domainSeparatorV4();
    }
}
