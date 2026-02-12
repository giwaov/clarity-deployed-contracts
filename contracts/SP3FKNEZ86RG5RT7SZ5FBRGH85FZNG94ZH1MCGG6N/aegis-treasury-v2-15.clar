;; Aegis Treasury v3 - Treasury Contract
;; Holds penalty fees and protocol revenue
;; Part of the Aegis Vault split architecture

(use-trait ft-trait .sip-010-trait.sip-010-trait)

;; ============================================
;; CONSTANTS
;; ============================================

(define-constant CONTRACT-OWNER tx-sender)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u8001))
(define-constant ERR-INSUFFICIENT-FUNDS (err u8002))
(define-constant ERR-INVALID-AMOUNT (err u8003))
(define-constant ERR-VAULT-ONLY (err u8004))

;; ============================================
;; DATA VARIABLES
;; ============================================

(define-data-var total-received uint u0)
(define-data-var total-distributed uint u0)

;; ============================================
;; DATA MAPS
;; ============================================

(define-map authorized-vaults principal bool)

;; ============================================
;; AUTHORIZATION
;; ============================================

(define-private (is-authorized-vault (caller principal))
  (default-to false (map-get? authorized-vaults caller))
)

;; ============================================
;; ADMIN FUNCTIONS
;; ============================================

(define-public (add-vault (vault principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set authorized-vaults vault true)
    (print { event: "vault-added", vault: vault })
    (ok true)
  )
)

(define-public (remove-vault (vault principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-delete authorized-vaults vault)
    (print { event: "vault-removed", vault: vault })
    (ok true)
  )
)

;; ============================================
;; PUBLIC FUNCTIONS
;; ============================================

;; Receive STX (can be called by anyone, tracked if from vault)
(define-public (receive-stx (amount uint))
  (begin
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (if (is-authorized-vault tx-sender)
      (var-set total-received (+ (var-get total-received) amount))
      true
    )
    (print { event: "stx-received", from: tx-sender, amount: amount, is-vault: (is-authorized-vault tx-sender) })
    (ok true)
  )
)

;; Distribute STX to recipient (owner only)
(define-public (distribute-stx (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= amount (stx-get-balance (as-contract tx-sender))) ERR-INSUFFICIENT-FUNDS)
    (try! (as-contract (stx-transfer? amount tx-sender recipient)))
    (var-set total-distributed (+ (var-get total-distributed) amount))
    (print { event: "stx-distributed", to: recipient, amount: amount })
    (ok true)
  )
)

;; Distribute tokens (owner only)
(define-public (distribute-tokens (token-contract <ft-trait>) (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (as-contract (contract-call? token-contract transfer amount tx-sender recipient none))
  )
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

(define-read-only (get-balance)
  (stx-get-balance (as-contract tx-sender))
)

(define-read-only (get-stats)
  {
    balance: (stx-get-balance (as-contract tx-sender)),
    total-received: (var-get total-received),
    total-distributed: (var-get total-distributed)
  }
)

(define-read-only (is-vault (address principal))
  (is-authorized-vault address)
)
