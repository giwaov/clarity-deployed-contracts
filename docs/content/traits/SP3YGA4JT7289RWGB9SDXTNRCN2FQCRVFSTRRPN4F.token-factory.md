---
title: "Trait token-factory"
draft: true
---
```
;; title: Token Factory
;; version: 1.0.0
;; summary: A smart contract for creating and managing custom tokens
;; description: This contract allows users to deploy token instances by providing token name, symbol, total supply, decimals, and other details. Each token follows SIP-010 standard.

;; constants
(define-constant ERR_TOKEN_NOT_FOUND u1001)
(define-constant ERR_INVALID_SUPPLY u1002)
(define-constant ERR_INVALID_DECIMALS u1003)
(define-constant ERR_INSUFFICIENT_BALANCE u1004)
(define-constant ERR_UNAUTHORIZED u1005)
(define-constant ERR_INVALID_RECIPIENT u1006)
(define-constant ERR_NAME_TOO_LONG u1007)
(define-constant ERR_SYMBOL_TOO_LONG u1008)
(define-constant ERR_URI_TOO_LONG u1009)

;; data vars
;; Token ID counter
(define-data-var token-id-counter uint u0)

;; data maps
;; Token metadata: token-id -> (name, symbol, decimals, total-supply, creator, uri, created-at)
(define-map token-metadata
  { token-id: uint }
  {
    name: (string-ascii 100),
    symbol: (string-ascii 20),
    decimals: uint,
    total-supply: uint,
    creator: principal,
    uri: (optional (string-ascii 200)),
    created-at: uint
  }
)

;; Token balances: (token-id, owner) -> balance
(define-map token-balances
  { token-id: uint, owner: principal }
  uint
)

;; Token allowances: (token-id, owner, spender) -> amount
(define-map token-allowances
  { token-id: uint, owner: principal, spender: principal }
  uint
)

;; public functions

;; Create a new token with specified parameters
;; @param name: Token name (max 100 characters)
;; @param symbol: Token symbol (max 20 characters)
;; @param decimals: Number of decimals (typically 6 or 8)
;; @param total-supply: Total supply of tokens to mint to creator
;; @param uri: Optional URI for token metadata
;; @returns: The new token ID
(define-public (create-token
  (name (string-ascii 100))
  (symbol (string-ascii 20))
  (decimals uint)
  (total-supply uint)
  (uri (optional (string-ascii 200)))
)
  (let (
    (caller tx-sender)
    (token-id (+ (var-get token-id-counter) u1))
  )
    ;; Validate inputs
    (asserts! (> (len name) u0) (err ERR_NAME_TOO_LONG))
    (asserts! (> (len symbol) u0) (err ERR_SYMBOL_TOO_LONG))
    (asserts! (and (>= decimals u0) (<= decimals u18)) (err ERR_INVALID_DECIMALS))
    (asserts! (> total-supply u0) (err ERR_INVALID_SUPPLY))
    
    ;; Store token metadata
    (map-set token-metadata
      { token-id: token-id }
      {
        name: name,
        symbol: symbol,
        decimals: decimals,
        total-supply: total-supply,
        creator: caller,
        uri: uri,
        created-at: u0
      }
    )
    
    ;; Mint total supply to creator
    (map-set token-balances
      { token-id: token-id, owner: caller }
      total-supply
    )
    
    ;; Update token counter
    (var-set token-id-counter token-id)
    
    (ok token-id)
  )
)

;; SIP-010: Get token name
(define-read-only (get-token-name
  (token-id uint)
)
  (let ((metadata (map-get? token-metadata { token-id: token-id })))
    (if (is-some metadata)
      (ok (get name (unwrap-panic metadata)))
      (err ERR_TOKEN_NOT_FOUND)
    )
  )
)

;; SIP-010: Get token symbol
(define-read-only (get-token-symbol
  (token-id uint)
)
  (let ((metadata (map-get? token-metadata { token-id: token-id })))
    (if (is-some metadata)
      (ok (get symbol (unwrap-panic metadata)))
      (err ERR_TOKEN_NOT_FOUND)
    )
  )
)

;; SIP-010: Get token decimals
(define-read-only (get-token-decimals
  (token-id uint)
)
  (let ((metadata (map-get? token-metadata { token-id: token-id })))
    (if (is-some metadata)
      (ok (get decimals (unwrap-panic metadata)))
      (err ERR_TOKEN_NOT_FOUND)
    )
  )
)

;; SIP-010: Get token total supply
(define-read-only (get-token-total-supply
  (token-id uint)
)
  (let ((metadata (map-get? token-metadata { token-id: token-id })))
    (if (is-some metadata)
      (ok (get total-supply (unwrap-panic metadata)))
      (err ERR_TOKEN_NOT_FOUND)
    )
  )
)

;; SIP-010: Get token URI
(define-read-only (get-token-uri
  (token-id uint)
)
  (let ((metadata (map-get? token-metadata { token-id: token-id })))
    (if (is-some metadata)
      (ok (get uri (unwrap-panic metadata)))
      (err ERR_TOKEN_NOT_FOUND)
    )
  )
)

;; SIP-010: Get balance of an address for a token
(define-read-only (get-balance
  (token-id uint)
  (owner principal)
)
  (let ((balance (map-get? token-balances { token-id: token-id, owner: owner })))
    (ok (default-to u0 balance))
  )
)

;; SIP-010: Transfer tokens
(define-public (transfer
  (token-id uint)
  (amount uint)
  (sender principal)
  (recipient principal)
  (memo (optional (buff 34)))
)
  (let (
    (caller tx-sender)
  )
    ;; Validate token exists
    (asserts! (is-some (map-get? token-metadata { token-id: token-id })) (err ERR_TOKEN_NOT_FOUND))
    (asserts! (is-eq caller sender) (err ERR_UNAUTHORIZED))
    (asserts! (> amount u0) (err ERR_INVALID_SUPPLY))
    
    ;; Check balance
    (let ((sender-balance (default-to u0 (map-get? token-balances { token-id: token-id, owner: sender }))))
      (asserts! (>= sender-balance amount) (err ERR_INSUFFICIENT_BALANCE))
      
      ;; Update balances
      (map-set token-balances
        { token-id: token-id, owner: sender }
        (- sender-balance amount)
      )
      (map-set token-balances
        { token-id: token-id, owner: recipient }
        (+ (default-to u0 (map-get? token-balances { token-id: token-id, owner: recipient })) amount)
      )
      
      (ok true)
    )
  )
)

;; SIP-010: Get allowance
(define-read-only (get-allowance
  (token-id uint)
  (owner principal)
  (spender principal)
)
  (ok (default-to u0 (map-get? token-allowances { token-id: token-id, owner: owner, spender: spender })))
)

;; SIP-010: Set allowance
(define-public (set-allowance
  (token-id uint)
  (owner principal)
  (spender principal)
  (amount uint)
)
  (let ((caller tx-sender))
    ;; Validate token exists
    (asserts! (is-some (map-get? token-metadata { token-id: token-id })) (err ERR_TOKEN_NOT_FOUND))
    (asserts! (is-eq caller owner) (err ERR_UNAUTHORIZED))
    
    ;; Set allowance
    (map-set token-allowances
      { token-id: token-id, owner: owner, spender: spender }
      amount
    )
    
    (ok true)
  )
)

;; SIP-010: Transfer from (using allowance)
(define-public (transfer-from
  (token-id uint)
  (amount uint)
  (sender principal)
  (recipient principal)
  (memo (optional (buff 34)))
)
  (let ((caller tx-sender))
    ;; Validate token exists
    (asserts! (is-some (map-get? token-metadata { token-id: token-id })) (err ERR_TOKEN_NOT_FOUND))
    (asserts! (> amount u0) (err ERR_INVALID_SUPPLY))
    
    ;; Check allowance
    (let ((allowance (default-to u0 (map-get? token-allowances { token-id: token-id, owner: sender, spender: caller }))))
      (asserts! (>= allowance amount) (err ERR_INSUFFICIENT_BALANCE))
      
      ;; Check sender balance
      (let ((sender-balance (default-to u0 (map-get? token-balances { token-id: token-id, owner: sender }))))
        (asserts! (>= sender-balance amount) (err ERR_INSUFFICIENT_BALANCE))
        
        ;; Update balances
        (map-set token-balances
          { token-id: token-id, owner: sender }
          (- sender-balance amount)
        )
        (map-set token-balances
          { token-id: token-id, owner: recipient }
          (+ (default-to u0 (map-get? token-balances { token-id: token-id, owner: recipient })) amount)
        )
        
        ;; Update allowance
        (map-set token-allowances
          { token-id: token-id, owner: sender, spender: caller }
          (- allowance amount)
        )
        
        (ok true)
      )
    )
  )
)

;; Mint additional tokens (only creator can mint)
(define-public (mint-token
  (token-id uint)
  (amount uint)
  (recipient principal)
)
  (let (
    (caller tx-sender)
    (metadata (map-get? token-metadata { token-id: token-id }))
  )
    (asserts! (is-some metadata) (err ERR_TOKEN_NOT_FOUND))
    (let ((token-info (unwrap-panic metadata)))
      (asserts! (is-eq caller (get creator token-info)) (err ERR_UNAUTHORIZED))
      (asserts! (> amount u0) (err ERR_INVALID_SUPPLY))
      
      ;; Update total supply
      (map-set token-metadata
        { token-id: token-id }
        {
          name: (get name token-info),
          symbol: (get symbol token-info),
          decimals: (get decimals token-info),
          total-supply: (+ (get total-supply token-info) amount),
          creator: (get creator token-info),
          uri: (get uri token-info),
          created-at: (get created-at token-info)
        }
      )
      
      ;; Update recipient balance
      (map-set token-balances
        { token-id: token-id, owner: recipient }
        (+ (default-to u0 (map-get? token-balances { token-id: token-id, owner: recipient })) amount)
      )
      
      (ok true)
    )
  )
)

;; Burn tokens
(define-public (burn-token
  (token-id uint)
  (amount uint)
  (owner principal)
)
  (let ((caller tx-sender))
    ;; Validate token exists
    (asserts! (is-some (map-get? token-metadata { token-id: token-id })) (err ERR_TOKEN_NOT_FOUND))
    (asserts! (is-eq caller owner) (err ERR_UNAUTHORIZED))
    (asserts! (> amount u0) (err ERR_INVALID_SUPPLY))
    
    ;; Check balance
    (let ((owner-balance (default-to u0 (map-get? token-balances { token-id: token-id, owner: owner }))))
      (asserts! (>= owner-balance amount) (err ERR_INSUFFICIENT_BALANCE))
      
      ;; Update balance
      (map-set token-balances
        { token-id: token-id, owner: owner }
        (- owner-balance amount)
      )
      
      ;; Update total supply
      (let ((metadata (unwrap-panic (map-get? token-metadata { token-id: token-id }))))
        (map-set token-metadata
          { token-id: token-id }
          {
            name: (get name metadata),
            symbol: (get symbol metadata),
            decimals: (get decimals metadata),
            total-supply: (- (get total-supply metadata) amount),
            creator: (get creator metadata),
            uri: (get uri metadata),
            created-at: (get created-at metadata)
          }
        )
      )
      
      (ok true)
    )
  )
)

;; read only functions

;; Get token metadata by ID
(define-read-only (get-token-metadata
  (token-id uint)
)
  (map-get? token-metadata { token-id: token-id })
)

;; Get token creator
(define-read-only (get-token-creator
  (token-id uint)
)
  (let ((metadata (map-get? token-metadata { token-id: token-id })))
    (if (is-some metadata)
      (ok (get creator (unwrap-panic metadata)))
      (err ERR_TOKEN_NOT_FOUND)
    )
  )
)

;; Get total number of tokens created
(define-read-only (get-total-tokens)
  (ok (var-get token-id-counter))
)

;; Get statistics
(define-read-only (get-stats)
  (ok {
    total-tokens: (var-get token-id-counter)
  })
)


```
