---
title: "Trait harden-feedchain"
draft: true
---
```
;; title: dex-analysis
;; version:
;; summary:
;; description:

;; traits
(define-trait vault-callback
  (
    (on-release (principal uint) (response bool uint))
  )
)

;; token definitions
;; Using native STX tokens

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_VAULT_NOT_FOUND (err u101))
(define-constant ERR_STILL_LOCKED (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_INVALID_CONTRACT (err u104))
(define-constant ERR_INVALID_SIGNATURE (err u105))
(define-constant ERR_ASSET_RESTRICTION_FAILED (err u106))
(define-constant ERR_CANNOT_EXTEND (err u107))
(define-constant ERR_NO_BENEFICIARY (err u108))
(define-constant ERR_GRACE_PERIOD_NOT_PASSED (err u109))
(define-constant ERR_BATCH_SIZE_EXCEEDED (err u110))

;; Minimum lock duration (1 day in seconds)
(define-constant MIN_LOCK_DURATION u86400)
;; Grace period for beneficiary claim (30 days after unlock)
(define-constant BENEFICIARY_GRACE_PERIOD u2592000)
;; Maximum batch size for operations
(define-constant MAX_BATCH_SIZE u10)

;; data vars
(define-data-var vault-counter uint u0)
(define-data-var trusted-contract-hash (optional (buff 32)) none)

;; data maps
;; Stores vault information for each user
(define-map vaults
  { vault-id: uint }
  {
    owner: principal,
    amount: uint,
    unlock-time: uint,
    created-at: uint,
    released: bool,
    beneficiary: (optional principal),
    metadata: (optional (string-ascii 100))
  }
)

;; Stores passkey public keys for users (secp256r1)
(define-map user-passkeys
  { user: principal }
  { public-key: (buff 33) }
)

;; Track verified contracts
(define-map verified-contracts
  { contract: principal }
  { verified: bool, hash: (buff 32) }
)

;; public functions

;; Register a passkey for the caller
(define-public (register-passkey (public-key (buff 33)))
  (begin
    (map-set user-passkeys
      { user: tx-sender }
      { public-key: public-key }
    )
    (ok true)
  )
)

;; Create a time-locked vault using Clarity 4's stacks-block-time
(define-public (create-vault (amount uint) (lock-duration uint))
  (let
    (
      (vault-id (var-get vault-counter))
      (current-time stacks-block-time)
      (unlock-time (+ current-time lock-duration))
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= lock-duration MIN_LOCK_DURATION) ERR_INVALID_AMOUNT)

    ;; Store vault data
    (map-set vaults
      { vault-id: vault-id }
      {
        owner: tx-sender,
        amount: amount,
        unlock-time: unlock-time,
        created-at: current-time,
        released: false,
        beneficiary: none,
        metadata: none
      }
    )

    ;; Increment counter
    (var-set vault-counter (+ vault-id u1))

    (ok vault-id)
  )
)


;; Release funds from vault if time has passed
(define-public (release-vault (vault-id uint))
  (let
    (
      (vault-data (unwrap! (map-get? vaults { vault-id: vault-id }) ERR_VAULT_NOT_FOUND))
      (current-time stacks-block-time)
    )
    (asserts! (is-eq tx-sender (get owner vault-data)) ERR_UNAUTHORIZED)
    (asserts! (not (get released vault-data)) ERR_VAULT_NOT_FOUND)
    (asserts! (>= current-time (get unlock-time vault-data)) ERR_STILL_LOCKED)

    ;; Mark as released
    (map-set vaults
      { vault-id: vault-id }
      (merge vault-data { released: true })
    )

    (ok true)
  )
)

```
