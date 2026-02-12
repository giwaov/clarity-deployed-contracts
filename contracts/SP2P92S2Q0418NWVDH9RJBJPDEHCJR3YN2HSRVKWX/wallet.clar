;; Dummy Wallet Contract
;; This is a simple trusted wallet contract for testing purposes

(define-constant CONTRACT-OWNER tx-sender)

;; Simple storage for the wallet owner
(define-data-var wallet-owner principal tx-sender)

;; Read-only function to get the wallet owner
(define-read-only (get-owner)
    (var-get wallet-owner)
)

;; Function to check if caller is the owner
(define-read-only (is-owner (caller principal))
    (is-eq caller (var-get wallet-owner))
)

;; Allow the wallet to receive STX (needed for time vault beneficiary)
(define-public (receive-stx)
    (ok true)
)
