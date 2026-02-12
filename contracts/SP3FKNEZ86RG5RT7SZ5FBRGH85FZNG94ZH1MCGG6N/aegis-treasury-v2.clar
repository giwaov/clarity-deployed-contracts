;; Aegis Treasury
;; Manages penalty fees from emergency withdrawals
;; Holds 2% penalties and allows admin fund management

;; ============================================
;; CONSTANTS
;; ============================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u2001))
(define-constant ERR-INSUFFICIENT-FUNDS (err u2002))
(define-constant ERR-INVALID-AMOUNT (err u2003))
(define-constant ERR-VAULT-ONLY (err u2004))

;; ============================================
;; DATA VARIABLES
;; ============================================

(define-data-var total-penalties-collected uint u0)
(define-data-var total-withdrawn uint u0)

;; ============================================
;; DATA MAPS
;; ============================================

;; Authorized vaults that can deposit penalties
(define-map authorized-vaults principal bool)

;; ============================================
;; PRIVATE FUNCTIONS
;; ============================================

(define-private (is-authorized-vault (vault principal))
  (default-to false (map-get? authorized-vaults vault))
)

;; ============================================
;; PUBLIC FUNCTIONS
;; ============================================

;; Receive penalty deposit from staking vault
(define-public (deposit-penalty (amount uint))
  (begin
    ;; Only authorized vaults can deposit
    (asserts! (is-authorized-vault contract-caller) ERR-VAULT-ONLY)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    ;; Transfer STX to treasury
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update total collected
    (var-set total-penalties-collected (+ (var-get total-penalties-collected) amount))
    
    (print { 
      event: "penalty-deposited", 
      amount: amount, 
      from-vault: contract-caller,
      total-collected: (var-get total-penalties-collected)
    })
    (ok true)
  )
)

;; Admin withdraw funds from treasury
(define-public (withdraw-funds (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= amount (get-treasury-balance)) ERR-INSUFFICIENT-FUNDS)
    
    ;; Transfer STX from treasury
    (try! (as-contract (stx-transfer? amount tx-sender recipient)))
    
    ;; Update total withdrawn
    (var-set total-withdrawn (+ (var-get total-withdrawn) amount))
    
    (print { 
      event: "treasury-withdrawal", 
      amount: amount, 
      recipient: recipient,
      remaining-balance: (get-treasury-balance)
    })
    (ok true)
  )
)

;; ============================================
;; ADMIN FUNCTIONS
;; ============================================

;; Add authorized vault
(define-public (add-vault (vault principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set authorized-vaults vault true)
    (print { event: "vault-added", vault: vault })
    (ok true)
  )
)

;; Remove authorized vault
(define-public (remove-vault (vault principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-delete authorized-vaults vault)
    (print { event: "vault-removed", vault: vault })
    (ok true)
  )
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

(define-read-only (get-treasury-balance)
  (stx-get-balance (as-contract tx-sender))
)

(define-read-only (get-total-penalties-collected)
  (var-get total-penalties-collected)
)

(define-read-only (get-total-withdrawn)
  (var-get total-withdrawn)
)

(define-read-only (get-contract-owner)
  CONTRACT-OWNER
)

(define-read-only (is-vault-authorized (vault principal))
  (is-authorized-vault vault)
)

;; Get treasury stats
(define-read-only (get-treasury-stats)
  {
    balance: (get-treasury-balance),
    total-collected: (var-get total-penalties-collected),
    total-withdrawn: (var-get total-withdrawn)
  }
)
