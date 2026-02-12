---
title: 'Audit "Stackspot"'
author: "Friedger"
GeekdocBreadcrumb: false
GeekdocNav: false
---

# Overview

## Introduction
I was asked to audit the smart contracts for "Stackspot" in Clarity programming language.

The purpose of the main smart contract (stackspot-jackpot) is to manage STX tokens that users deposited to earn stacking rewards as a group in so-called Pots. One lucky winner should receive all rewards (minus some fees). All player would receive their STX tokens back after the stacking period. A registry for pots increases trust and simplifies discovery, 

This audit was executed and written by Friedger (OpenIntents). The final report was published on December 20th, 2025.

## Code

A git repo was provided that contains the smart contract and tests for the smart contract. The source code is hosted at [https://github.com/Zeus-Adin/stackspot-contract](https://github.com/Zeus-Adin/stackspot-contract). For the review, the git commit [1c8a459](https://github.com/Zeus-Adin/stackspot-contract/commit/1c8a459eb07b579f071432cb5513c63cf942777e) was used.

## Scope and Approach

The audit focussed on the following topics:

* correctness
* misuse of funds
* error handling
* centralization
* runtime errors

For the audit, I used
* manual code inspection
* manual tests with clarity console
* reproducable tests

# Findings 

## Description

The contract code is structured in several contracts to separate concerns using Clarity 3. The code is commented. 

Tests cover most code of the core contracts. Mocking contracts for pox-4 and fastpool contract are not considered in the tests.

The stacking feature and reward distribution is fully functional.

The contracts have not been optimized for costs. Instead, several features have been implemented to increase usability and trust.

The contracts are not formatted using clarinet format.

Using Clarity 4 in-contract post-conditions, could increase the number of tokens used as rewards. Currently, it is limited to sBTC.

The VRF function has been not reviewed for its normal distribution. Instead a quick check on simnet has shown that overall the distribution looks equal for a sample of 1000 rounds with 100 members.

I have implemented some of the recommendations [https://github.com/Zeus-Adin/stackspot-contract/pull/9](https://github.com/Zeus-Adin/stackspot-contract/pull/9).

## Summary

### High Risk
None

### Medium Risk
* Trust: Fixed admin for Pot
* Trust: Fixed admin for audited contracts
* Usability: No pot details before start

### Low Risk
* Error Handling: Some errors do not have names 
* Performance: Unnecessary print events
* Performance: If claused for logic expressions
* Code Readability: Not formatted
* Usability: Parameter as result
* Usability: Extra transaction required
  
# Details

## Medium Risk

### Trust: Fixed contract owner

Functions `send-to-dispute-passed-time-acceptance` and `dao-vote-satisfaction` are guarded by the contract owner variable. This variable is initialized with the contract deployer. There is no public function to change this value.

Recommendations: Add setter function.

## Low Risk

### Error Handling/Performance: Inconsistent read of map gig

In function `accept-gig`, `decline-gig`, `redeem-back`, `send-to-dispute`, `send-to-dispute-passed-time-acceptance`, `satisfaction-vote-gig-as-client`, `satisfaction-vote-gig-as-artist`, the map of gigs is queried. The handling of the map entry is inconsistent. Sometimes the `map-get?` result is unwrapped immediately, using `unwrap-panic!`. Sometimes, the result is checked for some and thereafter unwrapped. 

Recommendation: Always assign variable `gig-info` with `(gig-info (unwrap-panic (map-get? gig gig-id)))`.

### Performance: Unnecessary unwrap of function call and wrap as result

In read-only functions `can-redeem`, the result is wrapped into an `ok` response, the function is used once and always unwraps the result.

Recommendations: Use function result directly as result.

### Performance: If claused for logic expressions

Function `check-is-expired`, `is-satifaction-valid` contain nested if clauses.

Recommendations: Use `and` and `or` directly.

### Code Readability: Satisfaction levels as numbers

The different levels of satisfaction are encoded as string. However, the constant names use numbers instead of the declared english words.

Recommendations: Use english words in constant names `vote-*`

### Code Readability: Inconsistent comments

The contracts contains comments at the top and at the bottom that describe functionality of the contract.

Recommendations: Place all comments regarding the general functionality at the top of the contract. Review the descriptions of the functions. Review the upper/lower case of comments.

### Usability: Parameter as result

The functions `accept-gig` and `decline-gig` return the function parameter as the result value.

Recommendations: Use `(ok true)` or return a helpful value like block-height as result.

### Usability: Extra transaction required

The function `send-to-dispute-passed-time-acceptance` has to be called before `dao-vote-satisfaction` when the time expired and the client and artist did not send the case to dispute.

Recommendations: Allow to call function `dao-vote-satisfaction` when the time has expired and the state is still in `accepted`.
