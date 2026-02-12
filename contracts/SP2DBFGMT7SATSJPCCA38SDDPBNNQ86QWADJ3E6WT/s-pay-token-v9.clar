;; title: s-pay-token
;; version: 1.0.0
;; summary: SIP-010 compliant token for the S-pay protocol.
;; description: A standard fungible token with owner-controlled minting.

(impl-trait .sip-010-trait.sip-010-trait)

(define-fungible-token s-pay-token)

(define-constant contract-owner tx-sender)

;; Error constants
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))

;; SIP-010 Standard Functions
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (try! (ft-transfer? s-pay-token amount sender recipient))
        (match memo to-print (print to-print) 0x)
        (ok true)
    )
)

(define-read-only (get-name)
    (ok "S-pay Token")
)

(define-read-only (get-symbol)
    (ok "SPAY")
)

(define-read-only (get-decimals)
    (ok u6)
)

(define-read-only (get-balance (user principal))
    (ok (ft-get-balance s-pay-token user))
)

(define-read-only (get-total-supply)
    (ok (ft-get-supply s-pay-token))
)

(define-read-only (get-token-uri)
    (ok none)
)

;; Minting Function
(define-public (mint (amount uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ft-mint? s-pay-token amount recipient)
    )
)
