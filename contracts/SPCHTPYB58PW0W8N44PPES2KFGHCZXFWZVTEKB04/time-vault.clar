;; Time-Locked Vault Contract
;; Lock STX until a specific block height

(define-constant err-not-owner (err u100))
(define-constant err-still-locked (err u101))
(define-constant err-vault-not-found (err u102))
(define-constant err-already-withdrawn (err u103))

(define-data-var vault-nonce uint u0)

(define-map vaults
    uint
    {
        owner: principal,
        amount: uint,
        unlock-block: uint,
        withdrawn: bool
    }
)

;; Create a time-locked vault
(define-public (create-vault (amount uint) (lock-duration uint))
    (let
        (
            (vault-id (var-get vault-nonce))
            (unlock-block (+ block-height lock-duration))
        )
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        (map-set vaults vault-id {
            owner: tx-sender,
            amount: amount,
            unlock-block: unlock-block,
            withdrawn: false
        })
        
        (var-set vault-nonce (+ vault-id u1))
        (print {event: "vault-created", vault-id: vault-id, amount: amount, unlock-block: unlock-block})
        (ok vault-id)
    )
)

;; Withdraw from vault after unlock time
(define-public (withdraw (vault-id uint))
    (let
        (
            (vault (unwrap! (map-get? vaults vault-id) err-vault-not-found))
        )
        (asserts! (is-eq tx-sender (get owner vault)) err-not-owner)
        (asserts! (>= block-height (get unlock-block vault)) err-still-locked)
        (asserts! (not (get withdrawn vault)) err-already-withdrawn)
        
        (try! (as-contract (stx-transfer? (get amount vault) tx-sender (get owner vault))))
        
        (map-set vaults vault-id (merge vault {withdrawn: true}))
        (print {event: "vault-withdrawn", vault-id: vault-id, amount: (get amount vault)})
        (ok true)
    )
)

;; Extend lock period (owner only)
(define-public (extend-lock (vault-id uint) (additional-blocks uint))
    (let
        (
            (vault (unwrap! (map-get? vaults vault-id) err-vault-not-found))
        )
        (asserts! (is-eq tx-sender (get owner vault)) err-not-owner)
        (asserts! (not (get withdrawn vault)) err-already-withdrawn)
        
        (map-set vaults vault-id (merge vault {
            unlock-block: (+ (get unlock-block vault) additional-blocks)
        }))
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-vault (vault-id uint))
    (map-get? vaults vault-id)
)

(define-read-only (get-vault-count)
    (var-get vault-nonce)
)

(define-read-only (is-unlocked (vault-id uint))
    (match (map-get? vaults vault-id)
        vault
        (>= block-height (get unlock-block vault))
        false
    )
)

(define-read-only (blocks-until-unlock (vault-id uint))
    (match (map-get? vaults vault-id)
        vault
        (if (>= block-height (get unlock-block vault))
            u0
            (- (get unlock-block vault) block-height))
        u0
    )
)
