;; Multi-Signature Wallet
;; Requires multiple signatures to execute transactions

(define-constant err-not-owner (err u100))
(define-constant err-insufficient-confirmations (err u101))
(define-constant err-tx-not-found (err u102))
(define-constant err-already-confirmed (err u103))
(define-constant err-already-executed (err u104))

(define-data-var required-confirmations uint u2)
(define-data-var tx-nonce uint u0)

(define-map owners principal bool)
(define-map transactions
    uint
    {
        to: principal,
        amount: uint,
        confirmations: uint,
        executed: bool
    }
)
(define-map confirmations {tx-id: uint, owner: principal} bool)

;; Initialize owners
(map-set owners tx-sender true)

;; Add owner (requires execution through multisig)
(define-public (add-owner (new-owner principal))
    (begin
        (asserts! (default-to false (map-get? owners tx-sender)) err-not-owner)
        (ok (map-set owners new-owner true))
    )
)

;; Submit a transaction
(define-public (submit-transaction (to principal) (amount uint))
    (let
        (
            (tx-id (var-get tx-nonce))
        )
        (asserts! (default-to false (map-get? owners tx-sender)) err-not-owner)
        
        (map-set transactions tx-id {
            to: to,
            amount: amount,
            confirmations: u1,
            executed: false
        })
        
        (map-set confirmations {tx-id: tx-id, owner: tx-sender} true)
        (var-set tx-nonce (+ tx-id u1))
        (ok tx-id)
    )
)

;; Confirm a transaction
(define-public (confirm-transaction (tx-id uint))
    (let
        (
            (tx (unwrap! (map-get? transactions tx-id) err-tx-not-found))
            (confirmation-key {tx-id: tx-id, owner: tx-sender})
        )
        (asserts! (default-to false (map-get? owners tx-sender)) err-not-owner)
        (asserts! (is-none (map-get? confirmations confirmation-key)) err-already-confirmed)
        (asserts! (not (get executed tx)) err-already-executed)
        
        (map-set confirmations confirmation-key true)
        (map-set transactions tx-id (merge tx {
            confirmations: (+ (get confirmations tx) u1)
        }))
        
        ;; Try to execute if threshold met
        (try! (execute-if-confirmed tx-id))
        (ok true)
    )
)

;; Execute transaction if enough confirmations
(define-private (execute-if-confirmed (tx-id uint))
    (let
        (
            (tx (unwrap! (map-get? transactions tx-id) err-tx-not-found))
        )
        (if (and 
                (>= (get confirmations tx) (var-get required-confirmations))
                (not (get executed tx)))
            (begin
                (try! (as-contract (stx-transfer? (get amount tx) tx-sender (get to tx))))
                (map-set transactions tx-id (merge tx {executed: true}))
                (ok true)
            )
            (ok false)
        )
    )
)

;; Revoke confirmation
(define-public (revoke-confirmation (tx-id uint))
    (let
        (
            (tx (unwrap! (map-get? transactions tx-id) err-tx-not-found))
            (confirmation-key {tx-id: tx-id, owner: tx-sender})
        )
        (asserts! (default-to false (map-get? owners tx-sender)) err-not-owner)
        (asserts! (not (get executed tx)) err-already-executed)
        (asserts! (is-some (map-get? confirmations confirmation-key)) err-already-confirmed)
        
        (map-delete confirmations confirmation-key)
        (map-set transactions tx-id (merge tx {
            confirmations: (- (get confirmations tx) u1)
        }))
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-transaction (tx-id uint))
    (map-get? transactions tx-id)
)

(define-read-only (is-owner (account principal))
    (default-to false (map-get? owners account))
)

(define-read-only (has-confirmed (tx-id uint) (owner principal))
    (is-some (map-get? confirmations {tx-id: tx-id, owner: owner}))
)
