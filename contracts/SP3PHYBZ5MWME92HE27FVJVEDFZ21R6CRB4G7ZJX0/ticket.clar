;; Contract: Ticket NFT
;; Description: Issues ticket if seats are available.

(define-non-fungible-token entry-pass uint)
(define-data-var ticket-id uint u0)

(define-public (buy-ticket)
    (let
        (
            (new-id (+ (var-get ticket-id) u1))
        )
        ;; 1. Try to register seat in Event Contract
        (try! (contract-call? .concert register-seat))
        
        ;; 2. Mint NFT
        (try! (nft-mint? entry-pass new-id tx-sender))
        (var-set ticket-id new-id)
        (ok "Ticket Issued")
    )
)