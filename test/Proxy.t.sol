// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {MyGovernorV2} from "../src/MyGovernorV2.sol";
import {ProxyVote} from "../src/Proxy.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
/**
 * @title ProxyTest
 * @dev Test suite for demonstrating two advanced patterns:
 *   1. UUPS Upgradeability
 *   2. Signature-based authorization with EIP-712
 */

contract ProxyTest is Test {
    // Contract instances
    MyGovernor public implementation;
    MyGovernorV2 public implementationV2;
    ProxyVote public proxy;
    ERC20Mock public token;

    // Helpers
    MyGovernor public proxyAsGovernor;

    // Constants
    bytes4 private constant CAST_VOTE_SELECTOR = bytes4(keccak256("castVote(uint256,uint8)"));
    bytes4 private constant CAST_VOTE_BY_SIG_SELECTOR =
        bytes4(keccak256("castVoteBySig(uint256,address,uint8,uint256,bytes)"));
    bytes4 private constant DELEGATE_VOTE_SELECTOR = bytes4(keccak256("delegateVote(uint256,address)"));
    bytes4 private constant CAST_VOTE_BY_DELEGATE_SELECTOR =
        bytes4(keccak256("castVoteByDelegate(uint256,address,uint8)"));
    bytes4 private constant UPGRADE_SELECTOR = UUPSUpgradeable.upgradeToAndCall.selector;
    bytes4 private constant GET_QUEST_SELECTOR = MyGovernor.getQuest.selector;
    bytes4 private constant CAN_VOTE_SELECTOR = MyGovernor.canVote.selector;
    bytes4 private constant VOTES_SELECTOR = bytes4(keccak256("votes(uint256,address)"));
    bytes4 private constant GET_NONCE_SELECTOR = bytes4(keccak256("getNonce(address)"));
    bytes4 private constant INIT = MyGovernor.init.selector;
    bytes4 private constant CREATE_QUEST = MyGovernor.createQuest.selector;
    bytes4 private constant GET_NAME_SELECTOR = MyGovernor.getName.selector;
    bytes4 private constant GET_VERSION_SELECTOR = bytes4(keccak256("getVersion()"));
    bytes4 private constant GET_DOMAIN_SEPARATOR_SELECTOR = MyGovernor.getDomainSeparator.selector;

    // Test addresses
    address private constant VOTER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 private constant VOTER_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address private constant DELEGATE = address(0x1);

    function setUp() public {
        implementation = new MyGovernor();
        proxy = new ProxyVote(address(implementation), "");
        token = new ERC20Mock();

        // Create a helper to easily call functions on the proxy
        proxyAsGovernor = MyGovernor(address(proxy));

        _initImplementation("GovernanceV1", address(token));

        implementationV2 = new MyGovernorV2();
    }

    /* ========== HELPER FUNCTIONS ========== */

    function _initImplementation(string memory name, address tokenAddress) private {
        bytes memory data = abi.encodeWithSelector(INIT, name, tokenAddress);
        (bool success,) = address(proxy).call(data);
        assertTrue(success, "Initialization failed");
    }

    function _createQuest(string memory name, string memory description, uint256 reward, string[] memory options)
        private
    {
        bytes memory data = abi.encodeWithSelector(CREATE_QUEST, name, description, reward, options);
        (bool success,) = address(proxy).call(data);
        assertTrue(success, "Quest creation failed");
    }

    function _getQuest(uint256 questId) private returns (MyGovernor.Quest memory) {
        bytes memory data = abi.encodeWithSelector(GET_QUEST_SELECTOR, questId);
        (bool success, bytes memory result) = address(proxy).call(data);
        assertTrue(success, "Failed to get quest");
        return abi.decode(result, (MyGovernor.Quest));
    }

    function _getVotes(uint256 questId, address voter) private returns (MyGovernor.Vote) {
        bytes memory data = abi.encodeWithSelector(VOTES_SELECTOR, questId, voter);
        (bool success, bytes memory result) = address(proxy).call(data);
        assertTrue(success, "Failed to get votes");
        return abi.decode(result, (MyGovernor.Vote));
    }

    function _getNonce(address voter) private returns (uint256) {
        bytes memory data = abi.encodeWithSelector(GET_NONCE_SELECTOR, voter);
        (bool success, bytes memory result) = address(proxy).call(data);
        assertTrue(success, "Failed to get nonce");
        return abi.decode(result, (uint256));
    }

    function _createEIP712Signature(uint256 questId, address voter, MyGovernor.Vote voteOption, uint256 deadline)
        private
        view
        returns (bytes memory)
    {
        uint256 nonce = proxyAsGovernor.getNonce(voter);

        bytes32 domainSeparator = proxyAsGovernor.getDomainSeparator();
        bytes32 structHash = keccak256(abi.encode(questId, voter, uint8(voteOption), nonce, deadline));

        bytes32 digest = MessageHashUtils.toTypedDataHash(domainSeparator, structHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(VOTER_PRIVATE_KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    function _upgradeImplementation(address newImplementation) private {
        bytes memory data = abi.encodeWithSelector(UPGRADE_SELECTOR, newImplementation, "");
        (bool success,) = address(proxy).call(data);
        assertTrue(success, "Upgrade failed");
    }

    /* ========== PROXY PATTERN TESTS ========== */

    function test_proxyBasics() public view {
        assertEq(address(implementation), proxy.getImplementation());
    }

    function test_proxyFunctionality() public view {
        string memory name = proxyAsGovernor.getName();
        assertEq(name, "GovernanceV1", "Name not set correctly");
    }

    function test_upgradeTo_newImplementation() public {
        assertEq(address(implementation), proxy.getImplementation());

        _upgradeImplementation(address(implementationV2));

        assertEq(address(implementationV2), proxy.getImplementation());

        bytes memory data = abi.encodeWithSelector(GET_VERSION_SELECTOR);
        (bool success, bytes memory result) = address(proxy).call(data);
        assertTrue(success, "Version retrieval failed");

        uint256 version = abi.decode(result, (uint256));
        assertEq(version, 2, "Version should be 2");
    }

    /* ========== VOTING FUNCTIONALITY TESTS ========== */

    function test_directVoting() public {
        _createQuest("QuestA", "DescriptionA", 100, new string[](0));

        token.mint(address(this), 100);

        proxyAsGovernor.castVote(0, MyGovernor.Vote.Yes);

        MyGovernor.Vote vote = _getVotes(0, address(this));
        assertEq(uint8(vote), uint8(MyGovernor.Vote.Yes), "Vote not recorded correctly");
    }

    function test_signatureBasedVoting() public {
        _createQuest("QuestA", "DescriptionA", 100, new string[](0));

        token.mint(VOTER, 100);

        uint256 deadline = block.timestamp + 1 hours;

        bytes memory signature = _createEIP712Signature(0, VOTER, MyGovernor.Vote.Yes, deadline);

        proxyAsGovernor.castVoteBySig(0, VOTER, MyGovernor.Vote.Yes, deadline, signature);

        MyGovernor.Vote vote = _getVotes(0, VOTER);
        assertEq(uint8(vote), uint8(MyGovernor.Vote.Yes), "Vote not recorded correctly for signer");

        uint256 newNonce = _getNonce(VOTER);
        assertEq(newNonce, 1, "Nonce should be incremented");
    }

    function test_signatureExpired() public {
        _createQuest("QuestA", "DescriptionA", 100, new string[](0));

        token.mint(VOTER, 100);

        uint256 deadline = block.timestamp - 1;

        bytes memory signature = _createEIP712Signature(0, VOTER, MyGovernor.Vote.Yes, deadline);

        bytes memory voteData =
            abi.encodeWithSelector(CAST_VOTE_BY_SIG_SELECTOR, 0, VOTER, uint8(MyGovernor.Vote.Yes), deadline, signature);

        (bool success,) = address(proxy).call(voteData);
        assertFalse(success, "Voting with expired signature should fail");
    }

    function test_invalidSignature_reverts() public {
        _createQuest("QuestA", "DescriptionA", 100, new string[](0));

        token.mint(VOTER, 100);

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 domainSeparator = proxyAsGovernor.getDomainSeparator();

        uint256 wrongPrivateKey = uint256(2);
        bytes32 structHash = keccak256(abi.encode(domainSeparator, 0, VOTER, uint8(MyGovernor.Vote.Yes), 0, deadline));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, digest);
        bytes memory invalidSignature = abi.encodePacked(r, s, v);

        bytes memory voteData = abi.encodeWithSelector(
            CAST_VOTE_BY_SIG_SELECTOR, 0, VOTER, uint8(MyGovernor.Vote.Yes), deadline, invalidSignature
        );

        (bool success,) = address(proxy).call(voteData);
        assertFalse(success, "Vote with invalid signature should fail");
    }

    /* ========== DELEGATION TESTS ========== */

    function test_delegateVote() public {
        _createQuest("QuestA", "DescriptionA", 100, new string[](0));

        token.mint(address(this), 100);

        bytes memory delegateData = abi.encodeWithSelector(DELEGATE_VOTE_SELECTOR, 0, DELEGATE);

        (bool success,) = address(proxy).call(delegateData);
        assertTrue(success, "Delegation failed");

        address delegateAddress = proxyAsGovernor.getDelegateFor(address(this), 0);
        assertEq(delegateAddress, DELEGATE, "Delegation not recorded correctly");

        vm.prank(DELEGATE);
        bytes memory voteData =
            abi.encodeWithSelector(CAST_VOTE_BY_DELEGATE_SELECTOR, 0, address(this), uint8(MyGovernor.Vote.Yes));

        (bool voteSuccess,) = address(proxy).call(voteData);
        assertTrue(voteSuccess, "Delegate voting failed");

        MyGovernor.Vote vote = _getVotes(0, address(this));
        assertEq(uint8(vote), uint8(MyGovernor.Vote.Yes), "Vote not recorded correctly");
    }

    function test_delegateCannotVoteAfterRevocation() public {
        _createQuest("QuestA", "DescriptionA", 100, new string[](0));

        token.mint(address(this), 100);

        proxyAsGovernor.delegateVote(0, DELEGATE);

        proxyAsGovernor.revokeDelegation(0);

        vm.prank(DELEGATE);
        bool voteSuccess = false;
        try proxyAsGovernor.castVoteByDelegate(0, address(this), MyGovernor.Vote.Yes) {
            voteSuccess = true;
        } catch {
            voteSuccess = false;
        }

        assertFalse(voteSuccess, "Delegate should not be able to vote after revocation");
    }

    /* ========== VOTING POWER TESTS ========== */

    function test_votingPower() public {
        _createQuest("QuestA", "DescriptionA", 100, new string[](0));

        token.mint(address(1), 100);
        token.mint(address(2), 200);

        uint256 power1 = proxyAsGovernor.getVotingPower(0, address(1));
        uint256 power2 = proxyAsGovernor.getVotingPower(0, address(2));

        assertEq(power1, 100, "Voting power should match token balance");
        assertEq(power2, 200, "Voting power should match token balance");
        assertEq(power2 / power1, 2, "Address 2 should have twice the voting power");
    }
}
