(define-constant CONTRACT_OWNER tx-sender)

(define-constant ERR_NOT_AUTHORIZED (err u1001))
(define-constant ERR_TOKEN_NOT_FOUND (err u1002))
(define-constant ERR_RECORD_NOT_FOUND (err u1003))
(define-constant ERR_INVALID_AMOUNT (err u1004))
(define-constant ERR_RECORD_EXPIRED (err u1005))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1006))
(define-constant ERR_INVALID_EXPIRY (err u1007))
(define-constant ERR_USER_ZERO (err u1008))
(define-constant ERR_ASSET_RESTRICTED (err u1009))
(define-constant ERR_INVALID_SIGNATURE (err u1010))
(define-constant ERR_RECORD_EXISTS (err u1011))

(define-data-var last-token-id uint u0)
(define-data-var last-record-id uint u0)
(define-data-var assets-restricted bool false)

(define-map tokens
  uint
  {
    owner: principal,
    balance: uint,
    uri: (string-ascii 256),
    created-at: uint
  }
)

(define-map token-balances
  { token-id: uint, owner: principal }
  uint
)

(define-map operator-approvals
  { owner: principal, operator: principal }
  bool
)

(define-map user-records
  uint
  {
    token-id: uint,
    owner: principal,
    amount: uint,
    user: principal,
    expiry: uint,
    created-at: uint
  }
)

(define-map frozen-balance
  { token-id: uint, owner: principal }
  uint
)

(define-map user-usable-balance
  { token-id: uint, user: principal }
  uint
)

(define-private (emit-create-user-record (record-id uint) (token-id uint) (amount uint) (owner principal) (user principal) (expiry uint))
  (print { 
    event: "CreateUserRecord", 
    record-id: record-id, 
    token-id: token-id, 
    amount: amount, 
    owner: owner, 
    user: user, 
    expiry: expiry,
    timestamp: stacks-block-time 
  })
)

(define-private (emit-delete-user-record (record-id uint))
  (print { event: "DeleteUserRecord", record-id: record-id, timestamp: stacks-block-time })
)

(define-read-only (get-token (token-id uint))
  (map-get? tokens token-id)
)

(define-read-only (balance-of (owner principal) (token-id uint))
  (default-to u0 (map-get? token-balances { token-id: token-id, owner: owner }))
)

(define-read-only (usable-balance-of (account principal) (token-id uint))
  (default-to u0 (map-get? user-usable-balance { token-id: token-id, user: account }))
)

(define-read-only (frozen-balance-of (account principal) (token-id uint))
  (default-to u0 (map-get? frozen-balance { token-id: token-id, owner: account }))
)

(define-read-only (user-record-of (record-id uint))
  (map-get? user-records record-id)
)

(define-read-only (is-approved-for-all (owner principal) (operator principal))
  (default-to false (map-get? operator-approvals { owner: owner, operator: operator }))
)

(define-read-only (get-contract-hash)
  (contract-hash? tx-sender)
)

(define-read-only (get-current-time)
  stacks-block-time
)

(define-read-only (check-restrictions)
  (var-get assets-restricted)
)

(define-read-only (verify-rental-signature 
  (msg-hash (buff 32))
  (sig (buff 64))
  (pub-key (buff 33)))
  (secp256r1-verify msg-hash sig pub-key)
)

(define-read-only (get-token-uri (token-id uint))
  (match (map-get? tokens token-id) 
    token (some (get uri token)) 
    none
  )
)

(define-read-only (get-token-hash (token-id uint))
  (match (map-get? tokens token-id)
    token (some (keccak256 (unwrap-panic (to-consensus-buff? (get uri token)))))
    none
  )
)

(define-read-only (is-record-valid (record-id uint))
  (match (map-get? user-records record-id)
    record (> (get expiry record) stacks-block-time)
    false
  )
)

(define-public (mint (recipient principal) (amount uint) (uri (string-ascii 256)))
  (let ((token-id (+ (var-get last-token-id) u1)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (not (var-get assets-restricted)) ERR_ASSET_RESTRICTED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (map-set tokens token-id {
      owner: recipient,
      balance: amount,
      uri: uri,
      created-at: stacks-block-time
    })
    (map-set token-balances { token-id: token-id, owner: recipient } amount)
    (var-set last-token-id token-id)
    (print { event: "Mint", token-id: token-id, recipient: recipient, amount: amount, timestamp: stacks-block-time })
    (ok token-id)
  )
)

(define-public (transfer (token-id uint) (from principal) (to principal) (amount uint))
  (let (
    (from-balance (balance-of from token-id))
    (from-frozen (frozen-balance-of from token-id))
    (available (- from-balance from-frozen))
  )
    (asserts! (or (is-eq tx-sender from) (is-approved-for-all from tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (>= available amount) ERR_INSUFFICIENT_BALANCE)
    (map-set token-balances { token-id: token-id, owner: from } (- from-balance amount))
    (map-set token-balances { token-id: token-id, owner: to } (+ (balance-of to token-id) amount))
    (print { event: "Transfer", token-id: token-id, from: from, to: to, amount: amount, timestamp: stacks-block-time })
    (ok true)
  )
)

(define-public (set-approval-for-all (operator principal) (approved bool))
  (begin
    (map-set operator-approvals { owner: tx-sender, operator: operator } approved)
    (print { event: "ApprovalForAll", owner: tx-sender, operator: operator, approved: approved, timestamp: stacks-block-time })
    (ok true)
  )
)

(define-public (create-user-record 
  (owner principal)
  (user principal)
  (token-id uint)
  (amount uint)
  (expiry uint))
  (let (
    (record-id (+ (var-get last-record-id) u1))
    (owner-balance (balance-of owner token-id))
    (current-frozen (frozen-balance-of owner token-id))
    (available (- owner-balance current-frozen))
  )
    (asserts! (or (is-eq tx-sender owner) (is-approved-for-all owner tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (not (is-eq user CONTRACT_OWNER)) ERR_USER_ZERO)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> expiry stacks-block-time) ERR_INVALID_EXPIRY)
    (asserts! (>= available amount) ERR_INSUFFICIENT_BALANCE)
    (map-set user-records record-id {
      token-id: token-id,
      owner: owner,
      amount: amount,
      user: user,
      expiry: expiry,
      created-at: stacks-block-time
    })
    (map-set frozen-balance { token-id: token-id, owner: owner } (+ current-frozen amount))
    (map-set user-usable-balance 
      { token-id: token-id, user: user } 
      (+ (usable-balance-of user token-id) amount)
    )
    (var-set last-record-id record-id)
    (emit-create-user-record record-id token-id amount owner user expiry)
    (ok record-id)
  )
)

(define-public (delete-user-record (record-id uint))
  (let ((record (unwrap! (map-get? user-records record-id) ERR_RECORD_NOT_FOUND)))
    (asserts! (or 
      (is-eq tx-sender (get owner record))
      (is-eq tx-sender (get user record))
      (is-approved-for-all (get owner record) tx-sender)
      (<= (get expiry record) stacks-block-time)
    ) ERR_NOT_AUTHORIZED)
    (map-set frozen-balance 
      { token-id: (get token-id record), owner: (get owner record) }
      (- (frozen-balance-of (get owner record) (get token-id record)) (get amount record))
    )
    (map-set user-usable-balance
      { token-id: (get token-id record), user: (get user record) }
      (- (usable-balance-of (get user record) (get token-id record)) (get amount record))
    )
    (map-delete user-records record-id)
    (emit-delete-user-record record-id)
    (ok true)
  )
)

(define-public (extend-rental (record-id uint) (new-expiry uint))
  (let ((record (unwrap! (map-get? user-records record-id) ERR_RECORD_NOT_FOUND)))
    (asserts! (or 
      (is-eq tx-sender (get owner record))
      (is-approved-for-all (get owner record) tx-sender)
    ) ERR_NOT_AUTHORIZED)
    (asserts! (> new-expiry (get expiry record)) ERR_INVALID_EXPIRY)
    (map-set user-records record-id (merge record { expiry: new-expiry }))
    (print { event: "RentalExtended", record-id: record-id, new-expiry: new-expiry, timestamp: stacks-block-time })
    (ok true)
  )
)

(define-public (create-user-record-with-sig
  (owner principal)
  (user principal)
  (token-id uint)
  (amount uint)
  (expiry uint)
  (sig (buff 64))
  (pub-key (buff 33)))
  (let (
    (msg-hash (keccak256 (concat 
      (concat (unwrap-panic (to-consensus-buff? owner)) (unwrap-panic (to-consensus-buff? user)))
      (concat (unwrap-panic (to-consensus-buff? token-id)) (unwrap-panic (to-consensus-buff? amount)))
    )))
  )
    (asserts! (secp256r1-verify msg-hash sig pub-key) ERR_INVALID_SIGNATURE)
    (create-user-record owner user token-id amount expiry)
  )
)

(define-public (batch-delete-expired-records (record-ids (list 20 uint)))
  (begin
    (map cleanup-expired-record record-ids)
    (ok true)
  )
)

(define-private (cleanup-expired-record (record-id uint))
  (match (map-get? user-records record-id)
    record
    (if (<= (get expiry record) stacks-block-time)
      (begin
        (map-set frozen-balance 
          { token-id: (get token-id record), owner: (get owner record) }
          (- (frozen-balance-of (get owner record) (get token-id record)) (get amount record))
        )
        (map-set user-usable-balance
          { token-id: (get token-id record), user: (get user record) }
          (- (usable-balance-of (get user record) (get token-id record)) (get amount record))
        )
        (map-delete user-records record-id)
        (print { event: "RecordExpired", record-id: record-id, timestamp: stacks-block-time })
        true
      )
      false
    )
    false
  )
)

(define-public (set-asset-restriction (restricted bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set assets-restricted restricted)
    (ok true)
  )
)

(define-read-only (get-last-token-id)
  (var-get last-token-id)
)

(define-read-only (get-last-record-id)
  (var-get last-record-id)
)

(define-read-only (supports-interface (interface-id (buff 4)))
  (or 
    (is-eq interface-id 0xc26d96cc)
    (is-eq interface-id 0xd9b67a26)
    (is-eq interface-id 0x01ffc9a7)
  )
)
