;; Outcome token contract for prediction market shares
;; Compatible with Clarity 2.1 and SIP-010 standards.
;; This contract manages the minting, burning, and transfer of binary outcome tokens.

(define-constant ERR_UNAUTHORIZED (err u1001))        ;; Caller has no permission for this action
(define-constant ERR_INVALID_MARKET (err u1002))      ;; Market ID does not exist
(define-constant ERR_INVALID_OUTCOME (err u1003))     ;; Outcome ID is not YES (1) or NO (0)
(define-constant ERR_INSUFFICIENT_BALANCE (err u1004)) ;; User lacks required token balance
(define-constant ERR_ALREADY_INITIALIZED (err u1005)) ;; Market/Token already initialized


(define-map token-id-yes-map
  uint
  uint
)
(define-map token-id-no-map
  uint
  uint
)
(define-map token-metadata
  uint
  {
    name: (string-ascii 32),
    symbol: (string-ascii 10),
    decimals: uint,
    market-id: uint,
    outcome: uint,
  }
)
(define-map balances
  {
    owner: principal,
    token-id: uint,
  }
  uint
)
(define-map total-supply-map
  uint
  uint
)
(define-map authorized-admins principal bool)


(define-data-var contract-owner principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

(define-read-only (is-admin (user principal))
  (default-to false (map-get? authorized-admins user))
)

(define-public (add-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set authorized-admins new-admin true))
  )
)

(define-public (remove-admin (admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set authorized-admins admin false))
  )
)


;; Looks up the token identifier for a given market and outcome type
;; Outcome 1 represents YES, outcome 0 represents NO
(define-read-only (get-token-id
    (market-id uint)
    (outcome uint)
  )
  (if (is-eq outcome u1)
    (ok (default-to u0 (map-get? token-id-yes-map market-id)))
    (ok (default-to u0 (map-get? token-id-no-map market-id)))
  )
)

;; Returns stored information about a specific token type
(define-read-only (get-token-metadata (token-id uint))
  (ok (map-get? token-metadata token-id))
)

;; Checks how many shares of a specific token a user owns
(define-read-only (get-balance
    (token-id uint)
    (owner principal)
  )
  (ok (default-to u0
    (map-get? balances {
      owner: owner,
      token-id: token-id,
    })
  ))
)

;; SIP-010 related getters
(define-read-only (get-name (token-id uint))
  (ok (get name (default-to {name: "Unknown", symbol: "???", decimals: u6, market-id: u0, outcome: u0} (map-get? token-metadata token-id))))
)

(define-read-only (get-symbol (token-id uint))
  (ok (get symbol (default-to {name: "Unknown", symbol: "???", decimals: u6, market-id: u0, outcome: u0} (map-get? token-metadata token-id))))
)

(define-read-only (get-decimals (token-id uint))
  (ok (get decimals (default-to {name: "Unknown", symbol: "???", decimals: u6, market-id: u0, outcome: u0} (map-get? token-metadata token-id))))
)

(define-read-only (get-token-uri (token-id uint))
  (ok none)
)


;; Returns the total number of shares minted for a token type
(define-read-only (get-total-supply (token-id uint))
  (ok (default-to u0 (map-get? total-supply-map token-id)))
)

;; Moves shares between user accounts
;; Requires sender to authorize the transfer
(define-public (transfer
    (token-id uint)
    (amount uint)
    (sender principal)
    (recipient principal)
  )
  (begin
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
    (asserts!
      (>=
        (default-to u0
          (map-get? balances {
            owner: sender,
            token-id: token-id,
          })
        )
        amount
      )
      ERR_INSUFFICIENT_BALANCE
    )
    (map-set balances {
      owner: sender,
      token-id: token-id,
    }
      (-
        (default-to u0
          (map-get? balances {
            owner: sender,
            token-id: token-id,
          })
        )
        amount
      ))
    (map-set balances {
      owner: recipient,
      token-id: token-id,
    }
      (+
        (default-to u0
          (map-get? balances {
            owner: recipient,
            token-id: token-id,
          })
        )
        amount
      ))
    (ok true)
  )
)

;; Creates new shares when users purchase outcome positions
;; Restricted to the authorized market contract
(define-public (mint
    (token-id uint)
    (recipient principal)
    (amount uint)
  )
  (begin
    (asserts! (or (is-eq tx-sender (var-get contract-owner)) (is-admin tx-sender)) ERR_UNAUTHORIZED)

    (map-set balances {
      owner: recipient,
      token-id: token-id,
    }
      (+
        (default-to u0
          (map-get? balances {
            owner: recipient,
            token-id: token-id,
          })
        )
        amount
      ))
    (map-set total-supply-map token-id
      (+ (default-to u0 (map-get? total-supply-map token-id)) amount)
    )
    (ok true)
  )
)

;; Destroys shares when users claim winnings
;; Restricted to the authorized market contract
(define-public (burn
    (token-id uint)
    (owner principal)
    (amount uint)
  )
  (begin
    (asserts! (or (is-eq tx-sender (var-get contract-owner)) (is-admin tx-sender)) ERR_UNAUTHORIZED)

    (asserts!
      (>=
        (default-to u0
          (map-get? balances {
            owner: owner,
            token-id: token-id,
          })
        )
        amount
      )
      ERR_INSUFFICIENT_BALANCE
    )
    (map-set balances {
      owner: owner,
      token-id: token-id,
    }
      (-
        (default-to u0
          (map-get? balances {
            owner: owner,
            token-id: token-id,
          })
        )
        amount
      ))
    (map-set total-supply-map token-id
      (- (default-to u0 (map-get? total-supply-map token-id)) amount)
    )
    (ok true)
  )
)

;; Registers a new pair of outcome tokens when a market is created
;; Sets up metadata and assigns unique token IDs
(define-public (initialize-token
    (market-id uint)
    (token-id-yes uint)
    (token-id-no uint)
    (name-yes (string-ascii 32))
    (name-no (string-ascii 32))
    (symbol-yes (string-ascii 10))
    (symbol-no (string-ascii 10))
  )
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? token-id-yes-map market-id)) ERR_ALREADY_INITIALIZED)

    (map-set token-id-yes-map market-id token-id-yes)
    (map-set token-id-no-map market-id token-id-no)
    (map-set token-metadata token-id-yes {
      name: name-yes,
      symbol: symbol-yes,
      decimals: u6,
      market-id: market-id,
      outcome: u1,
    })
    (map-set token-metadata token-id-no {
      name: name-no,
      symbol: symbol-no,
      decimals: u6,
      market-id: market-id,
      outcome: u0,
    })
    (ok true)
  )
)

;; Sets the contract owner which will be the market contract address
(define-public (initialize (owner principal))
  (begin
    (asserts! (is-eq tx-sender 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM) ERR_UNAUTHORIZED)
    (var-set contract-owner owner)
    (ok true)
  )
)


(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

(define-read-only (get-token-id-yes (market-id uint))
  (ok (map-get? token-id-yes-map market-id))
)

(define-read-only (get-token-id-no (market-id uint))
  (ok (map-get? token-id-no-map market-id))
)

(define-read-only (get-metadata (token-id uint))
  (ok (map-get? token-metadata token-id))
)
