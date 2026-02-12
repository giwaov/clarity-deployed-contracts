;; STX DeFi Yield Vault Contract
;; Handles yield generation for deposited STX
;; Mainnet deployment

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u2000))
(define-constant ERR_INSUFFICIENT_BALANCE (err u2001))
(define-constant ERR_INVALID_AMOUNT (err u2002))
(define-constant ERR_NO_DEPOSIT (err u2003))
(define-constant ERR_ALREADY_INITIALIZED (err u2004))
(define-constant ERR_NOT_INITIALIZED (err u2005))
(define-constant ERR_VAULT_EMPTY (err u2006))

;; Yield rate: 8% APY (stored as basis points, 800 = 8%)
(define-constant VAULT_YIELD_RATE u800)
;; Blocks per year (approx 52,560 with 10-min blocks)
(define-constant BLOCKS_PER_YEAR u52560)
;; Precision for calculations
(define-constant PRECISION u10000)
;; Minimum deposit
(define-constant MIN_DEPOSIT u1000)  ;; 0.001 STX in micro-STX

;; Data Variables
(define-data-var total-vault-deposits uint u0)
(define-data-var total-shares uint u0)
(define-data-var is-initialized bool false)
(define-data-var last-yield-block uint u0)
(define-data-var accumulated-yield uint u0)

;; Data Maps
;; User shares in the vault
(define-map user-shares principal uint)
;; User deposit block for tracking
(define-map user-deposit-block principal uint)

;; Authorization check
(define-private (is-authorized)
  (is-eq tx-sender CONTRACT_OWNER)
)

;; Initialize the vault
(define-public (initialize)
  (begin
    (asserts! (is-authorized) ERR_UNAUTHORIZED)
    (asserts! (not (var-get is-initialized)) ERR_ALREADY_INITIALIZED)
    (var-set is-initialized true)
    (var-set last-yield-block block-height)
    (ok true)
  )
)

;; Read-only functions

;; Get user's share balance
(define-read-only (get-user-shares (user principal))
  (default-to u0 (map-get? user-shares user))
)

;; Calculate current share price (in micro-STX per share)
(define-read-only (get-share-price)
  (let (
    (total-shares-val (var-get total-shares))
    (total-assets (get-total-assets))
  )
    (if (is-eq total-shares-val u0)
      PRECISION  ;; 1:1 initial price
      (/ (* total-assets PRECISION) total-shares-val)
    )
  )
)

;; Calculate total assets including yield
(define-read-only (get-total-assets)
  (+ (var-get total-vault-deposits) (get-pending-yield))
)

;; Calculate pending yield since last update
(define-read-only (get-pending-yield)
  (let (
    (total-deposits (var-get total-vault-deposits))
    (last-block (var-get last-yield-block))
    (blocks-elapsed (- block-height last-block))
    (yield-per-block (/ VAULT_YIELD_RATE BLOCKS_PER_YEAR))
  )
    (+ (var-get accumulated-yield)
       (/ (* (* total-deposits yield-per-block) blocks-elapsed) PRECISION))
  )
)

;; Get user's STX value of their shares
(define-read-only (get-user-value (user principal))
  (let (
    (shares (get-user-shares user))
    (share-price (get-share-price))
  )
    (/ (* shares share-price) PRECISION)
  )
)

;; Calculate shares for a deposit amount
(define-read-only (calculate-shares-for-deposit (amount uint))
  (let (
    (total-shares-val (var-get total-shares))
    (total-assets (get-total-assets))
  )
    (if (is-eq total-shares-val u0)
      amount  ;; 1:1 for first deposit
      (/ (* amount total-shares-val) total-assets)
    )
  )
)

;; Calculate STX for a share redemption
(define-read-only (calculate-stx-for-shares (shares uint))
  (let (
    (total-shares-val (var-get total-shares))
    (total-assets (get-total-assets))
  )
    (if (is-eq total-shares-val u0)
      u0
      (/ (* shares total-assets) total-shares-val)
    )
  )
)

;; Get vault statistics
(define-read-only (get-vault-stats)
  {
    total-deposits: (var-get total-vault-deposits),
    total-shares: (var-get total-shares),
    total-assets: (get-total-assets),
    share-price: (get-share-price),
    pending-yield: (get-pending-yield),
    apy: VAULT_YIELD_RATE
  }
)

;; Internal: Update yield
(define-private (update-yield)
  (let (
    (pending (get-pending-yield))
  )
    (var-set accumulated-yield pending)
    (var-set last-yield-block block-height)
    pending
  )
)

;; Public functions

;; Deposit STX into the vault
(define-public (vault-deposit (amount uint))
  (let (
    (current-shares (get-user-shares tx-sender))
    (shares-to-mint (calculate-shares-for-deposit amount))
  )
    (asserts! (var-get is-initialized) ERR_NOT_INITIALIZED)
    (asserts! (>= amount MIN_DEPOSIT) ERR_INVALID_AMOUNT)
    
    ;; Update yield before deposit
    (update-yield)
    
    ;; Transfer STX to vault
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Mint shares to user
    (map-set user-shares tx-sender (+ current-shares shares-to-mint))
    (map-set user-deposit-block tx-sender block-height)
    
    ;; Update totals
    (var-set total-vault-deposits (+ (var-get total-vault-deposits) amount))
    (var-set total-shares (+ (var-get total-shares) shares-to-mint))
    
    (ok {
      deposited: amount,
      shares-minted: shares-to-mint,
      total-shares: (+ current-shares shares-to-mint)
    })
  )
)

;; Withdraw STX from the vault
(define-public (vault-withdraw (shares uint))
  (let (
    (current-shares (get-user-shares tx-sender))
    (stx-to-withdraw (calculate-stx-for-shares shares))
    (vault-balance (var-get total-vault-deposits))
  )
    (asserts! (var-get is-initialized) ERR_NOT_INITIALIZED)
    (asserts! (> shares u0) ERR_INVALID_AMOUNT)
    (asserts! (<= shares current-shares) ERR_INSUFFICIENT_BALANCE)
    (asserts! (<= stx-to-withdraw vault-balance) ERR_VAULT_EMPTY)
    
    ;; Update yield before withdrawal
    (update-yield)
    
    ;; Burn shares
    (let (
      (new-shares (- current-shares shares))
    )
      (if (is-eq new-shares u0)
        (begin
          (map-delete user-shares tx-sender)
          (map-delete user-deposit-block tx-sender)
        )
        (map-set user-shares tx-sender new-shares)
      )
      
      ;; Update totals
      (var-set total-shares (- (var-get total-shares) shares))
      (var-set total-vault-deposits (- (var-get total-vault-deposits) stx-to-withdraw))
      
      ;; Transfer STX to user
      (try! (as-contract (stx-transfer? stx-to-withdraw tx-sender tx-sender)))
      
      (ok {
        withdrawn: stx-to-withdraw,
        shares-burned: shares,
        remaining-shares: new-shares
      })
    )
  )
)

;; Withdraw all shares
(define-public (vault-withdraw-all)
  (let (
    (current-shares (get-user-shares tx-sender))
  )
    (asserts! (> current-shares u0) ERR_NO_DEPOSIT)
    (vault-withdraw current-shares)
  )
)

;; Admin: Add yield to the vault (simulates yield generation)
;; In production, this would come from actual yield sources
(define-public (add-yield (amount uint))
  (begin
    (asserts! (is-authorized) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Transfer yield to vault
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Add to accumulated yield
    (var-set accumulated-yield (+ (var-get accumulated-yield) amount))
    
    (ok amount)
  )
)

;; Admin: Emergency withdraw (only for stuck funds)
(define-public (emergency-withdraw (amount uint))
  (begin
    (asserts! (is-authorized) ERR_UNAUTHORIZED)
    (try! (as-contract (stx-transfer? amount tx-sender CONTRACT_OWNER)))
    (ok amount)
  )
)
