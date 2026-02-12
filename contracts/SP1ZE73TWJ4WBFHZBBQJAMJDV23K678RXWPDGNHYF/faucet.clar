;; title: faucet
;; version: 1.0
;; summary: A simple fungible token faucet with time-based rate limiting.

;; token definitions
(define-fungible-token my-token)

;; constants
(define-constant CLAIM-AMOUNT u10)
(define-constant WAIT-TIME u144) ;; ~24 hours (10 min blocks)

;; errors
(define-constant ERR-TOO-SOON (err u100))

;; data maps
(define-map last-claim principal uint)

;; public functions

;; Claim tokens
(define-public (claim)
    (let
        (
            (caller tx-sender)
            (current-block stacks-block-height)
            (last-claimed-block (default-to u0 (map-get? last-claim caller)))
        )
        ;; Check if enough time has passed
        (asserts! (or (is-eq last-claimed-block u0) (> (- current-block last-claimed-block) WAIT-TIME)) ERR-TOO-SOON)

        ;; Update last claim time
        (map-set last-claim caller current-block)

        ;; Mint tokens to caller
        (ft-mint? my-token CLAIM-AMOUNT caller)
    )
)

;; read only functions

(define-read-only (get-balance (user principal))
    (ft-get-balance my-token user)
)

(define-read-only (get-last-claim (user principal))
    (map-get? last-claim user)
)
