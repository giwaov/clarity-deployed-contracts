;; Outcome token contract for prediction market shares
;; Each market mints a YES token and a NO token to represent user positions

(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_INVALID_MARKET (err u1002))
(define-constant ERR_INVALID_OUTCOME (err u1003))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1004))

(define-map token-id-yes-map uint uint)
(define-map token-id-no-map uint uint)
(define-map token-metadata uint
    {
        name: (string-ascii 32),
        symbol: (string-ascii 10),
        decimals: uint,
        market-id: uint,
        outcome: uint
    }
)
(define-map balances (tuple (owner principal) (token-id uint)) uint)
(define-map total-supply-map uint uint)

(define-data-var contract-owner principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Looks up the token identifier for a given market and outcome type
;; Outcome 1 represents YES, outcome 0 represents NO
(define-read-only (get-token-id (market-id uint) (outcome uint))
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
(define-read-only (get-balance (token-id uint) (owner principal))
    (ok (default-to u0 (map-get? balances (tuple (owner owner) (token-id token-id)))))
)

;; Returns the total number of shares minted for a token type
(define-read-only (get-total-supply (token-id uint))
    (ok (default-to u0 (map-get? total-supply-map token-id)))
)

;; Moves shares between user accounts
;; Requires sender to authorize the transfer
(define-public (transfer (token-id uint) (amount uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
        (asserts! (>= (default-to u0 (map-get? balances (tuple (owner sender) (token-id token-id)))) amount) ERR_INSUFFICIENT_BALANCE)
        (map-set balances (tuple (owner sender) (token-id token-id)) (- (default-to u0 (map-get? balances (tuple (owner sender) (token-id token-id)))) amount))
        (map-set balances (tuple (owner recipient) (token-id token-id)) (+ (default-to u0 (map-get? balances (tuple (owner recipient) (token-id token-id)))) amount))
        (ok true)
    )
)

;; Creates new shares when users purchase outcome positions
;; Restricted to the authorized market contract
(define-public (mint (token-id uint) (recipient principal) (amount uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (map-set balances (tuple (owner recipient) (token-id token-id)) (+ (default-to u0 (map-get? balances (tuple (owner recipient) (token-id token-id)))) amount))
        (map-set total-supply-map token-id (+ (default-to u0 (map-get? total-supply-map token-id)) amount))
        (ok true)
    )
)

;; Destroys shares when users claim winnings
;; Restricted to the authorized market contract
(define-public (burn (token-id uint) (owner principal) (amount uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (asserts! (>= (default-to u0 (map-get? balances (tuple (owner owner) (token-id token-id)))) amount) ERR_INSUFFICIENT_BALANCE)
        (map-set balances (tuple (owner owner) (token-id token-id)) (- (default-to u0 (map-get? balances (tuple (owner owner) (token-id token-id)))) amount))
        (map-set total-supply-map token-id (- (default-to u0 (map-get? total-supply-map token-id)) amount))
        (ok true)
    )
)

;; Registers a new pair of outcome tokens when a market is created
;; Sets up metadata and assigns unique token IDs
(define-public (initialize-token (market-id uint) (token-id-yes uint) (token-id-no uint) (name-yes (string-ascii 32)) (name-no (string-ascii 32)) (symbol-yes (string-ascii 10)) (symbol-no (string-ascii 10)))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (map-set token-id-yes-map market-id token-id-yes)
        (map-set token-id-no-map market-id token-id-no)
        (map-set token-metadata token-id-yes { name: name-yes, symbol: symbol-yes, decimals: u6, market-id: market-id, outcome: u1 })
        (map-set token-metadata token-id-no { name: name-no, symbol: symbol-no, decimals: u6, market-id: market-id, outcome: u0 })
        (ok true)
    )
)

;; Sets the contract owner which will be the market contract address
(define-public (initialize (owner principal))
    (begin
        (var-set contract-owner owner)
        (ok true)
    )
)

