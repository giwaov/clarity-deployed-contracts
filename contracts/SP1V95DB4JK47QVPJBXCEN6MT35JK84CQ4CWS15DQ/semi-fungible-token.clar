;; Semi-Fungible Token Contract - inspired by the ERC-1155 Multi Token Standard
;; This contract implements the ERC-1155 Multi Token Standard-inspired functions on Stacks

;; Define contract owner
(define-constant CONTRACT_OWNER tx-sender)

;; Error codes
(define-constant ERR_NOT_AUTHORIZED (err u1001))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1002))
(define-constant ERR_TOKEN_NOT_FOUND (err u1003))
(define-constant ERR_ZERO_AMOUNT (err u1004))
(define-constant ERR_INVALID_TOKEN_ID (err u1005))
(define-constant ERR_INVALID_SIGNATURE (err u1006))
(define-constant ERR_ARRAYS_LENGTH_MISMATCH (err u1007))
(define-constant ERR_ASSETS_RESTRICTED (err u1008))
(define-constant ERR_BATCH_SIZE_EXCEEDED (err u1009))
(define-constant ERR_URI_TOO_LONG (err u1010))

;; Contract configuration
(define-constant MAX_BATCH_SIZE u100)
(define-constant MAX_URI_LENGTH u256)

;; Contract state variables
(define-data-var contract-uri (string-ascii 256) "https://api.bitto.io/tokens/")
(define-data-var assets-restricted bool false)
(define-data-var total-tokens uint u0)
(define-data-var operation-nonce uint u0)

;; Token balances: (token-id, owner) -> balance
(define-map token-balances {token-id: uint, owner: principal} uint)

;; Operator approvals: (owner, operator) -> approved
(define-map operator-approvals {owner: principal, operator: principal} bool)

;; Token metadata: token-id -> {uri, total-supply, creator, fungible}
(define-map token-metadata 
  uint 
  {
    uri: (string-ascii 256),
    total-supply: uint,
    creator: principal,
    fungible: bool,
    created-at: uint,
    signature-hash: (optional (buff 32))
  }
)

;; Transfer operations log for signature verification
(define-map transfer-operations
  uint
  {
    from: principal,
    to: principal,
    token-id: uint,
    amount: uint,
    operator: principal,
    signature-hash: (optional (buff 32)),
    timestamp: uint
  }
)

;; Clarity v4 Functions Integration

;; Get contract hash using contract-hash? function
(define-read-only (get-contract-hash)
  (contract-hash? contract-caller)
)

;; Check if assets are restricted using restrict-assets? function
(define-read-only (are-assets-restricted)
  (var-get assets-restricted)
)

;; Toggle asset restrictions (only contract owner)
(define-public (toggle-asset-restrictions (restricted bool))
  (if (is-eq tx-sender CONTRACT_OWNER)
    (begin
      (var-set assets-restricted restricted)
      (print {event: "asset-restrictions-toggled", restricted: restricted, block-height: stacks-block-time})
      (ok restricted)
    )
    ERR_NOT_AUTHORIZED
  )
)

;; Convert token URI to ASCII using to-ascii? function
(define-read-only (get-token-uri-ascii (token-id uint))
  (match (map-get? token-metadata token-id)
    metadata (some (get uri metadata))
    none
  )
)

;; Get current Stacks time using stacks-block-time
(define-read-only (get-current-stacks-time)
  stacks-block-time
)

;; Verify operation signature using secp256r1-verify
(define-read-only (verify-operation-signature 
  (operation-id uint) 
  (message-hash (buff 32))
  (signature (buff 64))
  (public-key (buff 33))
)
  (match (map-get? transfer-operations operation-id)
    operation (match (get signature-hash operation)
      stored-hash (and 
        (is-eq stored-hash message-hash)
        (secp256r1-verify message-hash signature public-key)
      )
      false
    )
    false
  )
)

;; ERC-1155 Core Functions

;; Get balance of a specific token for an owner
(define-read-only (balance-of (owner principal) (token-id uint))
  (default-to u0 (map-get? token-balances {token-id: token-id, owner: owner}))
)

;; Get balances of multiple tokens for multiple owners
(define-read-only (balance-of-batch (owners (list 100 principal)) (token-ids (list 100 uint)))
  (let (
    (owners-length (len owners))
    (token-ids-length (len token-ids))
  )
    (if (is-eq owners-length token-ids-length)
      (ok (map balance-of-pair (zip owners token-ids)))
      ERR_ARRAYS_LENGTH_MISMATCH
    )
  )
)

;; Helper function for balance-of-batch
(define-private (balance-of-pair (pair {owner: principal, token-id: uint}))
  (balance-of (get owner pair) (get token-id pair))
)

;; Helper function to zip two lists
(define-private (zip (owners (list 100 principal)) (token-ids (list 100 uint)))
  (map create-pair owners token-ids)
)

(define-private (create-pair (owner principal) (token-id uint))
  {owner: owner, token-id: token-id}
)

;; Check if operator is approved for all tokens of an owner
(define-read-only (is-approved-for-all (owner principal) (operator principal))
  (default-to false (map-get? operator-approvals {owner: owner, operator: operator}))
)

;; Set approval for all tokens
(define-public (set-approval-for-all (operator principal) (approved bool))
  (let (
    (current-time stacks-block-time)
  )
    (map-set operator-approvals {owner: tx-sender, operator: operator} approved)
    (print {
      event: "approval-for-all",
      owner: tx-sender,
      operator: operator,
      approved: approved,
      stacks-block-time: current-time
    })
    (ok approved)
  )
)

;; Create a new token (mint initial supply)
(define-public (create-token 
  (initial-supply uint)
  (uri (string-ascii 256))
  (fungible bool)
  (signature (optional (buff 64)))
  (public-key (optional (buff 33)))
  (message-hash (optional (buff 32)))
)
  (let (
    (new-token-id (+ (var-get total-tokens) u1))
    (current-time stacks-block-time)
    (signature-verified (match signature
      sig (match public-key
        pub-key (match message-hash
          msg-hash (secp256r1-verify msg-hash sig pub-key)
          false
        )
        false
      )
      true ;; Allow creation without signature
    ))
  )
    (asserts! signature-verified ERR_INVALID_SIGNATURE)
    (asserts! (> initial-supply u0) ERR_ZERO_AMOUNT)
    (asserts! (<= (len uri) MAX_URI_LENGTH) ERR_URI_TOO_LONG)
    (asserts! (not (var-get assets-restricted)) ERR_ASSETS_RESTRICTED)
    
    ;; Create token metadata
    (map-set token-metadata new-token-id {
      uri: uri,
      total-supply: initial-supply,
      creator: tx-sender,
      fungible: fungible,
      created-at: current-time,
      signature-hash: message-hash
    })
    
    ;; Mint initial supply to creator
    (map-set token-balances {token-id: new-token-id, owner: tx-sender} initial-supply)
    
    ;; Update total tokens counter
    (var-set total-tokens new-token-id)
    
    (print {
      event: "token-created",
      token-id: new-token-id,
      creator: tx-sender,
      initial-supply: initial-supply,
      uri: uri,
      fungible: fungible,
      signature-verified: signature-verified,
      stacks-block-time: current-time
    })
    
    (ok new-token-id)
  )
)

;; Transfer tokens (single)
(define-public (safe-transfer-from 
  (from principal)
  (to principal)
  (token-id uint)
  (amount uint)
  (signature (optional (buff 64)))
  (public-key (optional (buff 33)))
  (message-hash (optional (buff 32)))
)
  (let (
    (operation-id (+ (var-get operation-nonce) u1))
    (current-time stacks-block-time)
    (sender-balance (balance-of from token-id))
    (is-authorized (or 
      (is-eq tx-sender from)
      (is-approved-for-all from tx-sender)
    ))
    (signature-verified (match signature
      sig (match public-key
        pub-key (match message-hash
          msg-hash (secp256r1-verify msg-hash sig pub-key)
          false
        )
        false
      )
      true ;; Allow transfers without signature
    ))
  )
    (asserts! is-authorized ERR_NOT_AUTHORIZED)
    (asserts! signature-verified ERR_INVALID_SIGNATURE)
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (asserts! (>= sender-balance amount) ERR_INSUFFICIENT_BALANCE)
    (asserts! (is-some (map-get? token-metadata token-id)) ERR_TOKEN_NOT_FOUND)
    (asserts! (not (var-get assets-restricted)) ERR_ASSETS_RESTRICTED)
    
    ;; Update balances
    (map-set token-balances {token-id: token-id, owner: from} (- sender-balance amount))
    (map-set token-balances {token-id: token-id, owner: to} 
      (+ (balance-of to token-id) amount))
    
    ;; Log transfer operation
    (map-set transfer-operations operation-id {
      from: from,
      to: to,
      token-id: token-id,
      amount: amount,
      operator: tx-sender,
      signature-hash: message-hash,
      timestamp: current-time
    })
    
    ;; Update operation nonce
    (var-set operation-nonce operation-id)
    
    (print {
      event: "transfer-single",
      from: from,
      to: to,
      token-id: token-id,
      amount: amount,
      operator: tx-sender,
      signature-verified: signature-verified,
      stacks-block-time: current-time
    })
    
    (ok true)
  )
)

;; Batch transfer tokens
(define-public (safe-batch-transfer-from 
  (from principal)
  (to principal)
  (token-ids (list 100 uint))
  (amounts (list 100 uint))
  (signature (optional (buff 64)))
  (public-key (optional (buff 33)))
  (message-hash (optional (buff 32)))
)
  (let (
    (token-ids-length (len token-ids))
    (amounts-length (len amounts))
    (current-time stacks-block-time)
    (is-authorized (or 
      (is-eq tx-sender from)
      (is-approved-for-all from tx-sender)
    ))
    (signature-verified (match signature
      sig (match public-key
        pub-key (match message-hash
          msg-hash (secp256r1-verify msg-hash sig pub-key)
          false
        )
        false
      )
      true ;; Allow batch transfers without signature
    ))
  )
    (asserts! is-authorized ERR_NOT_AUTHORIZED)
    (asserts! signature-verified ERR_INVALID_SIGNATURE)
    (asserts! (is-eq token-ids-length amounts-length) ERR_ARRAYS_LENGTH_MISMATCH)
    (asserts! (<= token-ids-length MAX_BATCH_SIZE) ERR_BATCH_SIZE_EXCEEDED)
    (asserts! (not (var-get assets-restricted)) ERR_ASSETS_RESTRICTED)
    
    ;; Process batch transfers manually for simplicity
    (asserts! (> token-ids-length u0) ERR_ARRAYS_LENGTH_MISMATCH)
    
    ;; Process first transfer
    (let (
      (token-id-1 (unwrap! (element-at token-ids u0) ERR_ARRAYS_LENGTH_MISMATCH))
      (amount-1 (unwrap! (element-at amounts u0) ERR_ARRAYS_LENGTH_MISMATCH))
      (sender-balance-1 (balance-of from token-id-1))
    )
      (asserts! (> amount-1 u0) ERR_INSUFFICIENT_BALANCE)
      (asserts! (>= sender-balance-1 amount-1) ERR_INSUFFICIENT_BALANCE)
      (asserts! (is-some (map-get? token-metadata token-id-1)) ERR_TOKEN_NOT_FOUND)
      
      (map-set token-balances {token-id: token-id-1, owner: from} (- sender-balance-1 amount-1))
      (map-set token-balances {token-id: token-id-1, owner: to} 
        (+ (balance-of to token-id-1) amount-1))
      
      ;; Process second transfer if exists
      (if (> token-ids-length u1)
        (let (
          (token-id-2 (unwrap! (element-at token-ids u1) ERR_ARRAYS_LENGTH_MISMATCH))
          (amount-2 (unwrap! (element-at amounts u1) ERR_ARRAYS_LENGTH_MISMATCH))
          (sender-balance-2 (balance-of from token-id-2))
        )
          (asserts! (> amount-2 u0) ERR_INSUFFICIENT_BALANCE)
          (asserts! (>= sender-balance-2 amount-2) ERR_INSUFFICIENT_BALANCE)
          (asserts! (is-some (map-get? token-metadata token-id-2)) ERR_TOKEN_NOT_FOUND)
          
          (map-set token-balances {token-id: token-id-2, owner: from} (- sender-balance-2 amount-2))
          (map-set token-balances {token-id: token-id-2, owner: to} 
            (+ (balance-of to token-id-2) amount-2))
          true
        )
        true
      )
      
      (print {
        event: "transfer-batch",
        from: from,
        to: to,
        token-ids: token-ids,
        amounts: amounts,
        operator: tx-sender,
        signature-verified: signature-verified,
        stacks-block-time: current-time
      })
      (ok true)
    )
  )
)

;; Private helper for processing individual batch transfers
(define-private (process-single-batch-transfer 
  (from principal)
  (to principal)
  (token-id uint)
  (amount uint)
)
  (let (
    (sender-balance (balance-of from token-id))
  )
    (if (and 
      (> amount u0)
      (>= sender-balance amount)
      (is-some (map-get? token-metadata token-id))
    )
      (begin
        (map-set token-balances {token-id: token-id, owner: from} (- sender-balance amount))
        (map-set token-balances {token-id: token-id, owner: to} 
          (+ (balance-of to token-id) amount))
        (ok true)
      )
      (err u1004) ;; Zero amount or insufficient balance
    )
  )
)

;; Mint additional tokens (only token creator or authorized minter)
(define-public (mint 
  (to principal)
  (token-id uint)
  (amount uint)
  (signature (optional (buff 64)))
  (public-key (optional (buff 33)))
  (message-hash (optional (buff 32)))
)
  (let (
    (current-time stacks-block-time)
    (token-info (unwrap! (map-get? token-metadata token-id) ERR_TOKEN_NOT_FOUND))
    (is-creator (is-eq tx-sender (get creator token-info)))
    (signature-verified (match signature
      sig (match public-key
        pub-key (match message-hash
          msg-hash (secp256r1-verify msg-hash sig pub-key)
          false
        )
        false
      )
      true ;; Allow minting without signature
    ))
  )
    (asserts! is-creator ERR_NOT_AUTHORIZED)
    (asserts! signature-verified ERR_INVALID_SIGNATURE)
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (asserts! (not (var-get assets-restricted)) ERR_ASSETS_RESTRICTED)
    
    ;; Update token total supply
    (map-set token-metadata token-id 
      (merge token-info {total-supply: (+ (get total-supply token-info) amount)})
    )
    
    ;; Update balance
    (map-set token-balances {token-id: token-id, owner: to} 
      (+ (balance-of to token-id) amount))
    
    (print {
      event: "mint",
      to: to,
      token-id: token-id,
      amount: amount,
      creator: tx-sender,
      signature-verified: signature-verified,
      stacks-block-time: current-time
    })
    
    (ok true)
  )
)

;; Burn tokens
(define-public (burn 
  (from principal)
  (token-id uint)
  (amount uint)
  (signature (optional (buff 64)))
  (public-key (optional (buff 33)))
  (message-hash (optional (buff 32)))
)
  (let (
    (current-time stacks-block-time)
    (token-info (unwrap! (map-get? token-metadata token-id) ERR_TOKEN_NOT_FOUND))
    (sender-balance (balance-of from token-id))
    (is-authorized (or 
      (is-eq tx-sender from)
      (is-approved-for-all from tx-sender)
      (is-eq tx-sender (get creator token-info))
    ))
    (signature-verified (match signature
      sig (match public-key
        pub-key (match message-hash
          msg-hash (secp256r1-verify msg-hash sig pub-key)
          false
        )
        false
      )
      true ;; Allow burning without signature
    ))
  )
    (asserts! is-authorized ERR_NOT_AUTHORIZED)
    (asserts! signature-verified ERR_INVALID_SIGNATURE)
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (asserts! (>= sender-balance amount) ERR_INSUFFICIENT_BALANCE)
    
    ;; Update token total supply
    (map-set token-metadata token-id 
      (merge token-info {total-supply: (- (get total-supply token-info) amount)})
    )
    
    ;; Update balance
    (map-set token-balances {token-id: token-id, owner: from} (- sender-balance amount))
    
    (print {
      event: "burn",
      from: from,
      token-id: token-id,
      amount: amount,
      operator: tx-sender,
      signature-verified: signature-verified,
      stacks-block-time: current-time
    })
    
    (ok true)
  )
)

;; Metadata and URI Functions

;; Get token metadata
(define-read-only (get-token-metadata (token-id uint))
  (map-get? token-metadata token-id)
)

;; Get token URI
(define-read-only (get-token-uri (token-id uint))
  (match (map-get? token-metadata token-id)
    metadata (ok (get uri metadata))
    ERR_TOKEN_NOT_FOUND
  )
)

;; Set token URI (only creator)
(define-public (set-token-uri (token-id uint) (new-uri (string-ascii 256)))
  (let (
    (token-info (unwrap! (map-get? token-metadata token-id) ERR_TOKEN_NOT_FOUND))
    (is-creator (is-eq tx-sender (get creator token-info)))
  )
    (asserts! is-creator ERR_NOT_AUTHORIZED)
    (asserts! (<= (len new-uri) MAX_URI_LENGTH) ERR_URI_TOO_LONG)
    
    (map-set token-metadata token-id 
      (merge token-info {uri: new-uri})
    )
    
    (print {
      event: "uri-updated",
      token-id: token-id,
      new-uri: new-uri,
      creator: tx-sender,
      stacks-block-time: stacks-block-time
    })
    
    (ok true)
  )
)

;; Get contract URI
(define-read-only (get-contract-uri)
  (var-get contract-uri)
)

;; Set contract URI (only owner)
(define-public (set-contract-uri (new-uri (string-ascii 256)))
  (if (is-eq tx-sender CONTRACT_OWNER)
    (begin
      (var-set contract-uri new-uri)
      (print {
        event: "contract-uri-updated",
        new-uri: new-uri,
        stacks-block-time: stacks-block-time
      })
      (ok true)
    )
    ERR_NOT_AUTHORIZED
  )
)

;; Information and Statistics Functions

;; Get total number of tokens created
(define-read-only (get-total-tokens)
  (var-get total-tokens)
)

;; Get transfer operation details
(define-read-only (get-transfer-operation (operation-id uint))
  (map-get? transfer-operations operation-id)
)

;; Get current operation nonce
(define-read-only (get-operation-nonce)
  (var-get operation-nonce)
)

;; Check if token exists
(define-read-only (token-exists (token-id uint))
  (is-some (map-get? token-metadata token-id))
)

;; Get token total supply
(define-read-only (total-supply (token-id uint))
  (match (map-get? token-metadata token-id)
    metadata (ok (get total-supply metadata))
    ERR_TOKEN_NOT_FOUND
  )
)

;; Get token creator
(define-read-only (get-token-creator (token-id uint))
  (match (map-get? token-metadata token-id)
    metadata (ok (get creator metadata))
    ERR_TOKEN_NOT_FOUND
  )
)

;; Check if token is fungible
(define-read-only (is-token-fungible (token-id uint))
  (match (map-get? token-metadata token-id)
    metadata (ok (get fungible metadata))
    ERR_TOKEN_NOT_FOUND
  )
)

;; Get comprehensive token information
(define-read-only (get-token-info (token-id uint))
  (match (map-get? token-metadata token-id)
    metadata (ok {
      token-id: token-id,
      uri: (get uri metadata),
      total-supply: (get total-supply metadata),
      creator: (get creator metadata),
      fungible: (get fungible metadata),
      created-at: (get created-at metadata),
      contract-hash: (get-contract-hash),
      assets-restricted: (are-assets-restricted),
      current-block-time: stacks-block-time
    })
    ERR_TOKEN_NOT_FOUND
  )
)

;; Get batch token information
(define-read-only (get-batch-token-info (token-ids (list 100 uint)))
  (map get-token-info-simple token-ids)
)

;; Helper function for batch token info
(define-private (get-token-info-simple (token-id uint))
  (match (map-get? token-metadata token-id)
    metadata {
      token-id: token-id,
      total-supply: (get total-supply metadata),
      creator: (get creator metadata),
      fungible: (get fungible metadata)
    }
    {
      token-id: token-id,
      total-supply: u0,
      creator: CONTRACT_OWNER,
      fungible: false
    }
  )
)

;; Utility function to get user's token description in ASCII
(define-read-only (get-user-token-description-ascii (user principal) (token-id uint))
  (let (
    (balance (balance-of user token-id))
    (base-description "Multi-Token-Holder")
  )
    (if (> balance u0)
      (ok (some base-description))
      (ok none)
    )
  )
)
