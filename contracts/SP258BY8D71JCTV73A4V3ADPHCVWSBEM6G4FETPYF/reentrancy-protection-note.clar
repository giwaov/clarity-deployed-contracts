;; Reentrancy Attacker Mock
;; 
;; NOTE: This contract is included for documentation purposes only.
;; Clarity has BUILT-IN REENTRANCY PROTECTION at the language level.
;; 
;; Unlike Solidity/EVM where reentrancy attacks are possible through 
;; external calls that can re-enter the same contract, Clarity prevents
;; this by design:
;; 
;; 1. All contract calls are atomic
;; 2. State changes are isolated within a transaction
;; 3. No external calls can modify state mid-execution
;; 4. The call stack is managed by the Clarity VM
;; 
;; This means:
;; - You CANNOT re-enter a function during its execution
;; - You CANNOT exploit the "checks-effects-interactions" pattern
;; - Reentrancy guards (like OpenZeppelin's ReentrancyGuard) are NOT needed
;; 
;; Example of what's NOT possible in Clarity:
;; 
;; In Solidity, an attacker could:
;; 1. Call claimReward()
;; 2. Receive ETH via fallback/receive function
;; 3. Re-call claimReward() before state is updated
;; 4. Drain the contract
;; 
;; In Clarity, step 3 is IMPOSSIBLE because:
;; - The transaction context doesn't allow re-entry
;; - State changes are committed atomically
;; - External contract calls cannot interrupt execution flow
;; 
;; CONCLUSION:
;; This file exists only to document that reentrancy protection
;; is a non-issue in Clarity smart contracts. No mock attacker
;; contract is needed or possible.
;; 
;; For more information:
;; - https://docs.stacks.co/docs/clarity/security
;; - https://book.clarity-lang.org/ch08-00-security.html

;; No actual contract code needed - Clarity's design prevents reentrancy attacks
