;; This contract implements the SIP-010 community-standard Fungible Token trait.
;; Enhanced with allowance system, comprehensive events, and improved error handling.

;; Define the FT, with no maximum supply
(define-fungible-token clarity-coin)

;; ===== ERROR CODES =====

;; Authorization errors (100-109)
(define-constant ERR_OWNER_ONLY (err u100))
(define-constant ERR_NOT_TOKEN_OWNER (err u101))
(define-constant ERR_UNAUTHORIZED (err u102))

;; Transfer errors (110-119)
(define-constant ERR_INSUFFICIENT_BALANCE (err u110))
(define-constant ERR_INSUFFICIENT_ALLOWANCE (err u111))
(define-constant ERR_INVALID_AMOUNT (err u112))
(define-constant ERR_INVALID_RECIPIENT (err u113))
(define-constant ERR_SELF_TRANSFER (err u114))

;; Allowance errors (120-129)
(define-constant ERR_ALLOWANCE_OVERFLOW (err u120))
(define-constant ERR_ALLOWANCE_UNDERFLOW (err u121))

;; General errors (130-139)
(define-constant ERR_INVALID_PARAMETER (err u130))
(define-constant ERR_CONTRACT_PAUSED (err u131))

;; ===== CONSTANTS =====

(define-constant CONTRACT_OWNER tx-sender)
(define-constant TOKEN_NAME "Clarity Coin")
(define-constant TOKEN_SYMBOL "CC")
(define-constant TOKEN_DECIMALS u6) ;; 6 units displayed past decimal, e.g. 1.000_000 = 1 token
(define-constant MAX_UINT u340282366920938463463374607431768211455) ;; Max uint value

;; ===== DATA VARIABLES =====

(define-data-var token-uri (string-utf8 256) u"https://hiro.so") ;; utf-8 string with token metadata host
(define-data-var contract-paused bool false)

;; ===== DATA MAPS =====

;; Allowances: owner -> spender -> amount
(define-map allowances {owner: principal, spender: principal} uint)

;; ===== HELPER FUNCTIONS =====

;; Check if contract is not paused
(define-private (assert-not-paused)
  (begin
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (ok true)
  )
)

;; Validate amount is greater than zero
(define-private (is-valid-amount (amount uint))
  (> amount u0)
)

;; Validate recipient is not the same as sender
(define-private (is-valid-recipient (sender principal) (recipient principal))
  (not (is-eq sender recipient))
)

;; Check if caller is contract owner
(define-private (is-contract-owner (caller principal))
  (is-eq caller CONTRACT_OWNER)
)

;; ===== EVENT LOGGING FUNCTIONS =====

;; Log transfer event
(define-private (log-transfer (from principal) (to principal) (amount uint))
  (print {
    event: "transfer",
    from: from,
    to: to,
    amount: amount
  })
)

;; Log mint event
(define-private (log-mint (to principal) (amount uint))
  (print {
    event: "mint",
    to: to,
    amount: amount,
    total-supply: (ft-get-supply clarity-coin)
  })
)

;; Log approval event
(define-private (log-approval (owner principal) (spender principal) (amount uint))
  (print {
    event: "approval",
    owner: owner,
    spender: spender,
    amount: amount
  })
)

;; Log burn event
(define-private (log-burn (from principal) (amount uint))
  (print {
    event: "burn",
    from: from,
    amount: amount,
    total-supply: (ft-get-supply clarity-coin)
  })
)


;; ===== EVENT HELPERS =====

;; Emit transfer event
(define-private (emit-transfer-event (from principal) (to principal) (amount uint))
  (print {
    event: "transfer",
    from: from,
    to: to,
    amount: amount
  })
)

;; Emit approval event
(define-private (emit-approval-event (owner principal) (spender principal) (amount uint))
  (print {
    event: "approval",
    owner: owner,
    spender: spender,
    amount: amount
  })
)

;; Emit mint event
(define-private (emit-mint-event (to principal) (amount uint))
  (print {
    event: "mint",
    to: to,
    amount: amount,
    total-supply: (ft-get-supply clarity-coin)
  })
)

;; ===== READ-ONLY FUNCTIONS =====
(define-read-only (get-balance (who principal))
  (ok (ft-get-balance clarity-coin who))
)

;; SIP-010 function: Returns the total supply of fungible token
(define-read-only (get-total-supply)
  (ok (ft-get-supply clarity-coin))
)

;; SIP-010 function: Returns the human-readable token name
(define-read-only (get-name)
  (ok TOKEN_NAME)
)

;; SIP-010 function: Returns the symbol or "ticker" for this token
(define-read-only (get-symbol)
  (ok TOKEN_SYMBOL)
)

;; SIP-010 function: Returns number of decimals to display
(define-read-only (get-decimals)
  (ok TOKEN_DECIMALS)
)

;; SIP-010 function: Returns the URI containing token metadata
(define-read-only (get-token-uri)
  (ok (some (var-get token-uri)))
)

;; ===== ALLOWANCE READ-ONLY FUNCTIONS =====

;; Get allowance amount for spender from owner
(define-read-only (get-allowance (owner principal) (spender principal))
  (ok (default-to u0 (map-get? allowances {owner: owner, spender: spender})))
)

;; Check if spender has sufficient allowance
(define-read-only (has-allowance (owner principal) (spender principal) (amount uint))
  (let ((current-allowance (default-to u0 (map-get? allowances {owner: owner, spender: spender}))))
    (ok (>= current-allowance amount))
  )
)

;; Get contract pause status
(define-read-only (get-contract-paused)
  (ok (var-get contract-paused))
)

;; ===== ALLOWANCE FUNCTIONS =====

;; Approve spender to spend amount on behalf of owner
(define-public (approve (spender principal) (amount uint))
  (begin
    ;; Validation
    (try! (assert-not-paused))
    (asserts! (not (is-eq tx-sender spender)) ERR_INVALID_RECIPIENT)
    (asserts! (<= amount MAX_UINT) ERR_ALLOWANCE_OVERFLOW)
    
    ;; Set allowance
    (map-set allowances {owner: tx-sender, spender: spender} amount)
    
    ;; Log event
    (log-approval tx-sender spender amount)
    
    (ok true)
  )
)

;; Increase allowance by amount
(define-public (increase-allowance (spender principal) (amount uint))
  (let ((current-allowance (default-to u0 (map-get? allowances {owner: tx-sender, spender: spender}))))
    (begin
      ;; Validation
      (try! (assert-not-paused))
      (asserts! (not (is-eq tx-sender spender)) ERR_INVALID_RECIPIENT)
      (asserts! (is-valid-amount amount) ERR_INVALID_AMOUNT)
      (asserts! (<= (+ current-allowance amount) MAX_UINT) ERR_ALLOWANCE_OVERFLOW)
      
      ;; Update allowance
      (let ((new-allowance (+ current-allowance amount)))
        (map-set allowances {owner: tx-sender, spender: spender} new-allowance)
        
        ;; Log event
        (log-approval tx-sender spender new-allowance)
        
        (ok true)
      )
    )
  )
)

;; Decrease allowance by amount
(define-public (decrease-allowance (spender principal) (amount uint))
  (let ((current-allowance (default-to u0 (map-get? allowances {owner: tx-sender, spender: spender}))))
    (begin
      ;; Validation
      (try! (assert-not-paused))
      (asserts! (not (is-eq tx-sender spender)) ERR_INVALID_RECIPIENT)
      (asserts! (is-valid-amount amount) ERR_INVALID_AMOUNT)
      (asserts! (>= current-allowance amount) ERR_ALLOWANCE_UNDERFLOW)
      
      ;; Update allowance
      (let ((new-allowance (- current-allowance amount)))
        (map-set allowances {owner: tx-sender, spender: spender} new-allowance)
        
        ;; Log event
        (log-approval tx-sender spender new-allowance)
        
        (ok true)
      )
    )
  )
)

;; Transfer tokens from owner to recipient using allowance
(define-public (transfer-from 
  (owner principal) 
  (recipient principal) 
  (amount uint) 
  (memo (optional (buff 34)))
)
  (let (
    (current-allowance (default-to u0 (map-get? allowances {owner: owner, spender: tx-sender})))
    (owner-balance (ft-get-balance clarity-coin owner))
  )
    (begin
      ;; Validation
      (try! (assert-not-paused))
      (asserts! (is-valid-amount amount) ERR_INVALID_AMOUNT)
      (asserts! (is-valid-recipient owner recipient) ERR_SELF_TRANSFER)
      (asserts! (>= owner-balance amount) ERR_INSUFFICIENT_BALANCE)
      (asserts! (>= current-allowance amount) ERR_INSUFFICIENT_ALLOWANCE)
      
      ;; Execute transfer
      (try! (ft-transfer? clarity-coin amount owner recipient))
      
      ;; Update allowance
      (map-set allowances {owner: owner, spender: tx-sender} (- current-allowance amount))
      
      ;; Log events
      (log-transfer owner recipient amount)
      (log-approval owner tx-sender (- current-allowance amount))
      
      ;; Handle memo
      (match memo to-print (print to-print) 0x)
      
      (ok true)
    )
  )
)

;; Properly updates token URI by emitting a SIP-019 token metadata update notification
(define-public (set-token-uri (value (string-utf8 256)))
    (begin
        ;; Validation
        (try! (assert-not-paused))
        (asserts! (is-contract-owner tx-sender) ERR_OWNER_ONLY)
        (asserts! (> (len value) u0) ERR_INVALID_PARAMETER)
        
        ;; Update URI
        (var-set token-uri value)
        
        ;; Log events
        (print {
          event: "token-uri-updated",
          new-uri: value,
          admin: tx-sender
        })
        
        ;; Emit SIP-019 notification
        (print {
          notification: "token-metadata-update",
          payload: {
            contract-id: CONTRACT_OWNER,
            token-class: "ft"
          }
        })
        
        (ok true)
    )
)

;; Mint new tokens and send them to a recipient.
;; Only the contract deployer can perform this operation.
(define-public (mint (amount uint) (recipient principal))
  (begin
    ;; Validation
    (try! (assert-not-paused))
    (asserts! (is-contract-owner tx-sender) ERR_OWNER_ONLY)
    (asserts! (is-valid-amount amount) ERR_INVALID_AMOUNT)
    (asserts! (not (is-eq recipient tx-sender)) ERR_INVALID_RECIPIENT)
    
    ;; Execute mint
    (try! (ft-mint? clarity-coin amount recipient))
    
    ;; Log event
    (log-mint recipient amount)
    
    (ok true)
  )
)

;; SIP-010 function: Transfers tokens to a recipient
;; Sender must be the same as the caller to prevent principals from transferring tokens they do not own.
(define-public (transfer
  (amount uint)
  (sender principal)
  (recipient principal)
  (memo (optional (buff 34)))
)
  (begin
    ;; Validation
    (try! (assert-not-paused))
    (asserts! (or (is-eq tx-sender sender) (is-eq contract-caller sender)) ERR_NOT_TOKEN_OWNER)
    (asserts! (is-valid-amount amount) ERR_INVALID_AMOUNT)
    (asserts! (is-valid-recipient sender recipient) ERR_SELF_TRANSFER)
    (asserts! (>= (ft-get-balance clarity-coin sender) amount) ERR_INSUFFICIENT_BALANCE)
    
    ;; Execute transfer
    (try! (ft-transfer? clarity-coin amount sender recipient))
    
    ;; Log event
    (log-transfer sender recipient amount)
    
    ;; Handle memo
    (match memo to-print (print to-print) 0x)
    
    (ok true)
  )
)

;; ===== BURN FUNCTION =====

;; Burn tokens from caller's balance
(define-public (burn (amount uint))
  (let ((caller-balance (ft-get-balance clarity-coin tx-sender)))
    (begin
      ;; Validation
      (try! (assert-not-paused))
      (asserts! (is-valid-amount amount) ERR_INVALID_AMOUNT)
      (asserts! (>= caller-balance amount) ERR_INSUFFICIENT_BALANCE)
      
      ;; Execute burn
      (try! (ft-burn? clarity-coin amount tx-sender))
      
      ;; Log event
      (log-burn tx-sender amount)
      
      (ok true)
    )
  )
)

;; ===== ADMINISTRATIVE FUNCTIONS =====

;; Pause/unpause contract (owner only)
(define-public (set-contract-paused (paused bool))
  (begin
    (asserts! (is-contract-owner tx-sender) ERR_OWNER_ONLY)
    (var-set contract-paused paused)
    
    ;; Log event
    (print {
      event: "contract-pause-changed",
      paused: paused,
      admin: tx-sender
    })
    
    (ok true)
  )
)

;; ===== CONTRACT INFO FUNCTIONS =====

;; Get comprehensive contract information
(define-read-only (get-contract-info)
  (ok {
    name: TOKEN_NAME,
    symbol: TOKEN_SYMBOL,
    decimals: TOKEN_DECIMALS,
    total-supply: (ft-get-supply clarity-coin),
    contract-owner: CONTRACT_OWNER,
    contract-paused: (var-get contract-paused),
    token-uri: (var-get token-uri),
    version: u"2.0.0"
  })
)

;; Get user's complete token information
(define-read-only (get-user-info (user principal))
  (ok {
    balance: (ft-get-balance clarity-coin user),
    is-contract-owner: (is-eq user CONTRACT_OWNER)
  })
)

;; Get allowance information for multiple spenders
(define-read-only (get-allowances (owner principal) (spenders (list 10 principal)))
  (ok (map get-single-allowance 
    (map create-allowance-key 
      (list owner owner owner owner owner owner owner owner owner owner) 
      spenders)))
)

;; Helper for batch allowance queries
(define-private (create-allowance-key (owner principal) (spender principal))
  {owner: owner, spender: spender}
)

(define-private (get-single-allowance (key {owner: principal, spender: principal}))
  {
    spender: (get spender key),
    allowance: (default-to u0 (map-get? allowances key))
  }
)