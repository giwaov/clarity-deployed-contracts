;; title: bitlot-token
;; summary: A standard SIP-010 fungible token for BitLot
;; description: Used for lottery rewards

(impl-trait .sip-010-trait-ft-standard.sip-010-trait)

(define-fungible-token bitlot-token u1000000000000) ;; Max supply with 6 decimals

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (try! (ft-transfer? bitlot-token amount sender recipient))
        (match memo to-print (print to-print) 0x)
        (ok true)
    )
)

(define-read-only (get-name)
    (ok "BitLot Token")
)

(define-read-only (get-symbol)
    (ok "BLOT")
)

(define-read-only (get-decimals)
    (ok u6)
)

(define-read-only (get-balance (who principal))
    (ok (ft-get-balance bitlot-token who))
)

(define-read-only (get-total-supply)
    (ok (ft-get-supply bitlot-token))
)

(define-read-only (get-token-uri)
    (ok none)
)

(define-public (mint (amount uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ft-mint? bitlot-token amount recipient)
    )
)

;; Mint initial supply to deployer
(begin
    (try! (ft-mint? bitlot-token u1000000000000 contract-owner)) ;; 1 million tokens (6 decimals)
)
