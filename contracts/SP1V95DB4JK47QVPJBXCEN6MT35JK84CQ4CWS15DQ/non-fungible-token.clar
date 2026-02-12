;; Non-Fungible Token Contract with ERC-721 Standard and Clarity v4 Features
;; This contract implements the ERC-721 Non-Fungible Token Standard with tokenized vault functionality

;; ============================================================================
;; Constants and Errors
;; ============================================================================

(define-constant CONTRACT_OWNER tx-sender)
(define-constant TOKEN_NAME "Bitto NFT")
(define-constant TOKEN_SYMBOL "BNFT")

;; Error constants
(define-constant ERR_NOT_AUTHORIZED (err u1001))
(define-constant ERR_NOT_APPROVED (err u1002))
(define-constant ERR_TOKEN_NOT_FOUND (err u1003))
(define-constant ERR_TOKEN_ALREADY_EXISTS (err u1004))
(define-constant ERR_INVALID_RECIPIENT (err u1005))
(define-constant ERR_INVALID_SIGNATURE (err u1006))
(define-constant ERR_URI_TOO_LONG (err u1007))
(define-constant ERR_ASSETS_RESTRICTED (err u1008))
(define-constant ERR_INVALID_VAULT (err u1009))
(define-constant ERR_INSUFFICIENT_SHARES (err u1010))

;; Configuration constants
(define-constant MAX_URI_LENGTH u256)

;; ============================================================================
;; Data Variables
;; ============================================================================

(define-data-var base-contract-uri (string-ascii 256) "https://api.bitto.io/nft/")
(define-data-var token-supply uint u0)
(define-data-var operation-nonce uint u0)
(define-data-var assets-restricted bool false)

;; ============================================================================
;; Data Maps
;; ============================================================================

;; Token ownership (ERC-721 standard)
(define-map token-owners uint principal)

;; Token approvals (ERC-721 standard)
(define-map token-approvals uint principal)

;; Operator approvals (ERC-721 standard)
(define-map operator-approvals {owner: principal, operator: principal} bool)

;; Token metadata
(define-map token-metadata uint {
    uri: (string-ascii 256),
    name: (string-ascii 64),
    description: (string-ascii 256),
    creator: principal,
    created-at: uint,
    signature-hash: (optional (buff 32)),
    attributes: (optional (string-ascii 512))
})

;; Tokenized vault storage
(define-map vault-deposits principal uint)
(define-map vault-shares principal uint)
(define-map vault-permissions {vault: uint, user: principal} bool)

;; Operation tracking
(define-map transfer-operations uint {
  from: principal,
  to: principal,
  token-id: uint,
  block-height: uint,
  timestamp: uint
})

;; ============================================================================
;; Clarity v4 Functions Integration
;; ============================================================================

;; Get contract hash using contract-hash? function
(define-read-only (get-contract-hash)
  (contract-hash? tx-sender)
)

;; Check if assets are restricted using restrict-assets? function
(define-read-only (are-assets-restricted)
  (var-get assets-restricted)
)

;; Get current Stacks block time
(define-read-only (get-current-stacks-time)
  stacks-block-time
)

;; ============================================================================
;; Basic Read-Only Functions (no circular dependencies)
;; ============================================================================

;; Get token name
(define-read-only (get-name)
  TOKEN_NAME
)

;; Get token symbol
(define-read-only (get-symbol)
  TOKEN_SYMBOL
)

;; Get contract URI
(define-read-only (contract-uri)
  (var-get base-contract-uri)
)

;; Get total supply
(define-read-only (total-supply)
  (var-get token-supply)
)

;; Get owner of a specific token (ERC-721 ownerOf)
(define-read-only (owner-of (token-id uint))
  (match (map-get? token-owners token-id)
    owner (ok owner)
    ERR_TOKEN_NOT_FOUND
  )
)

;; Get approved principal for a specific token (ERC-721 getApproved)
(define-read-only (get-approved (token-id uint))
  (if (is-some (map-get? token-owners token-id))
    (ok (map-get? token-approvals token-id))
    ERR_TOKEN_NOT_FOUND
  )
)

;; Check if operator is approved for all tokens of owner (ERC-721 isApprovedForAll)
(define-read-only (is-approved-for-all (owner principal) (operator principal))
  (default-to false (map-get? operator-approvals {owner: owner, operator: operator}))
)

;; Get token URI
(define-read-only (token-uri (token-id uint))
  (match (map-get? token-metadata token-id)
    metadata (ok (get uri metadata))
    ERR_TOKEN_NOT_FOUND
  )
)

;; Get token metadata
(define-read-only (get-token-metadata (token-id uint))
  (map-get? token-metadata token-id)
)

;; Helper function to count tokens owned by a specific owner
(define-private (count-owner-tokens (token-id uint) (data {owner: principal, count: uint}))
  (if (<= token-id u100)
    (if (is-eq (get owner data) (default-to CONTRACT_OWNER (map-get? token-owners token-id)))
      {owner: (get owner data), count: (+ (get count data) u1)}
      data
    )
    data
  )
)

;; Get balance of NFTs owned by a principal (ERC-721 balanceOf)
(define-read-only (balance-of (owner principal))
  (get count (fold count-owner-tokens (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20 u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34 u35 u36 u37 u38 u39 u40 u41 u42 u43 u44 u45 u46 u47 u48 u49 u50 u51 u52 u53 u54 u55 u56 u57 u58 u59 u60 u61 u62 u63 u64 u65 u66 u67 u68 u69 u70 u71 u72 u73 u74 u75 u76 u77 u78 u79 u80 u81 u82 u83 u84 u85 u86 u87 u88 u89 u90 u91 u92 u93 u94 u95 u96 u97 u98 u99 u100) {owner: owner, count: u0}))
)

;; Check if token exists
(define-read-only (token-exists (token-id uint))
  (is-some (map-get? token-owners token-id))
)

;; Get current operation nonce
(define-read-only (get-operation-nonce)
  (var-get operation-nonce)
)

;; Get transfer operation details
(define-read-only (get-transfer-operation (operation-id uint))
  (map-get? transfer-operations operation-id)
)

;; Get vault info for a user
(define-read-only (get-vault-info (vault-id uint) (user principal))
  (ok {
    vault-owner: CONTRACT_OWNER,
    user-deposits: (default-to u0 (map-get? vault-deposits user)),
    user-shares: (default-to u0 (map-get? vault-shares user)),
    has-permissions: (default-to false (map-get? vault-permissions {vault: vault-id, user: user})),
    current-time: stacks-block-time
  })
)

;; Get token URI as ASCII string
(define-read-only (get-token-uri-ascii (token-id uint))
  (match (map-get? token-metadata token-id)
    metadata (some (get uri metadata))
    none
  )
)

;; Get token name as ASCII string
(define-read-only (get-token-name-ascii (token-id uint))
  (match (map-get? token-metadata token-id)
    metadata (some (get name metadata))
    none
  )
)

;; ERC-165 style interface support check
(define-read-only (supports-interface (interface-id (buff 4)))
  (or
    (is-eq interface-id 0x80ac58cd) ;; ERC-721 interface ID
    (is-eq interface-id 0x01ffc9a7) ;; ERC-165 interface ID
    (is-eq interface-id 0x5b5e139f) ;; ERC-721 Metadata interface ID
  )
)

;; Get tokens owned by a user
(define-read-only (tokens-of-owner (owner principal))
  (let (
    (total (var-get token-supply))
  )
    {
      tokens: (fold check-ownership (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20 u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34 u35 u36 u37 u38 u39 u40 u41 u42 u43 u44 u45 u46 u47 u48 u49 u50) {owner: owner, tokens: (list)})
    }
  )
)

;; Helper function for tokens-of-owner
(define-private (check-ownership (token-id uint) (acc {owner: principal, tokens: (list 50 uint)}))
  (if (is-eq (default-to 'SP000000000000000000002Q6VF78 (map-get? token-owners token-id)) (get owner acc))
    {owner: (get owner acc), tokens: (unwrap-panic (as-max-len? (append (get tokens acc) token-id) u50))}
    acc
  )
)

;; Set token URI (only owner or approved)
(define-public (set-token-uri (token-id uint) (new-uri (string-ascii 256)))
  (let (
    (token-owner (unwrap! (map-get? token-owners token-id) ERR_TOKEN_NOT_FOUND))
  )
    (asserts! (or 
      (is-eq tx-sender token-owner)
      (is-eq (some tx-sender) (map-get? token-approvals token-id))
      (default-to false (map-get? operator-approvals {owner: token-owner, operator: tx-sender}))
    ) ERR_NOT_AUTHORIZED)
    
    ;; Update metadata with new URI
    (match (map-get? token-metadata token-id)
      metadata (begin
        (map-set token-metadata token-id (merge metadata {uri: new-uri}))
        (print {
          event: "uri-updated",
          token-id: token-id,
          new-uri: new-uri,
          stacks-block-time: stacks-block-time
        })
        (ok true)
      )
      ERR_TOKEN_NOT_FOUND
    )
  )
)

;; Set token attributes (only owner or approved)
(define-public (set-token-attributes (token-id uint) (attributes (string-ascii 512)))
  (let (
    (token-owner (unwrap! (map-get? token-owners token-id) ERR_TOKEN_NOT_FOUND))
  )
    (asserts! (or 
      (is-eq tx-sender token-owner)
      (is-eq (some tx-sender) (map-get? token-approvals token-id))
      (default-to false (map-get? operator-approvals {owner: token-owner, operator: tx-sender}))
    ) ERR_NOT_AUTHORIZED)
    
    ;; Update metadata with new attributes
    (match (map-get? token-metadata token-id)
      metadata (begin
        (map-set token-metadata token-id (merge metadata {attributes: (some attributes)}))
        (print {
          event: "attributes-updated",
          token-id: token-id,
          attributes: attributes,
          stacks-block-time: stacks-block-time
        })
        (ok true)
      )
      ERR_TOKEN_NOT_FOUND
    )
  )
)

;; Get comprehensive token information
(define-read-only (get-token-info (token-id uint))
  (match (map-get? token-metadata token-id)
    metadata (ok {
      owner: (unwrap! (map-get? token-owners token-id) ERR_TOKEN_NOT_FOUND),
      uri: (get uri metadata),
      name: (get name metadata),
      description: (get description metadata),
      creator: (get creator metadata),
      created-at: (get created-at metadata),
      attributes: (get attributes metadata)
    })
    ERR_TOKEN_NOT_FOUND
  )
)

;; Get batch token information
(define-read-only (get-batch-token-info (token-ids (list 100 uint)))
  (map get-token-info token-ids)
)

;; ============================================================================
;; Public Functions (ERC-721 Standard)
;; ============================================================================

;; Set contract URI (only contract owner) 
(define-public (set-contract-uri (new-uri (string-ascii 256)))
  (if (is-eq tx-sender CONTRACT_OWNER)
    (begin
      (var-set base-contract-uri new-uri)
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

;; Toggle asset restrictions (only contract owner)
(define-public (toggle-asset-restrictions (restricted bool))
  (if (is-eq tx-sender CONTRACT_OWNER)
    (begin
      (var-set assets-restricted restricted)
      (print {
        event: "asset-restrictions-toggled", 
        restricted: restricted, 
        block-height: stacks-block-time
      })
      (ok restricted)
    )
    ERR_NOT_AUTHORIZED
  )
)

;; Approve a principal to transfer a specific token (ERC-721 approve)
(define-public (approve (to principal) (token-id uint))
  (let (
    (token-owner (unwrap! (map-get? token-owners token-id) ERR_TOKEN_NOT_FOUND))
    (current-time stacks-block-time)
  )
    (asserts! (or (is-eq tx-sender token-owner) (is-approved-for-all token-owner tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (not (is-eq to token-owner)) ERR_INVALID_RECIPIENT)
    
    (map-set token-approvals token-id to)
    
    (print {
      event: "approval",
      owner: token-owner,
      approved: to,
      token-id: token-id,
      stacks-block-time: current-time
    })
    
    (ok true)
  )
)

;; Set or unset approval for all tokens (ERC-721 setApprovalForAll)
(define-public (set-approval-for-all (operator principal) (approved bool))
  (let (
    (current-time stacks-block-time)
  )
    (asserts! (not (is-eq tx-sender operator)) ERR_INVALID_RECIPIENT)
    
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

;; Mint a new NFT (ERC-721 mint with Clarity v4 enhancements)
(define-public (mint 
  (to principal)
  (token-id uint)
  (name (string-ascii 64))
  (description (string-ascii 256))
  (uri (string-ascii 256))
  (signature (optional (buff 64)))
  (public-key (optional (buff 33)))
  (message-hash (optional (buff 32)))
)
  (let (
    (current-time stacks-block-time)
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
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! signature-verified ERR_INVALID_SIGNATURE)
    (asserts! (is-none (map-get? token-owners token-id)) ERR_TOKEN_ALREADY_EXISTS)
    (asserts! (<= (len uri) MAX_URI_LENGTH) ERR_URI_TOO_LONG)
    (asserts! (not (var-get assets-restricted)) ERR_ASSETS_RESTRICTED)
    (asserts! (not (is-eq to CONTRACT_OWNER)) ERR_INVALID_RECIPIENT)
    
    ;; Create token metadata
    (map-set token-metadata token-id {
      uri: uri,
      name: name,
      description: description,
      creator: tx-sender,
      created-at: current-time,
      signature-hash: message-hash,
      attributes: none
    })
    
    ;; Set token owner
    (map-set token-owners token-id to)
    
    ;; Update total supply
    (var-set token-supply (+ (var-get token-supply) u1))
    
    ;; Track mint operation
    (let ((new-nonce (+ (var-get operation-nonce) u1)))
      (var-set operation-nonce new-nonce)
      (map-set transfer-operations new-nonce {
        from: CONTRACT_OWNER,
        to: to,
        token-id: token-id,
        block-height: stacks-block-height,
        timestamp: current-time
      })
    )
    
    (print {
      event: "mint",
      to: to,
      token-id: token-id,
      name: name,
      uri: uri,
      creator: tx-sender,
      signature-verified: signature-verified,
      stacks-block-time: current-time
    })
    
    (ok token-id)
  )
)

;; Batch mint multiple NFTs (ERC-721 extension)
(define-public (batch-mint
  (recipients (list 10 principal))
  (token-ids (list 10 uint))
  (names (list 10 (string-ascii 64)))
  (descriptions (list 10 (string-ascii 256)))
  (uris (list 10 (string-ascii 256)))
  (signature (optional (buff 64)))
  (public-key (optional (buff 33)))
  (message-hash (optional (buff 32)))
)
  (let (
    (signature-verified (match signature
      sig (match public-key
        pub-key (match message-hash
          msg-hash (secp256r1-verify msg-hash sig pub-key)
          false
        )
        false
      )
      true ;; Allow batch minting without signature
    ))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! signature-verified ERR_INVALID_SIGNATURE)
    (asserts! (not (var-get assets-restricted)) ERR_ASSETS_RESTRICTED)
    
    ;; Mint each NFT in the batch
    (map mint-single recipients token-ids names descriptions uris)
    (ok true)
  )
)

;; Helper function for batch minting
(define-private (mint-single
  (recipient principal)
  (token-id uint)
  (name (string-ascii 64))
  (description (string-ascii 256))
  (uri (string-ascii 256))
)
  (begin
    (asserts! (is-none (map-get? token-owners token-id)) token-id)
    (asserts! (<= (len uri) MAX_URI_LENGTH) token-id)
    (asserts! (not (is-eq recipient CONTRACT_OWNER)) token-id)
    
    ;; Create token metadata
    (map-set token-metadata token-id {
      uri: uri,
      name: name,
      description: description,
      creator: tx-sender,
      created-at: stacks-block-time,
      signature-hash: none,
      attributes: none
    })
    
    ;; Set token owner
    (map-set token-owners token-id recipient)
    
    ;; Update total supply
    (var-set token-supply (+ (var-get token-supply) u1))
    
    (print {
      event: "mint",
      to: recipient,
      token-id: token-id,
      name: name,
      uri: uri,
      creator: tx-sender,
      signature-verified: true,
      stacks-block-time: stacks-block-time
    })
    
    token-id
  )
)

;; Transfer token from one principal to another (ERC-721 transferFrom)
(define-public (transfer-from 
  (from principal) 
  (to principal) 
  (token-id uint)
  (signature (optional (buff 64)))
  (public-key (optional (buff 33)))
  (message-hash (optional (buff 32)))
)
  (let (
    (token-owner (unwrap! (map-get? token-owners token-id) ERR_TOKEN_NOT_FOUND))
    (current-time stacks-block-time)
    (is-approved (or 
      (is-eq tx-sender from)
      (is-eq tx-sender (default-to from (map-get? token-approvals token-id)))
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
      true ;; Allow transfer without signature
    ))
  )
    (asserts! (is-eq from token-owner) ERR_NOT_AUTHORIZED)
    (asserts! is-approved ERR_NOT_APPROVED)
    (asserts! (not (is-eq to from)) ERR_INVALID_RECIPIENT)
    (asserts! signature-verified ERR_INVALID_SIGNATURE)
    
    ;; Transfer ownership
    (map-set token-owners token-id to)
    (map-delete token-approvals token-id)
    
    ;; Track transfer operation
    (let ((new-nonce (+ (var-get operation-nonce) u1)))
      (var-set operation-nonce new-nonce)
      (map-set transfer-operations new-nonce {
        from: from,
        to: to,
        token-id: token-id,
        block-height: stacks-block-height,
        timestamp: current-time
      })
    )
    
    (print {
      event: "transfer",
      from: from,
      to: to,
      token-id: token-id,
      signature-verified: signature-verified,
      stacks-block-time: current-time
    })
    
    (ok true)
  )
)

;; Safe transfer with additional data (ERC-721 safeTransferFrom)
(define-public (safe-transfer-from 
  (from principal)
  (to principal)
  (token-id uint)
  (data (optional (buff 128)))
  (signature (optional (buff 64)))
  (public-key (optional (buff 33)))
  (message-hash (optional (buff 32)))
)
  (begin 
    (try! (transfer-from from to token-id signature public-key message-hash))
    (print {
      event: "safe-transfer",
      from: from,
      to: to,
      token-id: token-id,
      data: data,
      signature-verified: (and 
        (is-some signature) 
        (is-some public-key) 
        (is-some message-hash)
        (secp256r1-verify (unwrap-panic message-hash) (unwrap-panic signature) (unwrap-panic public-key))
      ),
      stacks-block-time: stacks-block-time
    })
    (ok true)
  )
)

;; Burn/destroy an NFT (ERC-721 burn)
(define-public (burn 
  (token-id uint)
  (signature (optional (buff 64)))
  (public-key (optional (buff 33)))
  (message-hash (optional (buff 32)))
)
  (let (
    (token-owner (unwrap! (map-get? token-owners token-id) ERR_TOKEN_NOT_FOUND))
    (current-time stacks-block-time)
    (is-authorized (or 
      (is-eq tx-sender token-owner)
      (is-approved-for-all token-owner tx-sender)
      (and (is-some (map-get? token-approvals token-id)) (is-eq tx-sender (unwrap-panic (map-get? token-approvals token-id))))
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
    (asserts! is-authorized ERR_NOT_APPROVED)
    (asserts! signature-verified ERR_INVALID_SIGNATURE)
    
    ;; Remove token ownership and metadata
    (map-delete token-owners token-id)
    (map-delete token-approvals token-id)
    (map-delete token-metadata token-id)
    
    ;; Decrease total supply
    (var-set token-supply (- (var-get token-supply) u1))
    
    (print {
      event: "burn",
      token-id: token-id,
      owner: token-owner,
      operator: tx-sender,
      signature-verified: signature-verified,
      stacks-block-time: current-time
    })
    
    (ok true)
  )
)

;; ============================================================================
;; Tokenized Vault Functions
;; ============================================================================

;; Deposit assets into a vault
(define-public (vault-deposit 
  (vault-id uint)
  (amount uint)
  (signature (optional (buff 64)))
  (public-key (optional (buff 33)))
  (message-hash (optional (buff 32)))
)
  (let (
    (current-deposits (default-to u0 (map-get? vault-deposits tx-sender)))
    (current-shares (default-to u0 (map-get? vault-shares tx-sender)))
    (current-time stacks-block-time)
    (signature-verified (match signature
      sig (match public-key
        pub-key (match message-hash
          msg-hash (secp256r1-verify msg-hash sig pub-key)
          false
        )
        false
      )
      true
    ))
  )
    (asserts! signature-verified ERR_INVALID_SIGNATURE)
    (asserts! (> amount u0) ERR_INVALID_RECIPIENT)
    
    ;; Update deposits and shares
    (map-set vault-deposits tx-sender (+ current-deposits amount))
    (map-set vault-shares tx-sender (+ current-shares amount))
    
    (print {
      event: "vault-deposit",
      vault-id: vault-id,
      depositor: tx-sender,
      amount: amount,
      total-deposits: (+ current-deposits amount),
      shares: (+ current-shares amount),
      signature-verified: signature-verified,
      stacks-block-time: current-time
    })
    
    (ok amount)
  )
)

;; Withdraw assets from a vault
(define-public (vault-withdraw 
  (vault-id uint)
  (shares uint)
  (signature (optional (buff 64)))
  (public-key (optional (buff 33)))
  (message-hash (optional (buff 32)))
)
  (let (
    (current-deposits (default-to u0 (map-get? vault-deposits tx-sender)))
    (current-shares (default-to u0 (map-get? vault-shares tx-sender)))
    (current-time stacks-block-time)
    (signature-verified (match signature
      sig (match public-key
        pub-key (match message-hash
          msg-hash (secp256r1-verify msg-hash sig pub-key)
          false
        )
        false
      )
      true
    ))
  )
    (asserts! signature-verified ERR_INVALID_SIGNATURE)
    (asserts! (>= current-shares shares) ERR_INSUFFICIENT_SHARES)
    (asserts! (> shares u0) ERR_INVALID_RECIPIENT)
    
    ;; Update deposits and shares
    (map-set vault-deposits tx-sender (- current-deposits shares))
    (map-set vault-shares tx-sender (- current-shares shares))
    
    (print {
      event: "vault-withdraw",
      vault-id: vault-id,
      withdrawer: tx-sender,
      shares: shares,
      remaining-deposits: (- current-deposits shares),
      remaining-shares: (- current-shares shares),
      signature-verified: signature-verified,
      stacks-block-time: current-time
    })
    
    (ok shares)
  )
)

;; Transfer vault shares between users
(define-public (transfer-vault-shares 
  (vault-id uint)
  (to principal)
  (shares uint)
  (signature (optional (buff 64)))
  (public-key (optional (buff 33)))
  (message-hash (optional (buff 32)))
)
  (let (
    (sender-shares (default-to u0 (map-get? vault-shares tx-sender)))
    (receiver-shares (default-to u0 (map-get? vault-shares to)))
    (current-time stacks-block-time)
    (signature-verified (match signature
      sig (match public-key
        pub-key (match message-hash
          msg-hash (secp256r1-verify msg-hash sig pub-key)
          false
        )
        false
      )
      true
    ))
  )
    (asserts! signature-verified ERR_INVALID_SIGNATURE)
    (asserts! (>= sender-shares shares) ERR_INSUFFICIENT_SHARES)
    (asserts! (> shares u0) ERR_INVALID_RECIPIENT)
    (asserts! (not (is-eq tx-sender to)) ERR_INVALID_RECIPIENT)
    
    ;; Update shares
    (map-set vault-shares tx-sender (- sender-shares shares))
    (map-set vault-shares to (+ receiver-shares shares))
    
    (print {
      event: "vault-share-transfer",
      vault-id: vault-id,
      from: tx-sender,
      to: to,
      shares: shares,
      signature-verified: signature-verified,
      stacks-block-time: current-time
    })
    
    (ok shares)
  )
)
