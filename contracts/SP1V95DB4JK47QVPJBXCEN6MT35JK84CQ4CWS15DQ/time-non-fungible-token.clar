(define-constant CONTRACT_OWNER tx-sender)

(define-constant ERR_NOT_AUTHORIZED (err u1001))
(define-constant ERR_TOKEN_NOT_FOUND (err u1002))
(define-constant ERR_TOKEN_EXISTS (err u1003))
(define-constant ERR_INVALID_TIME (err u1004))
(define-constant ERR_TOKEN_EXPIRED (err u1005))
(define-constant ERR_NOT_YET_VALID (err u1006))
(define-constant ERR_MERGE_FAILED (err u1007))
(define-constant ERR_SPLIT_FAILED (err u1008))
(define-constant ERR_ASSET_RESTRICTED (err u1009))
(define-constant ERR_INVALID_SIGNATURE (err u1010))
(define-constant ERR_DIFFERENT_ASSETS (err u1011))

(define-data-var last-token-id uint u0)
(define-data-var last-asset-id uint u0)
(define-data-var assets-restricted bool false)

(define-map tokens
  uint
  {
    owner: principal,
    asset-id: uint,
    start-time: uint,
    end-time: uint,
    uri: (string-ascii 256),
    created-at: uint
  }
)

(define-map owner-balance principal uint)

(define-map token-approvals uint principal)

(define-map operator-approvals
  { owner: principal, operator: principal }
  bool
)

(define-private (emit-transfer (token-id uint) (from principal) (to principal))
  (print { event: "Transfer", token-id: token-id, from: from, to: to, timestamp: stacks-block-time })
)

(define-private (emit-time-update (token-id uint) (start-time uint) (end-time uint))
  (print { event: "TimeUpdated", token-id: token-id, start-time: start-time, end-time: end-time, timestamp: stacks-block-time })
)

(define-read-only (get-token (token-id uint))
  (map-get? tokens token-id)
)

(define-read-only (owner-of (token-id uint))
  (match (map-get? tokens token-id) token (some (get owner token)) none)
)

(define-read-only (balance-of (owner principal))
  (default-to u0 (map-get? owner-balance owner))
)

(define-read-only (get-start-time (token-id uint))
  (match (map-get? tokens token-id) token (some (get start-time token)) none)
)

(define-read-only (get-end-time (token-id uint))
  (match (map-get? tokens token-id) token (some (get end-time token)) none)
)

(define-read-only (asset-id (token-id uint))
  (match (map-get? tokens token-id) token (some (get asset-id token)) none)
)

(define-read-only (is-valid-now (token-id uint))
  (match (map-get? tokens token-id)
    token (and 
      (<= (get start-time token) stacks-block-time)
      (>= (get end-time token) stacks-block-time)
    )
    false
  )
)

(define-read-only (get-approved (token-id uint))
  (map-get? token-approvals token-id)
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

(define-read-only (verify-time-signature 
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

(define-read-only (time-remaining (token-id uint))
  (match (map-get? tokens token-id)
    token 
    (if (> (get end-time token) stacks-block-time)
      (some (- (get end-time token) stacks-block-time))
      (some u0)
    )
    none
  )
)

(define-private (is-authorized (token-id uint) (spender principal))
  (match (map-get? tokens token-id)
    token
    (or 
      (is-eq spender (get owner token))
      (is-eq (some spender) (map-get? token-approvals token-id))
      (is-approved-for-all (get owner token) spender)
    )
    false
  )
)

(define-public (mint 
  (recipient principal)
  (start uint)
  (end uint)
  (uri (string-ascii 256)))
  (let (
    (token-id (+ (var-get last-token-id) u1))
    (new-asset-id (+ (var-get last-asset-id) u1))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (not (var-get assets-restricted)) ERR_ASSET_RESTRICTED)
    (asserts! (< start end) ERR_INVALID_TIME)
    (map-set tokens token-id {
      owner: recipient,
      asset-id: new-asset-id,
      start-time: start,
      end-time: end,
      uri: uri,
      created-at: stacks-block-time
    })
    (map-set owner-balance recipient (+ (balance-of recipient) u1))
    (var-set last-token-id token-id)
    (var-set last-asset-id new-asset-id)
    (print { event: "Mint", token-id: token-id, recipient: recipient, start-time: start, end-time: end, timestamp: stacks-block-time })
    (ok token-id)
  )
)

(define-public (mint-with-asset-id
  (recipient principal)
  (existing-asset-id uint)
  (start uint)
  (end uint)
  (uri (string-ascii 256)))
  (let ((token-id (+ (var-get last-token-id) u1)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (not (var-get assets-restricted)) ERR_ASSET_RESTRICTED)
    (asserts! (< start end) ERR_INVALID_TIME)
    (map-set tokens token-id {
      owner: recipient,
      asset-id: existing-asset-id,
      start-time: start,
      end-time: end,
      uri: uri,
      created-at: stacks-block-time
    })
    (map-set owner-balance recipient (+ (balance-of recipient) u1))
    (var-set last-token-id token-id)
    (print { event: "Mint", token-id: token-id, recipient: recipient, asset-id: existing-asset-id, start-time: start, end-time: end, timestamp: stacks-block-time })
    (ok token-id)
  )
)

(define-public (transfer (token-id uint) (to principal))
  (let ((token (unwrap! (map-get? tokens token-id) ERR_TOKEN_NOT_FOUND)))
    (asserts! (is-authorized token-id tx-sender) ERR_NOT_AUTHORIZED)
    (map-set tokens token-id (merge token { owner: to }))
    (map-set owner-balance (get owner token) (- (balance-of (get owner token)) u1))
    (map-set owner-balance to (+ (balance-of to) u1))
    (map-delete token-approvals token-id)
    (emit-transfer token-id (get owner token) to)
    (ok true)
  )
)

(define-public (approve (token-id uint) (spender principal))
  (let ((token (unwrap! (map-get? tokens token-id) ERR_TOKEN_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner token)) ERR_NOT_AUTHORIZED)
    (map-set token-approvals token-id spender)
    (print { event: "Approval", token-id: token-id, owner: tx-sender, spender: spender, timestamp: stacks-block-time })
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

(define-public (split
  (old-token-id uint)
  (new-token1-id uint)
  (new-token1-owner principal)
  (new-token2-id uint)
  (new-token2-owner principal)
  (split-time uint))
  (let ((old-token (unwrap! (map-get? tokens old-token-id) ERR_TOKEN_NOT_FOUND)))
    (asserts! (is-authorized old-token-id tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (is-none (map-get? tokens new-token1-id)) ERR_TOKEN_EXISTS)
    (asserts! (is-none (map-get? tokens new-token2-id)) ERR_TOKEN_EXISTS)
    (asserts! (and 
      (<= (get start-time old-token) split-time)
      (< split-time (get end-time old-token))
    ) ERR_INVALID_TIME)
    (map-set tokens new-token1-id {
      owner: new-token1-owner,
      asset-id: (get asset-id old-token),
      start-time: (get start-time old-token),
      end-time: split-time,
      uri: (get uri old-token),
      created-at: stacks-block-time
    })
    (map-set tokens new-token2-id {
      owner: new-token2-owner,
      asset-id: (get asset-id old-token),
      start-time: (+ split-time u1),
      end-time: (get end-time old-token),
      uri: (get uri old-token),
      created-at: stacks-block-time
    })
    (map-set owner-balance (get owner old-token) (- (balance-of (get owner old-token)) u1))
    (map-set owner-balance new-token1-owner (+ (balance-of new-token1-owner) u1))
    (map-set owner-balance new-token2-owner (+ (balance-of new-token2-owner) u1))
    (map-delete tokens old-token-id)
    (map-delete token-approvals old-token-id)
    (var-set last-token-id (if (> new-token2-id (var-get last-token-id)) new-token2-id (var-get last-token-id)))
    (print { event: "Split", old-token-id: old-token-id, new-token1-id: new-token1-id, new-token2-id: new-token2-id, split-time: split-time, timestamp: stacks-block-time })
    (ok true)
  )
)

(define-public (merge-tokens
  (first-token-id uint)
  (second-token-id uint)
  (new-token-owner principal)
  (new-token-id uint))
  (let (
    (first-token (unwrap! (map-get? tokens first-token-id) ERR_TOKEN_NOT_FOUND))
    (second-token (unwrap! (map-get? tokens second-token-id) ERR_TOKEN_NOT_FOUND))
  )
    (asserts! (is-authorized first-token-id tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (is-authorized second-token-id tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (is-none (map-get? tokens new-token-id)) ERR_TOKEN_EXISTS)
    (asserts! (is-eq (get asset-id first-token) (get asset-id second-token)) ERR_DIFFERENT_ASSETS)
    (asserts! (is-eq (+ (get end-time first-token) u1) (get start-time second-token)) ERR_MERGE_FAILED)
    (map-set tokens new-token-id {
      owner: new-token-owner,
      asset-id: (get asset-id first-token),
      start-time: (get start-time first-token),
      end-time: (get end-time second-token),
      uri: (get uri first-token),
      created-at: stacks-block-time
    })
    (map-set owner-balance (get owner first-token) (- (balance-of (get owner first-token)) u1))
    (map-set owner-balance (get owner second-token) (- (balance-of (get owner second-token)) u1))
    (map-set owner-balance new-token-owner (+ (balance-of new-token-owner) u1))
    (map-delete tokens first-token-id)
    (map-delete tokens second-token-id)
    (map-delete token-approvals first-token-id)
    (map-delete token-approvals second-token-id)
    (var-set last-token-id (if (> new-token-id (var-get last-token-id)) new-token-id (var-get last-token-id)))
    (print { event: "Merge", first-token-id: first-token-id, second-token-id: second-token-id, new-token-id: new-token-id, timestamp: stacks-block-time })
    (ok true)
  )
)

(define-public (burn (token-id uint))
  (let ((token (unwrap! (map-get? tokens token-id) ERR_TOKEN_NOT_FOUND)))
    (asserts! (is-authorized token-id tx-sender) ERR_NOT_AUTHORIZED)
    (map-set owner-balance (get owner token) (- (balance-of (get owner token)) u1))
    (map-delete tokens token-id)
    (map-delete token-approvals token-id)
    (print { event: "Burn", token-id: token-id, timestamp: stacks-block-time })
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

(define-read-only (get-last-asset-id)
  (var-get last-asset-id)
)

(define-read-only (supports-interface (interface-id (buff 4)))
  (or 
    (is-eq interface-id 0xf140be0d)
    (is-eq interface-id 0x75cf3842)
    (is-eq interface-id 0x80ac58cd)
    (is-eq interface-id 0x01ffc9a7)
  )
)
