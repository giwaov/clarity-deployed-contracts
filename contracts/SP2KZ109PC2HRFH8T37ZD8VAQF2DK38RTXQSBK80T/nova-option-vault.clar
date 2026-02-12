
;; nova-option-vault.clar
;; Simplified covered call vault
;; CLARITY VERSION: 2

(use-trait nova-trait-fungible .nova-trait-fungible.nova-trait-fungible)

(define-map vaults
    uint
    {
        asset: principal,
        strike-price: uint,
        expiry: uint,
        deposits: uint
    }
)
(define-data-var vault-id-nonce uint u0)

(define-public (create-vault (asset <nova-trait-fungible>) (strike uint) (expiry uint))
    (let ((id (var-get vault-id-nonce)))
        (map-set vaults id {
            asset: (contract-of asset),
            strike-price: strike,
            expiry: expiry,
            deposits: u0
        })
        (var-set vault-id-nonce (+ id u1))
        (ok id)
    )
)

(define-public (deposit (id uint) (amount uint) (token <nova-trait-fungible>))
    (let ((vault (unwrap! (map-get? vaults id) (err u404))))
        (asserts! (is-eq (contract-of token) (get asset vault)) (err u100))
        (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
        (map-set vaults id (merge vault {deposits: (+ (get deposits vault) amount)}))
        (ok true)
    )
)
