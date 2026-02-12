;; Time Capsule - Time-Locked Vault Contract
;; A secure vault system for locking STX tokens until a specified block height
;; Compatible with Clarity 3

(define-constant ERR-CAPSULE-NOT-FOUND (err u100))
(define-constant ERR-ALREADY-CLAIMED (err u101))
(define-constant ERR-TOO-EARLY (err u102))
(define-constant ERR-NOT-BENEFICIARY (err u103))
(define-constant ERR-INVALID-AMOUNT (err u104))
(define-constant ERR-INVALID-UNLOCK-TIME (err u105))

;; Capsule counter for unique IDs
(define-data-var capsule-nonce uint u0)

;; Map storing all capsules
(define-map capsules 
    uint 
    {
        owner: principal, 
        amount: uint, 
        unlock-block: uint, 
        beneficiary: principal, 
        is-claimed: bool 
    }
)

;; Check if the vault is ready to be claimed based on block height
(define-read-only (is-unlockable (capsule-id uint))
    (match (map-get? capsules capsule-id)
        capsule (>= burn-block-height (get unlock-block capsule))
        false
    )
)

;; Get capsule details
(define-read-only (get-capsule (capsule-id uint))
    (map-get? capsules capsule-id)
)

;; Get current capsule count
(define-read-only (get-capsule-count)
    (var-get capsule-nonce)
)

;; Create a new time-locked vault
(define-public (create-vault (amount uint) (unlock-block uint) (beneficiary principal))
    (let
        (
            (new-id (+ (var-get capsule-nonce) u1))
        )
        ;; Validate inputs
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (> unlock-block burn-block-height) ERR-INVALID-UNLOCK-TIME)

        ;; Transfer STX to the contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

        ;; Store the capsule
        (map-set capsules new-id {
            owner: tx-sender,
            amount: amount,
            unlock-block: unlock-block,
            beneficiary: beneficiary,
            is-claimed: false
        })

        ;; Update the nonce
        (var-set capsule-nonce new-id)

        ;; Log the event
        (print {
            event: "vault-created", 
            id: new-id,
            owner: tx-sender,
            beneficiary: beneficiary,
            amount: amount,
            unlock-block: unlock-block
        })

        (ok new-id)
    )
)

;; Claim a vault (only beneficiary can claim after unlock time)
(define-public (claim-vault (id uint))
    (let
        (
            (capsule (unwrap! (map-get? capsules id) ERR-CAPSULE-NOT-FOUND))
            (beneficiary (get beneficiary capsule))
            (amount (get amount capsule))
        )
        ;; Verify conditions
        (asserts! (not (get is-claimed capsule)) ERR-ALREADY-CLAIMED)
        (asserts! (is-eq tx-sender beneficiary) ERR-NOT-BENEFICIARY)
        (asserts! (>= burn-block-height (get unlock-block capsule)) ERR-TOO-EARLY)

        ;; Transfer STX from contract to beneficiary
        (try! (as-contract (stx-transfer? amount tx-sender beneficiary)))

        ;; Mark as claimed
        (map-set capsules id (merge capsule { is-claimed: true }))

        ;; Log the event
        (print {
            event: "vault-claimed",
            id: id,
            beneficiary: beneficiary,
            amount: amount
        })

        (ok true)
    )
)