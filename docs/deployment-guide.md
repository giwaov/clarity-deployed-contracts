# Clarity Contract Deployment Guide

## Overview

This guide covers best practices for deploying Clarity smart contracts on the Stacks blockchain, with lessons learned from reviewing deployed contracts in this repository.

## Pre-Deployment Checklist

### 1. Code Review
- [ ] All public functions have proper access controls
- [ ] Error codes are well-defined and documented
- [ ] No hardcoded values that should be configurable
- [ ] All map keys and value types are correct
- [ ] Post-conditions are properly set for token transfers

### 2. Testing
```bash
# Run all tests
clarinet test

# Run specific test file
clarinet test tests/my-contract_test.ts

# Generate test coverage
clarinet test --coverage

# Check contract analysis
clarinet check
```

### 3. Security Audit
- Review for common Clarity vulnerabilities
- Check trait implementations match expected interfaces
- Verify principal-based access control
- Test edge cases with boundary values

## Deployment Process

### Testnet Deployment

```bash
# Configure Clarinet for testnet
clarinet deployments generate --testnet

# Deploy to testnet
clarinet deployments apply -p deployments/default.testnet-plan.yaml
```

### Mainnet Deployment

```javascript
import { makeContractDeploy, broadcastTransaction } from '@stacks/transactions';
import { StacksMainnet } from '@stacks/network';

const txOptions = {
  contractName: 'my-contract',
  codeBody: contractCode,
  senderKey: privateKey,
  network: new StacksMainnet(),
  fee: 100000, // Set appropriate fee
  nonce: nextNonce,
};

const transaction = await makeContractDeploy(txOptions);
const result = await broadcastTransaction(transaction, network);
```

## Common Patterns in Deployed Contracts

### Token Contracts (SIP-010)
Most deployed fungible tokens follow the SIP-010 trait:
```clarity
(impl-trait .sip-010-trait.sip-010-trait)

(define-fungible-token my-token)

(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender from) (err u401))
    (ft-transfer? my-token amount from to)
  )
)
```

### NFT Contracts (SIP-009)
```clarity
(impl-trait .sip-009-trait.sip-009-trait)

(define-non-fungible-token my-nft uint)

(define-public (transfer (id uint) (from principal) (to principal))
  (begin
    (asserts! (is-eq tx-sender from) (err u401))
    (nft-transfer? my-nft id from to)
  )
)
```

## Post-Deployment Verification

1. Verify contract on Stacks Explorer
2. Test all public functions via Explorer or CLI
3. Monitor initial transactions for unexpected behavior
4. Document contract address and deployment transaction
