;; timelock-token.clar
;; SIP-010 Fungible Token for TimeLock Exchange Staking Rewards
;; Token Symbol: TLX
;; Decimals: 6

;; ============================================================================
;; SIP-010 Trait Definition
;; ============================================================================

(define-trait sip-010-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 10) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

;; ============================================================================
;; Constants
;; ============================================================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INSUFFICIENT-BALANCE (err u402))
(define-constant ERR-INVALID-AMOUNT (err u403))
(define-constant ERR-MINT-FAILED (err u404))
(define-constant ERR-BURN-FAILED (err u405))
(define-constant ERR-TRANSFER-FAILED (err u406))
(define-constant ERR-NOT-MINTER (err u407))

;; Token metadata
(define-constant TOKEN-NAME "TimeLock Token")
(define-constant TOKEN-SYMBOL "TLX")
(define-constant TOKEN-DECIMALS u6)
(define-constant TOKEN-URI (some u"https://timelock-exchange.com/token/tlx.json"))

;; Supply limits
(define-constant MAX-SUPPLY u1000000000000000) ;; 1 billion TLX (with 6 decimals)
(define-constant INITIAL-REWARDS-POOL u100000000000000) ;; 100 million TLX for staking rewards

;; ============================================================================
;; Data Variables
;; ============================================================================

(define-data-var total-supply uint u0)
(define-data-var rewards-distributed uint u0)
(define-data-var token-paused bool false)

;; ============================================================================
;; Data Maps
;; ============================================================================

;; Token balances
(define-map balances principal uint)

;; Allowances for delegated transfers
(define-map allowances 
  { owner: principal, spender: principal }
  uint
)

;; Authorized minters (staking contracts)
(define-map minters principal bool)

;; ============================================================================
;; SIP-010 Functions
;; ============================================================================

;; Transfer tokens
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (not (var-get token-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (let (
      (sender-balance (default-to u0 (map-get? balances sender)))
    )
      (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
      (map-set balances sender (- sender-balance amount))
      (map-set balances recipient (+ (default-to u0 (map-get? balances recipient)) amount))
      (print { type: "transfer", amount: amount, sender: sender, recipient: recipient, memo: memo })
      (ok true)
    )
  )
)

;; Get token name
(define-read-only (get-name)
  (ok TOKEN-NAME)
)

;; Get token symbol
(define-read-only (get-symbol)
  (ok TOKEN-SYMBOL)
)

;; Get decimals
(define-read-only (get-decimals)
  (ok TOKEN-DECIMALS)
)

;; Get balance
(define-read-only (get-balance (account principal))
  (ok (default-to u0 (map-get? balances account)))
)

;; Get total supply
(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

;; Get token URI
(define-read-only (get-token-uri)
  (ok TOKEN-URI)
)

;; ============================================================================
;; Minting & Burning (for staking rewards)
;; ============================================================================

;; Add authorized minter (owner only)
(define-public (add-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set minters minter true)
    (print { event: "minter-added", minter: minter })
    (ok true)
  )
)

;; Remove minter (owner only)
(define-public (remove-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-delete minters minter)
    (print { event: "minter-removed", minter: minter })
    (ok true)
  )
)

;; Check if address is minter
(define-read-only (is-minter (address principal))
  (or (is-eq address CONTRACT-OWNER) (default-to false (map-get? minters address)))
)

;; Mint tokens (minters only - for staking rewards)
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-minter tx-sender) ERR-NOT-MINTER)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= (+ (var-get total-supply) amount) MAX-SUPPLY) ERR-MINT-FAILED)
    (var-set total-supply (+ (var-get total-supply) amount))
    (var-set rewards-distributed (+ (var-get rewards-distributed) amount))
    (map-set balances recipient (+ (default-to u0 (map-get? balances recipient)) amount))
    (print { event: "mint", amount: amount, recipient: recipient, minter: tx-sender })
    (ok true)
  )
)

;; Burn tokens
(define-public (burn (amount uint))
  (let (
    (sender-balance (default-to u0 (map-get? balances tx-sender)))
  )
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
    (var-set total-supply (- (var-get total-supply) amount))
    (map-set balances tx-sender (- sender-balance amount))
    (print { event: "burn", amount: amount, burner: tx-sender })
    (ok true)
  )
)

;; ============================================================================
;; Allowance Functions (ERC-20 style)
;; ============================================================================

;; Approve spender
(define-public (approve (spender principal) (amount uint))
  (begin
    (map-set allowances { owner: tx-sender, spender: spender } amount)
    (print { event: "approval", owner: tx-sender, spender: spender, amount: amount })
    (ok true)
  )
)

;; Get allowance
(define-read-only (get-allowance (owner principal) (spender principal))
  (ok (default-to u0 (map-get? allowances { owner: owner, spender: spender })))
)

;; Transfer from (using allowance)
(define-public (transfer-from (amount uint) (sender principal) (recipient principal))
  (let (
    (current-allowance (default-to u0 (map-get? allowances { owner: sender, spender: tx-sender })))
    (sender-balance (default-to u0 (map-get? balances sender)))
  )
    (asserts! (not (var-get token-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (>= current-allowance amount) ERR-NOT-AUTHORIZED)
    (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
    (map-set allowances { owner: sender, spender: tx-sender } (- current-allowance amount))
    (map-set balances sender (- sender-balance amount))
    (map-set balances recipient (+ (default-to u0 (map-get? balances recipient)) amount))
    (print { event: "transfer-from", amount: amount, sender: sender, recipient: recipient, spender: tx-sender })
    (ok true)
  )
)

;; ============================================================================
;; Admin Functions
;; ============================================================================

;; Pause/unpause token (emergency)
(define-public (set-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set token-paused paused)
    (print { event: "pause-toggled", paused: paused })
    (ok true)
  )
)

;; ============================================================================
;; Read-Only Functions
;; ============================================================================

;; Get token stats
(define-read-only (get-token-stats)
  {
    name: TOKEN-NAME,
    symbol: TOKEN-SYMBOL,
    decimals: TOKEN-DECIMALS,
    total-supply: (var-get total-supply),
    max-supply: MAX-SUPPLY,
    rewards-distributed: (var-get rewards-distributed),
    is-paused: (var-get token-paused)
  }
)

;; Get remaining mintable supply
(define-read-only (get-remaining-supply)
  (- MAX-SUPPLY (var-get total-supply))
)

;; ============================================================================
;; Initialize (mint initial supply to owner for distribution)
;; ============================================================================

;; Initial mint for rewards pool (call once after deployment)
(define-public (initialize-rewards-pool)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (var-get total-supply) u0) ERR-MINT-FAILED) ;; Only once
    (var-set total-supply INITIAL-REWARDS-POOL)
    (map-set balances CONTRACT-OWNER INITIAL-REWARDS-POOL)
    (print { event: "rewards-pool-initialized", amount: INITIAL-REWARDS-POOL })
    (ok INITIAL-REWARDS-POOL)
  )
)
