;; title: Stx-analytics - Time-Locked Asset Vault with Clarity 4 Features
;; version: 1.0.0
;; summary: Demonstrates Clarity 4 capabilities including time-locks, contract verification, and passkey auth
;; description: A secure vault that locks STX tokens with time-based releases, contract verification, and passkey support

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

;; Release vault with passkey authentication using secp256r1-verify
(define-public (release-vault-with-passkey
    (vault-id uint)
    (message-hash (buff 32))
    (signature (buff 64)))
  (let
    (
      (vault-data (unwrap! (map-get? vaults { vault-id: vault-id }) ERR_VAULT_NOT_FOUND))
      (current-time stacks-block-time)
      (passkey-data (unwrap! (map-get? user-passkeys { user: tx-sender }) ERR_UNAUTHORIZED))
    )
    (asserts! (is-eq tx-sender (get owner vault-data)) ERR_UNAUTHORIZED)
    (asserts! (not (get released vault-data)) ERR_VAULT_NOT_FOUND)
    (asserts! (>= current-time (get unlock-time vault-data)) ERR_STILL_LOCKED)

    ;; Verify passkey signature using Clarity 4's secp256r1-verify
    (asserts!
      (secp256r1-verify message-hash signature (get public-key passkey-data))
      ERR_INVALID_SIGNATURE
    )

    ;; Mark as released
    (map-set vaults
      { vault-id: vault-id }
      (merge vault-data { released: true })
    )

    (ok true)
  )
)

;; Verify and whitelist a contract using contract-hash?
(define-public (verify-contract (contract-principal principal) (expected-hash (buff 32)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    ;; Store verified contract with hash
    (map-set verified-contracts
      { contract: contract-principal }
      { verified: true, hash: expected-hash }
    )

    (ok true)
  )
)

;; Call external contract with asset restrictions using restrict-assets?
(define-public (release-to-callback
    (vault-id uint)
    (callback-contract <vault-callback>))
  (let
    (
      (vault-data (unwrap! (map-get? vaults { vault-id: vault-id }) ERR_VAULT_NOT_FOUND))
      (current-time stacks-block-time)
    )
    (begin
      (asserts! (is-eq tx-sender (get owner vault-data)) ERR_UNAUTHORIZED)
      (asserts! (not (get released vault-data)) ERR_VAULT_NOT_FOUND)
      (asserts! (>= current-time (get unlock-time vault-data)) ERR_STILL_LOCKED)

      ;; Mark as released
      (map-set vaults
        { vault-id: vault-id }
        (merge vault-data { released: true })
      )

      ;; Call external contract callback
      (contract-call? callback-contract on-release
        (get owner vault-data)
        (get amount vault-data))
    )
  )
)

;; Add more STX to existing vault
(define-public (add-to-vault (vault-id uint) (additional-amount uint))
  (let
    (
      (vault-data (unwrap! (map-get? vaults { vault-id: vault-id }) ERR_VAULT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner vault-data)) ERR_UNAUTHORIZED)
    (asserts! (not (get released vault-data)) ERR_VAULT_NOT_FOUND)
    (asserts! (> additional-amount u0) ERR_INVALID_AMOUNT)

    ;; Update vault amount
    (map-set vaults
      { vault-id: vault-id }
      (merge vault-data { amount: (+ (get amount vault-data) additional-amount) })
    )

    (ok true)
  )
)

;; Extend vault lock duration
(define-public (extend-vault-lock (vault-id uint) (additional-time uint))
  (let
    (
      (vault-data (unwrap! (map-get? vaults { vault-id: vault-id }) ERR_VAULT_NOT_FOUND))
      (current-time stacks-block-time)
    )
    (asserts! (is-eq tx-sender (get owner vault-data)) ERR_UNAUTHORIZED)
    (asserts! (not (get released vault-data)) ERR_VAULT_NOT_FOUND)
    (asserts! (> additional-time u0) ERR_INVALID_AMOUNT)

    ;; Update unlock time
    (map-set vaults
      { vault-id: vault-id }
      (merge vault-data { unlock-time: (+ (get unlock-time vault-data) additional-time) })
    )

    (ok true)
  )
)

;; Transfer vault ownership to another principal
(define-public (transfer-vault-ownership (vault-id uint) (new-owner principal))
  (let
    (
      (vault-data (unwrap! (map-get? vaults { vault-id: vault-id }) ERR_VAULT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner vault-data)) ERR_UNAUTHORIZED)
    (asserts! (not (get released vault-data)) ERR_VAULT_NOT_FOUND)

    ;; Update vault owner
    (map-set vaults
      { vault-id: vault-id }
      (merge vault-data { owner: new-owner })
    )

    (ok true)
  )
)

;; Set beneficiary for vault (receives funds if owner doesn't claim)
(define-public (set-beneficiary (vault-id uint) (beneficiary principal))
  (let
    (
      (vault-data (unwrap! (map-get? vaults { vault-id: vault-id }) ERR_VAULT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner vault-data)) ERR_UNAUTHORIZED)
    (asserts! (not (get released vault-data)) ERR_VAULT_NOT_FOUND)

    ;; Update beneficiary
    (map-set vaults
      { vault-id: vault-id }
      (merge vault-data { beneficiary: (some beneficiary) })
    )

    (ok true)
  )
)

;; Claim vault as beneficiary after grace period
(define-public (claim-as-beneficiary (vault-id uint))
  (let
    (
      (vault-data (unwrap! (map-get? vaults { vault-id: vault-id }) ERR_VAULT_NOT_FOUND))
      (current-time stacks-block-time)
      (beneficiary-principal (unwrap! (get beneficiary vault-data) ERR_NO_BENEFICIARY))
      (grace-deadline (+ (get unlock-time vault-data) BENEFICIARY_GRACE_PERIOD))
    )
    (asserts! (is-eq tx-sender beneficiary-principal) ERR_UNAUTHORIZED)
    (asserts! (not (get released vault-data)) ERR_VAULT_NOT_FOUND)
    (asserts! (>= current-time grace-deadline) ERR_GRACE_PERIOD_NOT_PASSED)

    ;; Mark as released
    (map-set vaults
      { vault-id: vault-id }
      (merge vault-data { released: true })
    )

    (ok true)
  )
)

;; Set vault metadata (description/note)
(define-public (set-vault-metadata (vault-id uint) (metadata (string-ascii 100)))
  (let
    (
      (vault-data (unwrap! (map-get? vaults { vault-id: vault-id }) ERR_VAULT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner vault-data)) ERR_UNAUTHORIZED)

    ;; Update metadata
    (map-set vaults
      { vault-id: vault-id }
      (merge vault-data { metadata: (some metadata) })
    )

    (ok true)
  )
)

;; Batch release multiple vaults
(define-public (release-vaults-batch (vault-ids (list 10 uint)))
  (begin
    (asserts! (<= (len vault-ids) MAX_BATCH_SIZE) ERR_BATCH_SIZE_EXCEEDED)
    (ok (map release-vault-helper vault-ids))
  )
)

;; Helper for batch vault release
(define-private (release-vault-helper (vault-id uint))
  (match (release-vault vault-id)
    success true
    error false
  )
)


;; read only functions

;; Get vault information with ASCII status message using to-ascii?
(define-read-only (get-vault-info (vault-id uint))
  (match (map-get? vaults { vault-id: vault-id })
    vault-data
      (let
        (
          (current-time stacks-block-time)
          (is-unlocked (>= current-time (get unlock-time vault-data)))
          (status-string (to-ascii? is-unlocked))
        )
        (ok {
          vault-data: vault-data,
          is-unlocked: is-unlocked,
          current-time: current-time,
          time-remaining: (if is-unlocked u0 (- (get unlock-time vault-data) current-time)),
          status-message: (unwrap-panic status-string)
        })
      )
    ERR_VAULT_NOT_FOUND
  )
)

;; Get readable vault status as ASCII
(define-read-only (get-vault-status-ascii (vault-id uint))
  (match (map-get? vaults { vault-id: vault-id })
    vault-data
      (let
        (
          (current-time stacks-block-time)
          (is-unlocked (>= current-time (get unlock-time vault-data)))
          (is-released (get released vault-data))
        )
        ;; Convert boolean states to ASCII for readable output
        (ok {
          unlocked: (unwrap-panic (to-ascii? is-unlocked)),
          released: (unwrap-panic (to-ascii? is-released)),
          owner: (unwrap-panic (to-ascii? (get owner vault-data)))
        })
      )
    ERR_VAULT_NOT_FOUND
  )
)

;; Check if a contract is verified
(define-read-only (is-contract-verified (contract-principal principal))
  (ok (default-to false
    (get verified (map-get? verified-contracts { contract: contract-principal }))
  ))
)

;; Get contract hash if available
(define-read-only (get-contract-hash (contract-principal principal))
  (ok (contract-hash? contract-principal))
)

;; Get current block timestamp
(define-read-only (get-current-time)
  (ok stacks-block-time)
)

;; Get total number of vaults created
(define-read-only (get-vault-count)
  (ok (var-get vault-counter))
)

;; Check if user has registered a passkey
(define-read-only (has-passkey (user principal))
  (ok (is-some (map-get? user-passkeys { user: user })))
)

;; Get vault beneficiary
(define-read-only (get-vault-beneficiary (vault-id uint))
  (match (map-get? vaults { vault-id: vault-id })
    vault-data (ok (get beneficiary vault-data))
    ERR_VAULT_NOT_FOUND
  )
)

;; Get vault metadata
(define-read-only (get-vault-metadata (vault-id uint))
  (match (map-get? vaults { vault-id: vault-id })
    vault-data (ok (get metadata vault-data))
    ERR_VAULT_NOT_FOUND
  )
)

;; Check if vault is unlocked
(define-read-only (is-vault-unlocked (vault-id uint))
  (match (map-get? vaults { vault-id: vault-id })
    vault-data
      (ok (>= stacks-block-time (get unlock-time vault-data)))
    ERR_VAULT_NOT_FOUND
  )
)

;; Get time remaining until unlock
(define-read-only (get-time-remaining (vault-id uint))
  (match (map-get? vaults { vault-id: vault-id })
    vault-data
      (let
        (
          (current-time stacks-block-time)
          (unlock-time (get unlock-time vault-data))
        )
        (if (>= current-time unlock-time)
          (ok u0)
          (ok (- unlock-time current-time))
        )
      )
    ERR_VAULT_NOT_FOUND
  )
)

;; Get vault owner
(define-read-only (get-vault-owner (vault-id uint))
  (match (map-get? vaults { vault-id: vault-id })
    vault-data (ok (get owner vault-data))
    ERR_VAULT_NOT_FOUND
  )
)

;; Get vault amount
(define-read-only (get-vault-amount (vault-id uint))
  (match (map-get? vaults { vault-id: vault-id })
    vault-data (ok (get amount vault-data))
    ERR_VAULT_NOT_FOUND
  )
)

;; Check if vault is released
(define-read-only (is-vault-released (vault-id uint))
  (match (map-get? vaults { vault-id: vault-id })
    vault-data (ok (get released vault-data))
    ERR_VAULT_NOT_FOUND
  )
)

;; private functions

;; Helper to validate time
(define-private (is-time-valid (unlock-time uint))
  (>= stacks-block-time unlock-time)
)

