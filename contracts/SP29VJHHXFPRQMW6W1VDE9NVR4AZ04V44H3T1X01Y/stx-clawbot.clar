;; STX-Clawbot: A Wallet Contract for Bot-Based STX Management
;; Allows any bot to deposit, withdraw, and spend STX

;; Define error codes
(define-constant ERR-INVALID-AMOUNT (err u4))
(define-constant ERR-INSUFFICIENT-BALANCE (err u2))

;; Data storage for account balances
(define-map balances
  { account: principal }
  { amount: uint }
)

;; Data storage for authorized bots (optional - if you want to restrict which bots can spend)
(define-map authorized-bots
  { bot: principal }
  { active: bool }
)

;; Track total deposits for stats
(define-data-var total-deposits uint u0)

;; ============================================================================
;; Public Functions
;; ============================================================================

;; Deposit STX into the wallet
;; Any account can deposit STX
(define-public (deposit (amount uint))
  (begin
    ;; Validate amount
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    ;; Update balance (STX received via stx-transfer? call)
    (map-set balances
      { account: tx-sender }
      { amount: (+ (get-balance tx-sender) amount) }
    )
    ;; Update total deposits
    (var-set total-deposits (+ (var-get total-deposits) amount))
    (ok amount)
  )
)

;; Withdraw STX from the wallet
;; Only the account owner can withdraw their own funds
(define-public (withdraw (amount uint))
  (begin
    ;; Validate amount
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    ;; Check balance
    (asserts! (>= (get-balance tx-sender) amount) ERR-INSUFFICIENT-BALANCE)
    ;; Transfer STX from contract to sender
    (try! (stx-transfer? amount tx-sender tx-sender))
    ;; Update balance
    (map-set balances
      { account: tx-sender }
      { amount: (- (get-balance tx-sender) amount) }
    )
    (ok amount)
  )
)

;; Bot spend function - allows bots to withdraw and send STX to a recipient
;; Any bot can call this, but it deducts from the caller's balance
(define-public (bot-spend (amount uint) (recipient principal))
  (begin
    ;; Validate amount
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    ;; Check bot's balance
    (asserts! (>= (get-balance tx-sender) amount) ERR-INSUFFICIENT-BALANCE)
    ;; Transfer STX from contract to recipient
    (try! (stx-transfer? amount tx-sender recipient))
    ;; Deduct from bot's balance
    (map-set balances
      { account: tx-sender }
      { amount: (- (get-balance tx-sender) amount) }
    )
    (ok amount)
  )
)

;; Transfer STX between accounts within the wallet
;; Allows users to send their balance to other accounts
(define-public (transfer (amount uint) (recipient principal))
  (begin
    ;; Validate amount
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    ;; Check sender's balance
    (asserts! (>= (get-balance tx-sender) amount) ERR-INSUFFICIENT-BALANCE)
    ;; Deduct from sender
    (map-set balances
      { account: tx-sender }
      { amount: (- (get-balance tx-sender) amount) }
    )
    ;; Add to recipient
    (map-set balances
      { account: recipient }
      { amount: (+ (get-balance recipient) amount) }
    )
    (ok amount)
  )
)

;; Authorize a bot (optional - for tracking approved bots)
(define-public (authorize-bot (bot principal))
  (begin
    (map-set authorized-bots { bot: bot } { active: true })
    (ok true)
  )
)

;; Revoke bot authorization
(define-public (revoke-bot (bot principal))
  (begin
    (map-delete authorized-bots { bot: bot })
    (ok true)
  )
)

;; ============================================================================
;; Read-Only Functions
;; ============================================================================

;; Get the balance of an account
(define-read-only (get-balance (account principal))
  (default-to u0 (get amount (map-get? balances { account: account })))
)

;; Check if a bot is authorized
(define-read-only (is-bot-authorized (bot principal))
  (default-to false (get active (map-get? authorized-bots { bot: bot })))
)

;; Get total deposits
(define-read-only (get-total-deposits)
  (var-get total-deposits)
)
