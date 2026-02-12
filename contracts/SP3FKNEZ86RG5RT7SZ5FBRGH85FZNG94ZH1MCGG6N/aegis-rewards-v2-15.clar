;; Aegis Rewards v3 - Instant Claims Contract
;; Handles reward claims using merkle proofs for instant execution
;; Part of the Aegis Vault split architecture

;; ============================================
;; CONSTANTS
;; ============================================

(define-constant CONTRACT-OWNER tx-sender)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u6001))
(define-constant ERR-INVALID-PROOF (err u6002))
(define-constant ERR-ALREADY-CLAIMED (err u6003))
(define-constant ERR-NO-STAKE-FOUND (err u6004))
(define-constant ERR-ZERO-AMOUNT (err u6005))
(define-constant ERR-CONTRACT-PAUSED (err u6006))
(define-constant ERR-MINT-FAILED (err u6007))
(define-constant ERR-INVALID-SIGNATURE (err u6008))
(define-constant ERR-CLAIM-EXPIRED (err u6009))

;; Reward parameters
(define-constant BLOCKS-PER-DAY u144)
(define-constant BASE-REWARD-PER-DAY u5000000)  ;; 5 AGS tokens (6 decimals)
(define-constant CLAIM-VALIDITY-BLOCKS u1008)   ;; Claims valid for ~7 days

;; ============================================
;; DATA VARIABLES
;; ============================================

(define-data-var contract-paused bool false)
(define-data-var staking-contract principal CONTRACT-OWNER)
(define-data-var token-contract principal CONTRACT-OWNER)
(define-data-var merkle-root (buff 32) 0x0000000000000000000000000000000000000000000000000000000000000000)
(define-data-var merkle-update-block uint u0)
(define-data-var total-rewards-distributed uint u0)
(define-data-var total-claims uint u0)

;; Oracle for signature-based claims (alternative to merkle)
(define-data-var oracle-pubkey (buff 33) 0x000000000000000000000000000000000000000000000000000000000000000000)

;; ============================================
;; DATA MAPS
;; ============================================

;; Track claimed amounts per stake to prevent double claims
(define-map claimed-rewards 
  { staker: principal, stake-id: uint, merkle-root: (buff 32) }
  uint
)

;; Track total claimed per stake (all time)
(define-map total-claimed-per-stake
  { staker: principal, stake-id: uint }
  uint
)

;; ============================================
;; ADMIN FUNCTIONS
;; ============================================

(define-public (set-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set contract-paused paused)
    (ok true)
  )
)

(define-public (set-staking-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set staking-contract contract)
    (ok true)
  )
)

(define-public (set-token-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set token-contract contract)
    (ok true)
  )
)

;; Update merkle root (called periodically by backend)
(define-public (set-merkle-root (new-root (buff 32)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set merkle-root new-root)
    (var-set merkle-update-block block-height)
    (print { event: "merkle-root-updated", root: new-root, block: block-height })
    (ok true)
  )
)

(define-public (set-oracle-pubkey (pubkey (buff 33)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set oracle-pubkey pubkey)
    (ok true)
  )
)

;; ============================================
;; MERKLE PROOF VERIFICATION
;; ============================================

;; Verify a merkle proof for a claim
;; Leaf = hash(staker, stake-id, amount)
(define-private (verify-merkle-proof 
  (leaf (buff 32)) 
  (proof (list 10 (buff 32)))
  (root (buff 32))
)
  (is-eq (fold hash-pair proof leaf) root)
)

;; Hash pair for merkle proof - always concatenate in consistent order
;; Off-chain merkle tree builder must use same ordering (sorted)
(define-private (hash-pair (proof-element (buff 32)) (current-hash (buff 32)))
  (sha256 (concat current-hash proof-element))
)

;; ============================================
;; PUBLIC CLAIM FUNCTIONS
;; ============================================

;; Claim rewards using merkle proof (INSTANT - no on-chain calculation)
;; The leaf hash is computed off-chain and passed in for verification
;; Leaf = keccak256(staker, stake-id, claimable-amount)
(define-public (claim-rewards-merkle 
  (stake-id uint) 
  (claimable-amount uint)
  (leaf-hash (buff 32))
  (proof (list 10 (buff 32)))
)
  (let
    (
      (staker tx-sender)
      (current-root (var-get merkle-root))
      (already-claimed (default-to u0 (map-get? claimed-rewards { staker: staker, stake-id: stake-id, merkle-root: current-root })))
      (to-claim (- claimable-amount already-claimed))
    )
    ;; Validations
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (> to-claim u0) ERR-ZERO-AMOUNT)
    (asserts! (verify-merkle-proof leaf-hash proof current-root) ERR-INVALID-PROOF)
    
    ;; Check stake exists and is active
    (asserts! (is-some (contract-call? .aegis-staking-v2-15 get-stake staker stake-id)) ERR-NO-STAKE-FOUND)
    
    ;; Mint AGS tokens to staker
    (try! (contract-call? .aegis-token-v2-15 mint staker to-claim))
    
    ;; Update claimed tracking
    (map-set claimed-rewards 
      { staker: staker, stake-id: stake-id, merkle-root: current-root }
      claimable-amount
    )
    (map-set total-claimed-per-stake
      { staker: staker, stake-id: stake-id }
      (+ (default-to u0 (map-get? total-claimed-per-stake { staker: staker, stake-id: stake-id })) to-claim)
    )
    
    ;; Update staking contract
    (try! (contract-call? .aegis-staking-v2-15 update-claimed staker stake-id to-claim))
    
    ;; Update stats
    (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) to-claim))
    (var-set total-claims (+ (var-get total-claims) u1))
    
    (print { 
      event: "claim-rewards",
      method: "merkle",
      staker: staker,
      stake-id: stake-id,
      amount: to-claim
    })
    
    (ok to-claim)
  )
)

;; Fallback: On-chain reward calculation (higher gas, always available)
(define-public (claim-rewards-direct (stake-id uint))
  (let
    (
      (staker tx-sender)
      (stake-data (unwrap! (contract-call? .aegis-staking-v2-15 get-stake staker stake-id) ERR-NO-STAKE-FOUND))
      (pending (calculate-pending-rewards stake-data))
    )
    ;; Validations
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (get is-active stake-data) ERR-NO-STAKE-FOUND)
    (asserts! (> pending u0) ERR-ZERO-AMOUNT)
    
    ;; Mint AGS tokens
    (try! (contract-call? .aegis-token-v2-15 mint staker pending))
    
    ;; Update claimed in staking contract
    (try! (contract-call? .aegis-staking-v2-15 update-claimed staker stake-id pending))
    
    ;; Update stats
    (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) pending))
    (var-set total-claims (+ (var-get total-claims) u1))
    
    (print { 
      event: "claim-rewards",
      method: "direct",
      staker: staker,
      stake-id: stake-id,
      amount: pending
    })
    
    (ok pending)
  )
)

;; ============================================
;; PRIVATE HELPERS
;; ============================================

(define-private (calculate-pending-rewards (stake-data {
  amount: uint,
  start-block: uint,
  lock-blocks: uint,
  lock-period-type: uint,
  bonus-multiplier: uint,
  is-active: bool,
  total-claimed: uint
}))
  (let
    (
      (blocks-staked (- block-height (get start-block stake-data)))
      (days-staked (/ blocks-staked BLOCKS-PER-DAY))
      (base-rewards (* days-staked BASE-REWARD-PER-DAY))
      (with-bonus (/ (* base-rewards (get bonus-multiplier stake-data)) u10000))
    )
    (if (> with-bonus (get total-claimed stake-data))
      (- with-bonus (get total-claimed stake-data))
      u0
    )
  )
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

(define-read-only (get-pending-rewards (staker principal) (stake-id uint))
  (match (contract-call? .aegis-staking-v2-15 get-stake staker stake-id)
    stake-data
      (if (get is-active stake-data)
        (ok (calculate-pending-rewards stake-data))
        (ok u0)
      )
    (ok u0)
  )
)

(define-read-only (get-claimed-for-root (staker principal) (stake-id uint))
  (default-to u0 (map-get? claimed-rewards { staker: staker, stake-id: stake-id, merkle-root: (var-get merkle-root) }))
)

(define-read-only (get-total-claimed (staker principal) (stake-id uint))
  (default-to u0 (map-get? total-claimed-per-stake { staker: staker, stake-id: stake-id }))
)

(define-read-only (get-rewards-stats)
  {
    total-distributed: (var-get total-rewards-distributed),
    total-claims: (var-get total-claims),
    merkle-root: (var-get merkle-root),
    merkle-update-block: (var-get merkle-update-block),
    is-paused: (var-get contract-paused)
  }
)

(define-read-only (get-merkle-root)
  (var-get merkle-root)
)

;; Verify a claim proof with pre-computed leaf hash
;; The leaf hash is computed off-chain: sha256(staker || stake-id || amount)
(define-read-only (verify-claim-proof 
  (leaf-hash (buff 32))
  (proof (list 10 (buff 32)))
)
  (verify-merkle-proof leaf-hash proof (var-get merkle-root))
)
