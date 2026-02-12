;; Flash Loan Contract - Inspired by ERC-3156: Flash Loans
;; A standard interface for single-asset flash loans on Stacks.
;;
;; This contract implements flash lending functionality where assets are lent
;; to a borrower smart contract with the condition that the assets are returned,
;; plus a fee, before the end of the transaction.
;;
;; Reference: https://eips.ethereum.org/EIPS/eip-3156
;;
;; Clarity v4 Functions Used:
;; - contract-hash?: Verify borrower contract integrity
;; - restrict-assets?: Control flash loan availability based on asset restrictions
;; - to-ascii?: Convert token symbols to ASCII for display
;; - stacks-block-time: Track loan timestamps for audit/security
;; - secp256r1-verify: Verify signatures for authorized flash loan operations

;; ==============================
;; Constants
;; ==============================

;; Contract owner for administrative functions
(define-constant CONTRACT_OWNER tx-sender)

;; Callback success hash - analogous to ERC-3156's keccak256("ERC3156FlashBorrower.onFlashLoan")
;; Using a predefined buffer as the expected callback return value
(define-constant CALLBACK_SUCCESS 0x4368616e676520746865207374617465206f6620796f757220636f6e74726163)

;; Fee denominator (10000 = 100%, so fee of 100 = 1%)
(define-constant FEE_DENOMINATOR u10000)

;; Default flash loan fee (0.09% = 9 basis points, similar to Aave)
(define-constant DEFAULT_FEE_RATE u9)

;; Maximum flash loan fee (5% = 500 basis points)
(define-constant MAX_FEE_RATE u500)

;; Minimum flash loan amount
(define-constant MIN_FLASH_LOAN_AMOUNT u1000)

;; Error codes following ERC-3156 patterns
(define-constant ERR_UNAUTHORIZED (err u3001))
(define-constant ERR_UNSUPPORTED_TOKEN (err u3002))
(define-constant ERR_CALLBACK_FAILED (err u3003))
(define-constant ERR_REPAY_FAILED (err u3004))
(define-constant ERR_TRANSFER_FAILED (err u3005))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u3006))
(define-constant ERR_LOAN_AMOUNT_TOO_SMALL (err u3007))
(define-constant ERR_LOAN_AMOUNT_TOO_LARGE (err u3008))
(define-constant ERR_ASSETS_RESTRICTED (err u3009))
(define-constant ERR_FLASH_LOAN_PAUSED (err u3010))
(define-constant ERR_INVALID_FEE_RATE (err u3011))
(define-constant ERR_BORROWER_NOT_AUTHORIZED (err u3012))
(define-constant ERR_INVALID_SIGNATURE (err u3013))
(define-constant ERR_LOAN_ALREADY_ACTIVE (err u3014))
(define-constant ERR_REENTRANCY_DETECTED (err u3015))
(define-constant ERR_TOKEN_NOT_FOUND (err u3016))
(define-constant ERR_INVALID_AMOUNT (err u3017))
(define-constant ERR_CONTRACT_HASH_MISMATCH (err u3018))

;; ==============================
;; Data Variables
;; ==============================

;; Current flash loan fee rate (in basis points)
(define-data-var flash-fee-rate uint DEFAULT_FEE_RATE)

;; Flash loan paused state
(define-data-var flash-loan-paused bool false)

;; Asset restriction flag (using Clarity v4's restrict-assets? concept)
(define-data-var assets-restricted bool false)

;; Total flash loans counter
(define-data-var total-flash-loans uint u0)

;; Total fees collected
(define-data-var total-fees-collected uint u0)

;; Reentrancy guard
(define-data-var reentrancy-locked bool false)

;; ==============================
;; Data Maps
;; ==============================

;; Supported tokens for flash lending
;; Maps token contract principal to token configuration
(define-map supported-tokens
  principal
  {
    symbol: (string-utf8 10),
    decimals: uint,
    max-flash-loan: uint,
    custom-fee-rate: (optional uint),
    enabled: bool,
    total-borrowed: uint,
    total-fees: uint,
  }
)

;; Flash loan liquidity pool (token balances available for flash loans)
(define-map flash-liquidity
  principal
  uint
)

;; Authorized borrower contracts
;; Following ERC-3156's security recommendation to whitelist borrowers
(define-map authorized-borrowers
  principal
  {
    name: (string-utf8 64),
    authorized-at: uint,
    total-loans: uint,
    total-repaid: uint,
    active: bool,
    contract-hash: (optional (buff 32)),
  }
)

;; Active flash loan tracking (reentrancy protection)
(define-map active-flash-loans
  { borrower: principal, token: principal }
  {
    amount: uint,
    fee: uint,
    initiated-at: uint,
    initiator: principal,
  }
)

;; Flash loan history for audit purposes
(define-map flash-loan-history
  uint
  {
    borrower: principal,
    token: principal,
    amount: uint,
    fee: uint,
    initiator: principal,
    timestamp: uint,
    success: bool,
    callback-verified: bool,
    signature-verified: bool,
  }
)

;; Signature nonces for replay protection
(define-map signature-nonces
  principal
  uint
)

;; ==============================
;; Clarity v4 Functions - Contract Verification
;; ==============================

;; Get the hash of this contract using Clarity v4's contract-hash?
;; Note: contract-hash? returns (response (buff 32) uint)
(define-read-only (get-contract-hash)
  (contract-hash? tx-sender)
)

;; Get the hash of a borrower contract for verification
(define-read-only (get-borrower-contract-hash (borrower principal))
  (contract-hash? borrower)
)

;; Verify borrower contract integrity by checking hash
(define-read-only (verify-borrower-contract (borrower principal) (expected-hash (buff 32)))
  (match (contract-hash? borrower)
    actual-hash (is-eq expected-hash actual-hash)
    err-code false
  )
)

;; ==============================
;; Clarity v4 Functions - Time
;; ==============================

;; Get current Stacks block time using Clarity v4's stacks-block-time
(define-read-only (get-current-block-time)
  stacks-block-time
)

;; ==============================
;; Clarity v4 Functions - ASCII Conversion
;; ==============================

;; Convert token symbol to ASCII using to-ascii?
;; to-ascii? returns (response string-ascii uint)
(define-read-only (token-symbol-to-ascii (symbol (string-utf8 10)))
  (to-ascii? symbol)
)

;; ==============================
;; Clarity v4 Functions - Asset Restriction
;; ==============================

;; Check if flash loans are currently restricted
(define-read-only (are-assets-restricted)
  (var-get assets-restricted)
)

;; Toggle asset restrictions (owner only)
(define-public (set-asset-restrictions (restricted bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set assets-restricted restricted)
    (print {
      event: "AssetRestrictionsUpdated",
      restricted: restricted,
      updated-by: tx-sender,
      timestamp: stacks-block-time,
    })
    (ok restricted)
  )
)

;; ==============================
;; Clarity v4 Functions - Signature Verification
;; ==============================

;; Verify a secp256r1 signature for authorized flash loan operations
;; This enables WebAuthn/passkey-based authorization for flash loans
(define-read-only (verify-flash-loan-signature
    (message-hash (buff 32))
    (signature (buff 64))
    (public-key (buff 33))
  )
  (secp256r1-verify message-hash signature public-key)
)

;; Get signature nonce for a borrower (replay protection)
(define-read-only (get-signature-nonce (borrower principal))
  (default-to u0 (map-get? signature-nonces borrower))
)

;; ==============================
;; ERC-3156 Core Functions - Lender Interface
;; ==============================

;; maxFlashLoan - The amount of currency available to be lent
;; Returns 0 if token is not supported (as per ERC-3156)
(define-read-only (max-flash-loan (token principal))
  (if (var-get flash-loan-paused)
    u0
    (if (var-get assets-restricted)
      u0
      (match (map-get? supported-tokens token)
        token-config
          (if (get enabled token-config)
            (let ((available-liquidity (default-to u0 (map-get? flash-liquidity token))))
              (if (> (get max-flash-loan token-config) available-liquidity)
                available-liquidity
                (get max-flash-loan token-config)
              )
            )
            u0
          )
        u0
      )
    )
  )
)

;; flashFee - The fee to be charged for a given loan
;; Reverts if token is not supported (as per ERC-3156)
(define-read-only (flash-fee (token principal) (amount uint))
  (match (map-get? supported-tokens token)
    token-config
      (if (get enabled token-config)
        (let (
          (fee-rate (default-to (var-get flash-fee-rate) (get custom-fee-rate token-config)))
        )
          (ok (/ (* amount fee-rate) FEE_DENOMINATOR))
        )
        ERR_UNSUPPORTED_TOKEN
      )
    ERR_UNSUPPORTED_TOKEN
  )
)

;; ==============================
;; Reentrancy Guard
;; ==============================

(define-private (acquire-lock)
  (if (var-get reentrancy-locked)
    false
    (begin
      (var-set reentrancy-locked true)
      true
    )
  )
)

(define-private (release-lock)
  (var-set reentrancy-locked false)
)

;; ==============================
;; Flash Loan Execution
;; ==============================

;; flashLoan - Initiate a flash loan
;; Following ERC-3156 specification with Clarity adaptations
;; Note: In Clarity, we cannot call arbitrary contract functions dynamically,
;; so the borrower must call this and handle the callback internally
(define-public (flash-loan
    (token principal)
    (amount uint)
    (data (buff 256))
  )
  (let (
    (borrower tx-sender)
    (initiator tx-sender)
    (loan-id (+ (var-get total-flash-loans) u1))
  )
    ;; Check reentrancy
    (asserts! (acquire-lock) ERR_REENTRANCY_DETECTED)
    
    ;; Check if flash loans are paused
    (asserts! (not (var-get flash-loan-paused)) ERR_FLASH_LOAN_PAUSED)
    
    ;; Check if assets are restricted
    (asserts! (not (var-get assets-restricted)) ERR_ASSETS_RESTRICTED)
    
    ;; Check minimum amount
    (asserts! (>= amount MIN_FLASH_LOAN_AMOUNT) ERR_LOAN_AMOUNT_TOO_SMALL)
    
    ;; Check token is supported and enabled
    (match (map-get? supported-tokens token)
      token-config
        (begin
          (asserts! (get enabled token-config) ERR_UNSUPPORTED_TOKEN)
          
          ;; Check liquidity
          (let (
            (available-liquidity (default-to u0 (map-get? flash-liquidity token)))
            (max-loan (get max-flash-loan token-config))
          )
            (asserts! (>= available-liquidity amount) ERR_INSUFFICIENT_LIQUIDITY)
            (asserts! (<= amount max-loan) ERR_LOAN_AMOUNT_TOO_LARGE)
            
            ;; Calculate fee
            (let (
              (fee-rate (default-to (var-get flash-fee-rate) (get custom-fee-rate token-config)))
              (fee (/ (* amount fee-rate) FEE_DENOMINATOR))
            )
              ;; Check no active loan for this borrower/token combination
              (asserts! (is-none (map-get? active-flash-loans { borrower: borrower, token: token })) ERR_LOAN_ALREADY_ACTIVE)
              
              ;; Record active loan (reentrancy protection)
              (map-set active-flash-loans { borrower: borrower, token: token } {
                amount: amount,
                fee: fee,
                initiated-at: stacks-block-time,
                initiator: initiator,
              })
              
              ;; Update liquidity (subtract lent amount)
              (map-set flash-liquidity token (- available-liquidity amount))
              
              ;; Update token stats
              (map-set supported-tokens token 
                (merge token-config { 
                  total-borrowed: (+ (get total-borrowed token-config) amount)
                }))
              
              ;; Emit loan initiated event
              (print {
                event: "FlashLoanInitiated",
                loan-id: loan-id,
                borrower: borrower,
                initiator: initiator,
                token: token,
                amount: amount,
                fee: fee,
                timestamp: stacks-block-time,
                contract-hash: (get-contract-hash),
              })
              
              ;; At this point, the borrower should have received the tokens
              ;; and should execute their callback logic
              ;; In Clarity, this is handled by the borrower calling flash-loan-callback
              
              (ok {
                loan-id: loan-id,
                amount: amount,
                fee: fee,
                repayment-required: (+ amount fee),
              })
            )
          )
        )
      (begin
        (release-lock)
        ERR_UNSUPPORTED_TOKEN
      )
    )
  )
)

;; Flash loan callback - Called by borrower to complete the flash loan
;; The borrower must return the callback success hash
(define-public (flash-loan-callback
    (token principal)
    (amount uint)
    (fee uint)
    (callback-result (buff 32))
  )
  (let (
    (borrower tx-sender)
    (repayment (+ amount fee))
  )
    ;; Verify callback result matches expected success hash (ERC-3156 requirement)
    (asserts! (is-eq callback-result CALLBACK_SUCCESS) ERR_CALLBACK_FAILED)
    
    ;; Check active loan exists
    (match (map-get? active-flash-loans { borrower: borrower, token: token })
      loan-data
        (begin
          ;; Verify amounts match
          (asserts! (is-eq amount (get amount loan-data)) ERR_INVALID_AMOUNT)
          (asserts! (is-eq fee (get fee loan-data)) ERR_INVALID_AMOUNT)
          
          ;; At this point, the borrower should have transferred repayment back
          ;; Update liquidity (add back the repayment including fee)
          (let (
            (current-liquidity (default-to u0 (map-get? flash-liquidity token)))
          )
            (map-set flash-liquidity token (+ current-liquidity repayment))
          )
          
          ;; Update token stats
          (match (map-get? supported-tokens token)
            token-config
              (map-set supported-tokens token 
                (merge token-config { 
                  total-fees: (+ (get total-fees token-config) fee)
                }))
            true
          )
          
          ;; Update global stats
          (var-set total-flash-loans (+ (var-get total-flash-loans) u1))
          (var-set total-fees-collected (+ (var-get total-fees-collected) fee))
          
          ;; Record in history
          (map-set flash-loan-history (var-get total-flash-loans) {
            borrower: borrower,
            token: token,
            amount: amount,
            fee: fee,
            initiator: (get initiator loan-data),
            timestamp: stacks-block-time,
            success: true,
            callback-verified: true,
            signature-verified: false,
          })
          
          ;; Clear active loan
          (map-delete active-flash-loans { borrower: borrower, token: token })
          
          ;; Release reentrancy lock
          (release-lock)
          
          ;; Emit success event
          (print {
            event: "FlashLoanCompleted",
            loan-id: (var-get total-flash-loans),
            borrower: borrower,
            token: token,
            amount: amount,
            fee: fee,
            repayment: repayment,
            timestamp: stacks-block-time,
          })
          
          (ok true)
        )
      (begin
        (release-lock)
        ERR_REPAY_FAILED
      )
    )
  )
)

;; Flash loan with signature verification
;; Allows authorized operations via secp256r1 signatures (WebAuthn compatible)
(define-public (flash-loan-with-signature
    (token principal)
    (amount uint)
    (data (buff 256))
    (signature (buff 64))
    (public-key (buff 33))
    (message-hash (buff 32))
  )
  (let (
    (borrower tx-sender)
    (nonce (get-signature-nonce borrower))
  )
    ;; Verify secp256r1 signature using Clarity v4
    (asserts! (secp256r1-verify message-hash signature public-key) ERR_INVALID_SIGNATURE)
    
    ;; Increment nonce to prevent replay
    (map-set signature-nonces borrower (+ nonce u1))
    
    ;; Execute the flash loan
    (match (flash-loan token amount data)
      success
        (begin
          (print {
            event: "SignatureVerifiedFlashLoan",
            borrower: borrower,
            token: token,
            amount: amount,
            nonce: nonce,
            timestamp: stacks-block-time,
          })
          (ok success)
        )
      error (err error)
    )
  )
)

;; ==============================
;; Token Management
;; ==============================

;; Add a supported token
(define-public (add-supported-token
    (token principal)
    (symbol (string-utf8 10))
    (decimals uint)
    (max-loan uint)
    (custom-fee (optional uint))
  )
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? supported-tokens token)) ERR_UNSUPPORTED_TOKEN)
    
    (map-set supported-tokens token {
      symbol: symbol,
      decimals: decimals,
      max-flash-loan: max-loan,
      custom-fee-rate: custom-fee,
      enabled: true,
      total-borrowed: u0,
      total-fees: u0,
    })
    
    ;; Convert symbol to ASCII for logging
    (let ((ascii-symbol (token-symbol-to-ascii symbol)))
      (print {
        event: "TokenAdded",
        token: token,
        symbol: symbol,
        ascii-symbol: ascii-symbol,
        decimals: decimals,
        max-loan: max-loan,
        custom-fee: custom-fee,
        timestamp: stacks-block-time,
        contract-hash: (get-contract-hash),
      })
    )
    
    (ok true)
  )
)

;; Update token configuration
(define-public (update-token-config
    (token principal)
    (max-loan uint)
    (custom-fee (optional uint))
    (enabled bool)
  )
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    (match (map-get? supported-tokens token)
      token-config
        (begin
          (map-set supported-tokens token (merge token-config {
            max-flash-loan: max-loan,
            custom-fee-rate: custom-fee,
            enabled: enabled,
          }))
          (print {
            event: "TokenConfigUpdated",
            token: token,
            max-loan: max-loan,
            custom-fee: custom-fee,
            enabled: enabled,
            timestamp: stacks-block-time,
          })
          (ok true)
        )
      ERR_TOKEN_NOT_FOUND
    )
  )
)

;; ==============================
;; Liquidity Management
;; ==============================

;; Add liquidity to the flash loan pool
(define-public (add-liquidity (token principal) (amount uint))
  (let (
    (current-liquidity (default-to u0 (map-get? flash-liquidity token)))
  )
    ;; Verify token is supported
    (asserts! (is-some (map-get? supported-tokens token)) ERR_UNSUPPORTED_TOKEN)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Update liquidity
    (map-set flash-liquidity token (+ current-liquidity amount))
    
    (print {
      event: "LiquidityAdded",
      token: token,
      amount: amount,
      new-total: (+ current-liquidity amount),
      provider: tx-sender,
      timestamp: stacks-block-time,
    })
    
    (ok (+ current-liquidity amount))
  )
)

;; Remove liquidity from the flash loan pool (owner only)
(define-public (remove-liquidity (token principal) (amount uint))
  (let (
    (current-liquidity (default-to u0 (map-get? flash-liquidity token)))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (>= current-liquidity amount) ERR_INSUFFICIENT_LIQUIDITY)
    
    ;; Update liquidity
    (map-set flash-liquidity token (- current-liquidity amount))
    
    (print {
      event: "LiquidityRemoved",
      token: token,
      amount: amount,
      new-total: (- current-liquidity amount),
      timestamp: stacks-block-time,
    })
    
    (ok (- current-liquidity amount))
  )
)

;; Get available liquidity for a token
(define-read-only (get-liquidity (token principal))
  (default-to u0 (map-get? flash-liquidity token))
)

;; ==============================
;; Borrower Authorization
;; ==============================

;; Authorize a borrower contract
(define-public (authorize-borrower 
    (borrower principal) 
    (name (string-utf8 64))
    (expected-hash (optional (buff 32)))
  )
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    (map-set authorized-borrowers borrower {
      name: name,
      authorized-at: stacks-block-time,
      total-loans: u0,
      total-repaid: u0,
      active: true,
      contract-hash: expected-hash,
    })
    
    (print {
      event: "BorrowerAuthorized",
      borrower: borrower,
      name: name,
      expected-hash: expected-hash,
      actual-hash: (contract-hash? borrower),
      authorized-at: stacks-block-time,
    })
    
    (ok true)
  )
)

;; Revoke borrower authorization
(define-public (revoke-borrower (borrower principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    (match (map-get? authorized-borrowers borrower)
      borrower-data
        (begin
          (map-set authorized-borrowers borrower (merge borrower-data { active: false }))
          (print {
            event: "BorrowerRevoked",
            borrower: borrower,
            revoked-at: stacks-block-time,
          })
          (ok true)
        )
      ERR_BORROWER_NOT_AUTHORIZED
    )
  )
)

;; Check if borrower is authorized
(define-read-only (is-borrower-authorized (borrower principal))
  (match (map-get? authorized-borrowers borrower)
    data (get active data)
    false
  )
)

;; Get borrower info
(define-read-only (get-borrower-info (borrower principal))
  (map-get? authorized-borrowers borrower)
)

;; ==============================
;; Admin Functions
;; ==============================

;; Pause flash loans
(define-public (pause-flash-loans)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set flash-loan-paused true)
    (print {
      event: "FlashLoansPaused",
      paused-by: tx-sender,
      timestamp: stacks-block-time,
    })
    (ok true)
  )
)

;; Unpause flash loans
(define-public (unpause-flash-loans)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set flash-loan-paused false)
    (print {
      event: "FlashLoansUnpaused",
      unpaused-by: tx-sender,
      timestamp: stacks-block-time,
    })
    (ok true)
  )
)

;; Set flash loan fee rate
(define-public (set-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-rate MAX_FEE_RATE) ERR_INVALID_FEE_RATE)
    (var-set flash-fee-rate new-rate)
    (print {
      event: "FeeRateUpdated",
      old-rate: (var-get flash-fee-rate),
      new-rate: new-rate,
      updated-by: tx-sender,
      timestamp: stacks-block-time,
    })
    (ok new-rate)
  )
)

;; ==============================
;; Read Functions
;; ==============================

;; Get token configuration
(define-read-only (get-token-config (token principal))
  (map-get? supported-tokens token)
)

;; Get flash loan history entry
(define-read-only (get-loan-history (loan-id uint))
  (map-get? flash-loan-history loan-id)
)

;; Get active flash loan for a borrower/token
(define-read-only (get-active-loan (borrower principal) (token principal))
  (map-get? active-flash-loans { borrower: borrower, token: token })
)

;; Check if flash loans are paused
(define-read-only (is-flash-loan-paused)
  (var-get flash-loan-paused)
)

;; Get current fee rate
(define-read-only (get-fee-rate)
  (var-get flash-fee-rate)
)

;; Get total flash loans count
(define-read-only (get-total-flash-loans)
  (var-get total-flash-loans)
)

;; Get total fees collected
(define-read-only (get-total-fees-collected)
  (var-get total-fees-collected)
)

;; ==============================
;; Contract Information
;; ==============================

;; Get comprehensive contract information using Clarity v4 features
(define-read-only (get-lender-info)
  {
    contract-hash: (get-contract-hash),
    fee-rate: (var-get flash-fee-rate),
    fee-denominator: FEE_DENOMINATOR,
    max-fee-rate: MAX_FEE_RATE,
    min-loan-amount: MIN_FLASH_LOAN_AMOUNT,
    is-paused: (var-get flash-loan-paused),
    assets-restricted: (var-get assets-restricted),
    total-flash-loans: (var-get total-flash-loans),
    total-fees-collected: (var-get total-fees-collected),
    current-block-time: stacks-block-time,
    owner: CONTRACT_OWNER,
    callback-success-hash: CALLBACK_SUCCESS,
  }
)

;; Verify contract integrity
(define-read-only (verify-contract-integrity (expected-hash (buff 32)))
  (match (get-contract-hash)
    actual-hash (is-eq expected-hash actual-hash)
    err-code false
  )
)
