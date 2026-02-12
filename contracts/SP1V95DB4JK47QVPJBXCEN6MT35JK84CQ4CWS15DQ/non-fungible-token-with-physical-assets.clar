(define-constant CONTRACT_OWNER tx-sender)

(define-constant ERR_NOT_AUTHORIZED (err u1001))
(define-constant ERR_TOKEN_NOT_FOUND (err u1002))
(define-constant ERR_TOKEN_EXISTS (err u1003))
(define-constant ERR_INVALID_ASSET (err u1004))
(define-constant ERR_NOT_ENGAGED (err u1005))
(define-constant ERR_WRONG_STATE (err u1006))
(define-constant ERR_TIMEOUT_EXPIRED (err u1007))
(define-constant ERR_INVALID_HASH (err u1008))
(define-constant ERR_ASSET_RESTRICTED (err u1009))
(define-constant ERR_INVALID_SIGNATURE (err u1010))

(define-constant STATE_NOT_ASSIGNED u0)
(define-constant STATE_WAITING_FOR_OWNER u1)
(define-constant STATE_ENGAGED_WITH_OWNER u2)
(define-constant STATE_WAITING_FOR_USER u3)
(define-constant STATE_ENGAGED_WITH_USER u4)
(define-constant STATE_USER_ASSIGNED u5)

(define-data-var last-token-id uint u0)
(define-data-var assets-restricted bool false)

(define-map tokens
  uint
  {
    owner: principal,
    user: (optional principal),
    asset-address: (optional principal),
    state: uint,
    data-engagement: (optional (buff 33)),
    hash-k-oa: (optional (buff 32)),
    hash-k-ua: (optional (buff 32)),
    timestamp: uint,
    timeout: uint,
    uri: (string-ascii 256),
    created-at: uint
  }
)

(define-map asset-to-token principal uint)
(define-map owner-balance principal uint)
(define-map user-balance principal uint)
(define-map user-owner-balance { user: principal, owner: principal } uint)

(define-private (emit-user-assigned (token-id uint) (user principal))
  (print { event: "UserAssigned", token-id: token-id, user: user, timestamp: stacks-block-time })
)

(define-private (emit-owner-engaged (token-id uint))
  (print { event: "OwnerEngaged", token-id: token-id, timestamp: stacks-block-time })
)

(define-private (emit-user-engaged (token-id uint))
  (print { event: "UserEngaged", token-id: token-id, timestamp: stacks-block-time })
)

(define-private (emit-timeout-alarm (token-id uint))
  (print { event: "TimeoutAlarm", token-id: token-id, timestamp: stacks-block-time })
)

(define-read-only (get-token (token-id uint))
  (map-get? tokens token-id)
)

(define-read-only (owner-of (token-id uint))
  (match (map-get? tokens token-id) token (some (get owner token)) none)
)

(define-read-only (user-of (token-id uint))
  (match (map-get? tokens token-id) token (get user token) none)
)

(define-read-only (token-from-asset (asset-addr principal))
  (map-get? asset-to-token asset-addr)
)

(define-read-only (owner-of-from-asset (asset-addr principal))
  (match (map-get? asset-to-token asset-addr)
    token-id (owner-of token-id)
    none
  )
)

(define-read-only (user-of-from-asset (asset-addr principal))
  (match (map-get? asset-to-token asset-addr)
    token-id (user-of token-id)
    none
  )
)

(define-read-only (balance-of (owner principal))
  (default-to u0 (map-get? owner-balance owner))
)

(define-read-only (user-balance-of (user principal))
  (default-to u0 (map-get? user-balance user))
)

(define-read-only (user-balance-of-owner (user principal) (owner principal))
  (default-to u0 (map-get? user-owner-balance { user: user, owner: owner }))
)

(define-read-only (get-token-state (token-id uint))
  (match (map-get? tokens token-id) token (some (get state token)) none)
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

(define-read-only (verify-asset-signature 
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

(define-public (mint 
  (recipient principal)
  (asset-addr (optional principal))
  (uri (string-ascii 256)))
  (let (
    (token-id (+ (var-get last-token-id) u1))
    (initial-state (if (is-some asset-addr) STATE_WAITING_FOR_OWNER STATE_NOT_ASSIGNED))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (not (var-get assets-restricted)) ERR_ASSET_RESTRICTED)
    (match asset-addr
      addr (begin
        (asserts! (is-none (map-get? asset-to-token addr)) ERR_INVALID_ASSET)
        (map-set asset-to-token addr token-id)
      )
      true
    )
    (map-set tokens token-id {
      owner: recipient,
      user: none,
      asset-address: asset-addr,
      state: initial-state,
      data-engagement: none,
      hash-k-oa: none,
      hash-k-ua: none,
      timestamp: stacks-block-time,
      timeout: u86400,
      uri: uri,
      created-at: stacks-block-time
    })
    (map-set owner-balance recipient (+ (balance-of recipient) u1))
    (var-set last-token-id token-id)
    (print { event: "Mint", token-id: token-id, recipient: recipient, timestamp: stacks-block-time })
    (ok token-id)
  )
)

(define-public (transfer (token-id uint) (recipient principal))
  (let ((token (unwrap! (map-get? tokens token-id) ERR_TOKEN_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner token)) ERR_NOT_AUTHORIZED)
    (map-set tokens token-id (merge token {
      owner: recipient,
      user: none,
      state: (if (is-some (get asset-address token)) STATE_WAITING_FOR_OWNER STATE_NOT_ASSIGNED),
      data-engagement: none,
      hash-k-oa: none,
      hash-k-ua: none,
      timestamp: stacks-block-time
    }))
    (map-set owner-balance (get owner token) (- (balance-of (get owner token)) u1))
    (map-set owner-balance recipient (+ (balance-of recipient) u1))
    (print { event: "Transfer", token-id: token-id, from: (get owner token), to: recipient, timestamp: stacks-block-time })
    (ok true)
  )
)

(define-public (set-user (token-id uint) (user-addr principal))
  (let ((token (unwrap! (map-get? tokens token-id) ERR_TOKEN_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner token)) ERR_NOT_AUTHORIZED)
    (asserts! (or 
      (is-eq (get state token) STATE_ENGAGED_WITH_OWNER)
      (is-eq (get state token) STATE_WAITING_FOR_USER)
      (is-eq (get state token) STATE_ENGAGED_WITH_USER)
      (is-eq (get state token) STATE_NOT_ASSIGNED)
    ) ERR_WRONG_STATE)
    (let ((new-state (if (is-some (get asset-address token)) STATE_WAITING_FOR_USER STATE_USER_ASSIGNED)))
      (map-set tokens token-id (merge token {
        user: (some user-addr),
        state: new-state,
        data-engagement: none,
        hash-k-ua: none
      }))
      (map-set user-balance user-addr (+ (user-balance-of user-addr) u1))
      (map-set user-owner-balance 
        { user: user-addr, owner: (get owner token) } 
        (+ (user-balance-of-owner user-addr (get owner token)) u1)
      )
      (emit-user-assigned token-id user-addr)
      (ok true)
    )
  )
)

(define-public (start-owner-engagement 
  (token-id uint)
  (engagement-data (buff 33))
  (hash-k (buff 32)))
  (let ((token (unwrap! (map-get? tokens token-id) ERR_TOKEN_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner token)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get state token) STATE_WAITING_FOR_OWNER) ERR_WRONG_STATE)
    (map-set tokens token-id (merge token {
      data-engagement: (some engagement-data),
      hash-k-oa: (some hash-k)
    }))
    (print { event: "OwnerEngagementStarted", token-id: token-id, timestamp: stacks-block-time })
    (ok true)
  )
)

(define-public (owner-engagement (token-id uint) (hash-k-a (buff 32)))
  (let ((token (unwrap! (map-get? tokens token-id) ERR_TOKEN_NOT_FOUND)))
    (asserts! (is-some (get asset-address token)) ERR_INVALID_ASSET)
    (asserts! (is-eq tx-sender (unwrap-panic (get asset-address token))) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get state token) STATE_WAITING_FOR_OWNER) ERR_WRONG_STATE)
    (asserts! (is-some (get data-engagement token)) ERR_NOT_ENGAGED)
    (asserts! (is-eq (some hash-k-a) (get hash-k-oa token)) ERR_INVALID_HASH)
    (map-set tokens token-id (merge token {
      state: STATE_ENGAGED_WITH_OWNER,
      data-engagement: none,
      timestamp: stacks-block-time
    }))
    (emit-owner-engaged token-id)
    (ok true)
  )
)

(define-public (start-user-engagement 
  (token-id uint)
  (engagement-data (buff 33))
  (hash-k (buff 32)))
  (let ((token (unwrap! (map-get? tokens token-id) ERR_TOKEN_NOT_FOUND)))
    (asserts! (is-some (get user token)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq tx-sender (unwrap-panic (get user token))) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get state token) STATE_WAITING_FOR_USER) ERR_WRONG_STATE)
    (map-set tokens token-id (merge token {
      data-engagement: (some engagement-data),
      hash-k-ua: (some hash-k)
    }))
    (print { event: "UserEngagementStarted", token-id: token-id, timestamp: stacks-block-time })
    (ok true)
  )
)

(define-public (user-engagement (token-id uint) (hash-k-a (buff 32)))
  (let ((token (unwrap! (map-get? tokens token-id) ERR_TOKEN_NOT_FOUND)))
    (asserts! (is-some (get asset-address token)) ERR_INVALID_ASSET)
    (asserts! (is-eq tx-sender (unwrap-panic (get asset-address token))) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get state token) STATE_WAITING_FOR_USER) ERR_WRONG_STATE)
    (asserts! (is-some (get data-engagement token)) ERR_NOT_ENGAGED)
    (asserts! (is-eq (some hash-k-a) (get hash-k-ua token)) ERR_INVALID_HASH)
    (map-set tokens token-id (merge token {
      state: STATE_ENGAGED_WITH_USER,
      data-engagement: none,
      timestamp: stacks-block-time
    }))
    (emit-user-engaged token-id)
    (ok true)
  )
)

(define-public (update-timestamp (token-id uint))
  (let ((token (unwrap! (map-get? tokens token-id) ERR_TOKEN_NOT_FOUND)))
    (asserts! (is-some (get asset-address token)) ERR_INVALID_ASSET)
    (asserts! (is-eq tx-sender (unwrap-panic (get asset-address token))) ERR_NOT_AUTHORIZED)
    (map-set tokens token-id (merge token { timestamp: stacks-block-time }))
    (ok true)
  )
)

(define-public (set-timeout (token-id uint) (new-timeout uint))
  (let ((token (unwrap! (map-get? tokens token-id) ERR_TOKEN_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner token)) ERR_NOT_AUTHORIZED)
    (asserts! (or 
      (is-eq (get state token) STATE_ENGAGED_WITH_OWNER)
      (is-eq (get state token) STATE_WAITING_FOR_USER)
      (is-eq (get state token) STATE_ENGAGED_WITH_USER)
    ) ERR_WRONG_STATE)
    (map-set tokens token-id (merge token { timeout: new-timeout }))
    (ok true)
  )
)

(define-public (check-timeout (token-id uint))
  (let ((token (unwrap! (map-get? tokens token-id) ERR_TOKEN_NOT_FOUND)))
    (if (> stacks-block-time (+ (get timestamp token) (get timeout token)))
      (begin
        (emit-timeout-alarm token-id)
        (ok true)
      )
      (ok false)
    )
  )
)

(define-public (unassign-user (token-id uint))
  (let ((token (unwrap! (map-get? tokens token-id) ERR_TOKEN_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner token)) ERR_NOT_AUTHORIZED)
    (match (get user token)
      usr (begin
        (map-set user-balance usr (- (user-balance-of usr) u1))
        (map-set user-owner-balance 
          { user: usr, owner: (get owner token) }
          (- (user-balance-of-owner usr (get owner token)) u1)
        )
      )
      true
    )
    (map-set tokens token-id (merge token {
      user: none,
      state: (if (is-some (get asset-address token)) STATE_ENGAGED_WITH_OWNER STATE_NOT_ASSIGNED),
      data-engagement: none,
      hash-k-ua: none
    }))
    (ok true)
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
