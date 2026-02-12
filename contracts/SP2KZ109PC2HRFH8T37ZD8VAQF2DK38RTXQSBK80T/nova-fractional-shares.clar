
;; nova-fractional-shares.clar
;; Wraps an NFT and issues fungible tokens representing shares.
;; CLARITY VERSION: 2

(use-trait nova-trait-non-fungible .nova-trait-non-fungible.nova-trait-non-fungible)
(impl-trait .nova-trait-fungible.nova-trait-fungible)

(define-fungible-token share-token)

(define-data-var locked-nft (optional {contract: principal, id: uint}) none)
(define-constant ERR-ALREADY-LOCKED (err u100))
(define-constant ERR-NOT-LOCKED (err u101))

;; Lock NFT to mint shares
(define-public (lock-nft (token-trait <nova-trait-non-fungible>) (token-id uint) (share-supply uint))
    (let (
        (sender tx-sender)
    )
    (asserts! (is-none (var-get locked-nft)) ERR-ALREADY-LOCKED)
    
    (try! (contract-call? token-trait transfer token-id sender (as-contract tx-sender)))
    
    (var-set locked-nft (some {contract: (contract-of token-trait), id: token-id}))
    (try! (ft-mint? share-token share-supply sender))
    (ok true))
)

;; Redeem shares to unlock NFT (only if you hold ALL shares)
;; This is a simplified logic where 100% shares required to unlock.
(define-public (redeem-nft (token-trait <nova-trait-non-fungible>))
    (let (
        (sender tx-sender)
        (locked (unwrap! (var-get locked-nft) ERR-NOT-LOCKED))
        (total (ft-get-supply share-token))
    )
    (asserts! (is-eq (contract-of token-trait) (get contract locked)) (err u102))
    
    ;; Burn all tokens (check balance == total supply)
    (asserts! (is-eq (ft-get-balance share-token sender) total) (err u103))
    (try! (ft-burn? share-token total sender))

    (try! (as-contract (contract-call? token-trait transfer (get id locked) tx-sender sender)))
    (var-set locked-nft none)
    (ok true))
)

;; SIP-010 / Nova Trait Fungible Interface

(define-read-only (get-total-supply)
    (ok (ft-get-supply share-token))
)

(define-read-only (get-name)
    (ok "Fractional Share")
)

(define-read-only (get-symbol)
    (ok "F-NFT")
)

(define-read-only (get-decimals)
    (ok u0)
)

(define-read-only (get-balance (account principal))
    (ok (ft-get-balance share-token account))
)

(define-read-only (get-token-uri)
    (ok none)
)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-eq tx-sender sender) (err u4))
        (match (ft-transfer? share-token amount sender recipient)
            response (begin
                (print memo)
                (ok response)
            )
            error (err error)
        )
    )
)
