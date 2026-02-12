;; ========================================
;; VAULTAYIELD - FEE COLLECTOR
;; ========================================

;; ========================================
;; CONSTANTS
;; ========================================

(define-constant CONTRACT-OWNER tx-sender)

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ZERO-AMOUNT (err u101))

;; ========================================
;; DATA VARIABLES
;; ========================================

(define-data-var accumulated-fees uint u0)
(define-data-var vault-core-contract (optional principal) none)
(define-data-var total-fees-collected uint u0)

;; ========================================
;; PUBLIC FUNCTIONS
;; ========================================

(define-public (collect-fee (amount uint))
  ;; Only vault-core can call this
  (begin
    (asserts! (is-authorized-vault) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    
    ;; Update counters
    (var-set accumulated-fees (+ (var-get accumulated-fees) amount))
    (var-set total-fees-collected (+ (var-get total-fees-collected) amount))
    
    ;; Emit event
    (print {
      event: "fee-collected",
      amount: amount,
      accumulated: (var-get accumulated-fees),
      timestamp: block-height
    })
    
    (ok true)
  )
)

(define-public (withdraw-fees (recipient principal))
  ;; Only owner can withdraw fees
  (let
    (
      (fees (var-get accumulated-fees))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> fees u0) ERR-ZERO-AMOUNT)
    
    ;; Reset accumulated fees
    (var-set accumulated-fees u0)
    
    ;; Transfer fees to recipient
    (try! (as-contract (stx-transfer? fees tx-sender recipient)))
    
    ;; Emit event
    (print {
      event: "fees-withdrawn",
      amount: fees,
      recipient: recipient,
      timestamp: block-height
    })
    
    (ok fees)
  )
)

;; ========================================
;; ADMIN FUNCTIONS
;; ========================================

(define-public (set-vault-core (vault-contract principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set vault-core-contract (some vault-contract))
    (ok true)
  )
)

;; ========================================
;; READ-ONLY FUNCTIONS
;; ========================================

(define-read-only (get-accumulated-fees)
  (var-get accumulated-fees)
)

(define-read-only (get-total-fees-collected)
  (var-get total-fees-collected)
)

;; ========================================
;; PRIVATE FUNCTIONS
;; ========================================

(define-private (is-authorized-vault)
  (match (var-get vault-core-contract)
    vault-contract (is-eq contract-caller vault-contract)
    false
  )
)
