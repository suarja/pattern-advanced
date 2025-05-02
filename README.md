# Governance Signature Patterns Demo

A demonstration of advanced Solidity patterns: UUPS Upgradeability and EIP-712 Signature Verification for meta-transactions in a governance system.

## Overview

This project showcases how to implement:

- **UUPS Proxy Pattern**: Upgradeable smart contracts with minimal gas overhead
- **EIP-712 Signatures**: Structured, human-readable message signing
- **Meta-transactions**: Gasless voting and delegation
- **Governance Mechanisms**: Weighted voting, vote delegation, and quest management

## Features

- 🔄 **Upgradeable Architecture**: Safely upgrade contract logic without losing state
- ✍️ **EIP-712 Signatures**: Type-safe, domain-separated signatures
- ⛽ **Gasless Transactions**: Users can vote without holding ETH
- 🗳️ **Vote Delegation**: Delegate voting power to trusted addresses
- ⚖️ **Weighted Voting**: Token-based voting power
- 🔒 **Replay Protection**: Nonces and deadlines prevent signature reuse

## Architecture

```
ProxyVote (ERC1967Proxy)
    ↓ delegates to
MyGovernor (Implementation)
    ├── Quest Management
    ├── Voting Logic
    ├── Signature Verification
    └── Delegation System
```

## Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js >= 16

### Installation

```bash
# Clone the repository
git clone https://github.com/suarja/pattern-advanced
cd governance-patterns

# Install dependencies
forge install

# Run tests
forge test
```

### Deploy

```bash
# Deploy to local network
forge script script/Deploy.s.sol --rpc-url localhost --broadcast

# Deploy to testnet
forge script script/Deploy.s.sol --rpc-url sepolia --broadcast --verify
```

## Core Contracts

### `ProxyVote.sol`

ERC1967 proxy contract that delegates all calls to the implementation.

### `MyGovernor.sol`

Main governance logic including:

- Quest creation and management
- Direct voting (`castVote`)
- Signature-based voting (`castVoteBySig`)
- Vote delegation system
- EIP-712 domain separation

### `MyGovernorV2.sol`

Upgraded implementation demonstrating:

- New challenge system
- Enhanced voting eligibility
- Backward compatibility

## Usage Examples

### Creating a Quest

```solidity
string[] memory options = new string[](2);
options[0] = "Yes";
options[1] = "No";

governor.createQuest(
    "Should we add a new feature?",
    "Description of the feature...",
    100, // reward
    options
);
```

### Voting Directly

```solidity
governor.castVote(questId, MyGovernor.Vote.Yes);
```

### Voting with Signature (Meta-transaction)

```javascript
// Frontend (using ethers.js)
const domain = {
  name: "GovernanceV1",
  version: "1",
  chainId: await provider.getNetwork().chainId,
  verifyingContract: governorAddress,
};

const types = {
  Vote: [
    { name: "questId", type: "uint256" },
    { name: "voter", type: "address" },
    { name: "voteOption", type: "uint8" },
    { name: "nonce", type: "uint256" },
    { name: "deadline", type: "uint256" },
  ],
};

const value = {
  questId: 0,
  voter: voterAddress,
  voteOption: 1, // Yes
  nonce: await governor.getNonce(voterAddress),
  deadline: Math.floor(Date.now() / 1000) + 3600, // 1 hour
};

const signature = await signer._signTypedData(domain, types, value);

// Anyone can submit this transaction
await governor.castVoteBySig(
  value.questId,
  value.voter,
  value.voteOption,
  value.deadline,
  signature
);
```

### Delegating Votes

```solidity
// Delegate voting power for a specific quest
governor.delegateVote(questId, delegateAddress);

// Delegate can now vote on behalf of the delegator
governor.castVoteByDelegate(questId, delegatorAddress, MyGovernor.Vote.Yes);

// Revoke delegation
governor.revokeDelegation(questId);
```

## Testing

The test suite covers:

- Proxy functionality and upgrades
- Direct voting
- Signature-based voting with EIP-712
- Vote delegation
- Edge cases and security checks

Run tests with coverage:

```bash
forge coverage
```

Run specific test:

```bash
forge test --match-test test_signatureBasedVoting -vvv
```

## Security Considerations

- ✅ Nonce system prevents replay attacks
- ✅ Deadline parameter limits signature validity
- ✅ Domain separator prevents cross-contract signature reuse
- ✅ Access controls on upgrade functionality
- ✅ Comprehensive test coverage

## Gas Optimization

- Proxy pattern adds minimal overhead (~2,000 gas)
- Signature verification costs ~3,000-5,000 gas
- Batch operations possible through meta-transactions

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- OpenZeppelin for upgradeable contracts and cryptography utilities
- Foundry for the development framework
- EIP-712 and EIP-1967 authors for the standards

## Resources

- [EIP-712: Typed structured data hashing and signing](https://eips.ethereum.org/EIPS/eip-712)
- [EIP-1967: Proxy Storage Slots](https://eips.ethereum.org/EIPS/eip-1967)
- [OpenZeppelin Upgrades](https://docs.openzeppelin.com/upgrades-plugins/1.x/)
- [Meta-transactions Guide](https://docs.openzeppelin.com/learn/sending-gasless-transactions)

## Author

Jason Suárez

- GitHub: [@suarja](https://github.com/suarja)
- Article: [Signing the Future: EIP-712 and Meta-Transactions in Web3](https://dev.to/allkhwarizmi/how-signatures-can-set-you-free-2pl4-temp-slug-2865510?preview=07778107c6d6612237a98baf4f0f6f9b3759ae45f0f7f1e11ad432c3b915659a2d91c002cf2bc2eb392e98ee3588120a7336cce81b0ce2fa7e248edf)
