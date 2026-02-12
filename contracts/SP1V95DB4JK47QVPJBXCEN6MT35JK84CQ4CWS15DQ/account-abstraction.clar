(define-constant CONTRACT_OWNER tx-sender)

(define-constant ERR_NOT_AUTHORIZED (err u1001))
(define-constant ERR_ACCOUNT_NOT_FOUND (err u1002))
(define-constant ERR_INVALID_SIGNATURE (err u1003))
(define-constant ERR_INVALID_NONCE (err u1004))
(define-constant ERR_INSUFFICIENT_DEPOSIT (err u1005))
(define-constant ERR_OP_EXPIRED (err u1006))
(define-constant ERR_OP_NOT_YET_VALID (err u1007))
(define-constant ERR_ACCOUNT_EXISTS (err u1008))
(define-constant ERR_INVALID_PAYMASTER (err u1009))
(define-constant ERR_ASSET_RESTRICTED (err u1010))
(define-constant ERR_INVALID_ENTRY_POINT (err u1012))

(define-constant SIG_VALIDATION_SUCCESS u0)
(define-constant SIG_VALIDATION_FAILED u1)

(define-data-var entry-point-enabled bool true)
(define-data-var assets-restricted bool false)
(define-data-var total-deposits uint u0)

(define-map smart-accounts
  principal
  {
    public-key: (buff 33),
    nonce: uint,
    deposit: uint,
    created-at: uint,
    is-active: bool
  }
)

(define-map account-nonces
  { account: principal, key: uint }
  uint
)

(define-map paymasters
  principal
  {
    deposit: uint,
    stake: uint,
    unstake-delay: uint,
    withdraw-time: uint,
    is-active: bool
  }
)

(define-map pending-ops
  (buff 32)
  {
    sender: principal,
    nonce: uint,
    valid-after: uint,
    valid-until: uint,
    processed: bool
  }
)

(define-private (emit-account-created (account principal) (pk (buff 33)))
  (print { event: "AccountCreated", account: account, public-key: pk, timestamp: stacks-block-time })
)

(define-private (emit-op-executed (op-hash (buff 32)) (sender principal))
  (print { event: "UserOperationExecuted", op-hash: op-hash, sender: sender, timestamp: stacks-block-time })
)

(define-private (emit-deposited (account principal) (amount uint))
  (print { event: "Deposited", account: account, amount: amount, timestamp: stacks-block-time })
)

(define-read-only (get-account (account principal))
  (map-get? smart-accounts account)
)

(define-read-only (get-nonce (account principal) (key uint))
  (default-to u0 (map-get? account-nonces { account: account, key: key }))
)

(define-read-only (get-deposit (account principal))
  (match (map-get? smart-accounts account) acc (get deposit acc) u0)
)

(define-read-only (get-paymaster (paymaster principal))
  (map-get? paymasters paymaster)
)

(define-read-only (get-entry-point-status)
  (var-get entry-point-enabled)
)

(define-read-only (get-current-time)
  stacks-block-time
)

(define-read-only (get-contract-hash-info)
  (contract-hash? tx-sender)
)

(define-read-only (check-asset-restrictions)
  (var-get assets-restricted)
)

(define-read-only (verify-user-op-signature (msg-hash (buff 32)) (sig (buff 64)) (pk (buff 33)))
  (if (secp256r1-verify msg-hash sig pk) SIG_VALIDATION_SUCCESS SIG_VALIDATION_FAILED)
)

(define-read-only (validate-user-op-timing (valid-after uint) (valid-until uint))
  (let ((t stacks-block-time))
    (if (> valid-after t) (err u1) (if (and (> valid-until u0) (< valid-until t)) (err u2) (ok true)))
  )
)

(define-read-only (compute-op-hash (sender principal) (nonce uint) (call-data (buff 256)) (valid-after uint) (valid-until uint))
  (sha256 (concat (concat (unwrap-panic (to-consensus-buff? sender)) (unwrap-panic (to-consensus-buff? nonce)))
    (concat call-data (concat (unwrap-panic (to-consensus-buff? valid-after)) (unwrap-panic (to-consensus-buff? valid-until))))))
)

(define-read-only (get-account-info (account principal))
  (match (map-get? smart-accounts account)
    acc { exists: true, nonce: (get nonce acc), deposit: (get deposit acc), is-active: (get is-active acc) }
    { exists: false, nonce: u0, deposit: u0, is-active: false }
  )
)

(define-read-only (is-valid-signature (account principal) (msg-hash (buff 32)) (sig (buff 64)))
  (match (map-get? smart-accounts account) acc (secp256r1-verify msg-hash sig (get public-key acc)) false)
)

(define-read-only (get-entry-point-info)
  { owner: CONTRACT_OWNER, enabled: (var-get entry-point-enabled), contract-hash: (contract-hash? tx-sender), current-time: stacks-block-time }
)

(define-read-only (estimate-gas (call-gas uint) (ver-gas uint) (pre-gas uint))
  (+ call-gas (+ ver-gas pre-gas))
)

(define-public (create-account (public-key (buff 33)))
  (let ((account tx-sender))
    (asserts! (is-none (map-get? smart-accounts account)) ERR_ACCOUNT_EXISTS)
    (asserts! (not (var-get assets-restricted)) ERR_ASSET_RESTRICTED)
    (map-set smart-accounts account { public-key: public-key, nonce: u0, deposit: u0, created-at: stacks-block-time, is-active: true })
    (emit-account-created account public-key)
    (ok account)
  )
)

(define-public (deposit-to (account principal) (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INSUFFICIENT_DEPOSIT)
    (try! (stx-transfer? amount tx-sender CONTRACT_OWNER))
    (var-set total-deposits (+ (var-get total-deposits) amount))
    (match (map-get? smart-accounts account)
      acc (map-set smart-accounts account (merge acc { deposit: (+ (get deposit acc) amount) }))
      (map-set smart-accounts account { public-key: 0x000000000000000000000000000000000000000000000000000000000000000000, nonce: u0, deposit: amount, created-at: stacks-block-time, is-active: true })
    )
    (emit-deposited account amount)
    (ok amount)
  )
)

(define-public (withdraw-to (recipient principal) (amount uint))
  (let ((account tx-sender))
    (match (map-get? smart-accounts account)
      acc 
        (begin
          (asserts! (>= (get deposit acc) amount) ERR_INSUFFICIENT_DEPOSIT)
          (try! (stx-transfer? amount CONTRACT_OWNER recipient))
          (var-set total-deposits (- (var-get total-deposits) amount))
          (map-set smart-accounts account (merge acc { deposit: (- (get deposit acc) amount) }))
          (print { event: "Withdrawn", account: account, recipient: recipient, amount: amount, timestamp: stacks-block-time })
          (ok amount)
        )
      ERR_ACCOUNT_NOT_FOUND
    )
  )
)

(define-public (validate-user-op
    (sender principal) (nonce uint) (sig (buff 64)) (msg-hash (buff 32))
    (valid-after uint) (valid-until uint) (missing-funds uint))
  (let (
    (acc (unwrap! (map-get? smart-accounts sender) ERR_ACCOUNT_NOT_FOUND))
    (t stacks-block-time)
  )
    (asserts! (var-get entry-point-enabled) ERR_INVALID_ENTRY_POINT)
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active acc) ERR_ACCOUNT_NOT_FOUND)
    (asserts! (is-eq nonce (get nonce acc)) ERR_INVALID_NONCE)
    (asserts! (<= valid-after t) ERR_OP_NOT_YET_VALID)
    (asserts! (or (is-eq valid-until u0) (>= valid-until t)) ERR_OP_EXPIRED)
    (asserts! (secp256r1-verify msg-hash sig (get public-key acc)) ERR_INVALID_SIGNATURE)
    (asserts! (>= (get deposit acc) missing-funds) ERR_INSUFFICIENT_DEPOSIT)
    (map-set smart-accounts sender (merge acc { nonce: (+ (get nonce acc) u1) }))
    (ok SIG_VALIDATION_SUCCESS)
  )
)

(define-public (handle-op
    (sender principal) (nonce uint) (sig (buff 64)) (msg-hash (buff 32))
    (valid-after uint) (valid-until uint) (call-gas uint) (ver-gas uint) (pre-gas uint))
  (let (
    (acc (unwrap! (map-get? smart-accounts sender) ERR_ACCOUNT_NOT_FOUND))
    (total-gas (+ call-gas (+ ver-gas pre-gas)))
    (op-hash (compute-op-hash sender nonce 0x00 valid-after valid-until))
  )
    (asserts! (var-get entry-point-enabled) ERR_INVALID_ENTRY_POINT)
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (try! (validate-user-op sender nonce sig msg-hash valid-after valid-until total-gas))
    (map-set pending-ops op-hash { sender: sender, nonce: nonce, valid-after: valid-after, valid-until: valid-until, processed: true })
    (map-set smart-accounts sender (merge acc { deposit: (- (get deposit acc) total-gas) }))
    (emit-op-executed op-hash sender)
    (ok op-hash)
  )
)

(define-public (register-paymaster (stake uint) (unstake-delay uint))
  (let ((paymaster tx-sender))
    (asserts! (> stake u0) ERR_INSUFFICIENT_DEPOSIT)
    (asserts! (not (var-get assets-restricted)) ERR_ASSET_RESTRICTED)
    (try! (stx-transfer? stake tx-sender CONTRACT_OWNER))
    (map-set paymasters paymaster { deposit: u0, stake: stake, unstake-delay: unstake-delay, withdraw-time: u0, is-active: true })
    (print { event: "PaymasterRegistered", paymaster: paymaster, stake: stake, timestamp: stacks-block-time })
    (ok true)
  )
)

(define-public (add-paymaster-deposit (amount uint))
  (let ((paymaster tx-sender))
    (match (map-get? paymasters paymaster)
      pm 
        (begin
          (try! (stx-transfer? amount tx-sender CONTRACT_OWNER))
          (map-set paymasters paymaster (merge pm { deposit: (+ (get deposit pm) amount) }))
          (print { event: "PaymasterDeposited", paymaster: paymaster, amount: amount, timestamp: stacks-block-time })
          (ok amount)
        )
      ERR_INVALID_PAYMASTER
    )
  )
)

(define-public (unlock-paymaster-stake)
  (let ((paymaster tx-sender))
    (match (map-get? paymasters paymaster)
      pm 
        (begin
          (map-set paymasters paymaster (merge pm { withdraw-time: (+ stacks-block-time (get unstake-delay pm)) }))
          (print { event: "PaymasterStakeUnlocked", paymaster: paymaster, timestamp: stacks-block-time })
          (ok true)
        )
      ERR_INVALID_PAYMASTER
    )
  )
)

(define-public (withdraw-paymaster-stake (recipient principal))
  (let ((paymaster tx-sender))
    (match (map-get? paymasters paymaster)
      pm 
        (begin
          (asserts! (> (get withdraw-time pm) u0) ERR_NOT_AUTHORIZED)
          (asserts! (>= stacks-block-time (get withdraw-time pm)) ERR_NOT_AUTHORIZED)
          (try! (stx-transfer? (get stake pm) CONTRACT_OWNER recipient))
          (map-set paymasters paymaster (merge pm { stake: u0, withdraw-time: u0 }))
          (print { event: "PaymasterStakeWithdrawn", paymaster: paymaster, amount: (get stake pm), timestamp: stacks-block-time })
          (ok (get stake pm))
        )
      ERR_INVALID_PAYMASTER
    )
  )
)

(define-public (validate-paymaster-op (paymaster principal) (sender principal) (max-cost uint))
  (let ((pm (unwrap! (map-get? paymasters paymaster) ERR_INVALID_PAYMASTER)))
    (asserts! (get is-active pm) ERR_INVALID_PAYMASTER)
    (asserts! (>= (get deposit pm) max-cost) ERR_INSUFFICIENT_DEPOSIT)
    (map-set paymasters paymaster (merge pm { deposit: (- (get deposit pm) max-cost) }))
    (print { event: "PaymasterValidated", paymaster: paymaster, sender: sender, max-cost: max-cost, timestamp: stacks-block-time })
    (ok SIG_VALIDATION_SUCCESS)
  )
)

(define-public (update-account-key (new-pk (buff 33)))
  (let ((account tx-sender))
    (match (map-get? smart-accounts account)
      acc 
        (begin
          (map-set smart-accounts account (merge acc { public-key: new-pk }))
          (print { event: "AccountKeyUpdated", account: account, timestamp: stacks-block-time })
          (ok true)
        )
      ERR_ACCOUNT_NOT_FOUND
    )
  )
)

(define-public (deactivate-account)
  (let ((account tx-sender))
    (match (map-get? smart-accounts account)
      acc (begin (map-set smart-accounts account (merge acc { is-active: false })) (ok true))
      ERR_ACCOUNT_NOT_FOUND
    )
  )
)

(define-public (reactivate-account)
  (let ((account tx-sender))
    (match (map-get? smart-accounts account)
      acc (begin (map-set smart-accounts account (merge acc { is-active: true })) (ok true))
      ERR_ACCOUNT_NOT_FOUND
    )
  )
)

(define-public (set-entry-point-status (enabled bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set entry-point-enabled enabled)
    (print { event: "EntryPointStatusUpdated", enabled: enabled, timestamp: stacks-block-time })
    (ok enabled)
  )
)

(define-public (set-asset-restrictions (restricted bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set assets-restricted restricted)
    (print { event: "AssetRestrictionsUpdated", restricted: restricted, timestamp: stacks-block-time })
    (ok restricted)
  )
)
