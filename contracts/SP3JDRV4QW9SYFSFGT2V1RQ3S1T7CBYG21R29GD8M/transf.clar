;; Simple STX Transfer Contract
;; Allows registered wallets to transfer STX to other wallets

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-registered (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-transfer-failed (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-self-transfer (err u105))

;; Data maps
(define-map registered-wallets principal bool)

;; Initialize contract owner as registered
(map-set registered-wallets contract-owner true)

;; Read-only functions

;; Check if a wallet is registered
(define-read-only (is-registered (wallet principal))
    (ok (default-to false (map-get? registered-wallets wallet)))
)

;; Get STX balance of a wallet
(define-read-only (get-balance (wallet principal))
    (ok (stx-get-balance wallet))
)

;; Public functions

;; Register a new wallet (only owner can register wallets)
(define-public (register-wallet (wallet principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set registered-wallets wallet true))
    )
)

;; Unregister a wallet (only owner)
(define-public (unregister-wallet (wallet principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-delete registered-wallets wallet))
    )
)

;; Transfer STX from sender to recipient
;; Only registered wallets can initiate transfers
(define-public (transfer-stx (amount uint) (recipient principal))
    (begin
        ;; Validation checks
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (not (is-eq tx-sender recipient)) err-self-transfer)
        (asserts! (default-to false (map-get? registered-wallets tx-sender)) err-not-registered)
        (asserts! (>= (stx-get-balance tx-sender) amount) err-insufficient-balance)
        
        ;; Execute transfer
        (match (stx-transfer? amount tx-sender recipient)
            success (ok amount)
            error err-transfer-failed
        )
    )
)