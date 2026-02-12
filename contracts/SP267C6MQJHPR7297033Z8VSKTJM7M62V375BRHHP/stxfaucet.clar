;; STX Faucet Smart Contract - Clarity 3/4 compatible
;; Dispenses 0.05 STX once every 144 Bitcoin blocks (24 hours)

;; =============================================================================
;; CONSTANTS
;; =============================================================================

;; Hardcoded Contract Owner
(define-constant CONTRACT_OWNER 'SP267C6MQJHPR7297033Z8VSKTJM7M62V375BRHHP)

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_CLAIMED (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_FAUCET_INACTIVE (err u104))
(define-constant ERR_INVALID_RECIPIENT (err u105))

;; Rate limiting (144 Bitcoin blocks = 24 hours)
(define-constant BLOCKS_PER_DAY u144)

;; Default drip amounts (0.05 STX = 50,000 microSTX)
(define-constant DEFAULT_DRIP u50000)

;; =============================================================================
;; DATA STORAGE
;; =============================================================================

(define-map last-claims principal uint)
(define-data-var drip-amount uint DEFAULT_DRIP)
(define-data-var is-active bool true)

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-last-claim (user principal))
  (map-get? last-claims user)
)

(define-read-only (is-eligible (user principal))
  (let (
    (last-claim-height (default-to u0 (map-get? last-claims user)))
  )
    (if (is-eq last-claim-height u0)
      true
      (>= burn-block-height (+ last-claim-height BLOCKS_PER_DAY))
    )
  )
)

(define-read-only (get-faucet-balance)
  (stx-get-balance (as-contract tx-sender))
)

(define-read-only (get-blocks-remaining (user principal))
  (let (
    (last-claim-height (default-to u0 (map-get? last-claims user)))
  )
    (if (or (is-eq last-claim-height u0) (>= burn-block-height (+ last-claim-height BLOCKS_PER_DAY)))
      u0
      (- BLOCKS_PER_DAY (- burn-block-height last-claim-height))
    )
  )
)

;; =============================================================================
;; PUBLIC FUNCTIONS
;; =============================================================================

(define-public (claim-stx)
  (let (
    (claimer tx-sender)
    (amount (var-get drip-amount))
  )
    (asserts! (var-get is-active) ERR_FAUCET_INACTIVE)
    (asserts! (is-eligible claimer) ERR_ALREADY_CLAIMED)
    (asserts! (>= (stx-get-balance (as-contract tx-sender)) amount) ERR_INSUFFICIENT_BALANCE)
    
    (map-set last-claims claimer burn-block-height)

    ;; Transfer from contract to user
    (try! (as-contract (stx-transfer? amount tx-sender claimer)))
    
    (ok amount)
  )
)

;; =============================================================================
;; ADMIN FUNCTIONS
;; =============================================================================

(define-public (set-drip-amount (new-amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> new-amount u0) ERR_INVALID_AMOUNT)
    (var-set drip-amount new-amount)
    (ok new-amount)
  )
)

(define-public (toggle-active)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set is-active (not (var-get is-active)))
    (ok (var-get is-active))
  )
)

(define-public (fund-faucet (amount uint))
  (stx-transfer? amount tx-sender (as-contract tx-sender))
)

(define-public (withdraw (amount uint) (recipient principal))
  (begin
    ;; 1. Authority Check
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    ;; 2. Basic Recipient Check (Silences the "unchecked data" warning)
    (asserts! (not (is-eq recipient (as-contract tx-sender))) ERR_INVALID_RECIPIENT)
    
    ;; 3. Balance Check
    (asserts! (>= (stx-get-balance (as-contract tx-sender)) amount) ERR_INSUFFICIENT_BALANCE)
    
    ;; 4. Execution
    (try! (as-contract (stx-transfer? amount tx-sender recipient)))
    
    (ok amount)
  )
)