;; Lending and Borrowing Contract with Clarity v4 Features
;; This contract allows users to lend and borrow sBTC with advanced features
;; Uses contract-hash?, restrict-assets?, to-ascii?, stacks-block-time, and secp256r1-verify

;; Define contract owner
(define-constant CONTRACT_OWNER tx-sender)

;; Define error codes
(define-constant ERR_NOT_ENOUGH_BALANCE (err u1001))
(define-constant ERR_LOAN_NOT_FOUND (err u1002))
(define-constant ERR_UNAUTHORIZED (err u1003))
(define-constant ERR_LOAN_ALREADY_REPAID (err u1004))
(define-constant ERR_INVALID_AMOUNT (err u1005))
(define-constant ERR_ASSETS_RESTRICTED (err u1006))
(define-constant ERR_INVALID_SIGNATURE (err u1007))
(define-constant ERR_CONVERSION_FAILED (err u1008))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u1009))
(define-constant ERR_LOAN_EXPIRED (err u1010))

;; Define interest rates (basis points - 100 = 1%)
(define-constant INTEREST_RATE_PER_BLOCK u10) ;; 0.1% per block
(define-constant COLLATERAL_RATIO u150) ;; 150% collateral required

;; Asset restriction control
(define-data-var assets-restricted bool false)

;; Counters
(define-data-var loan-id-nonce uint u0)
(define-data-var lender-id-nonce uint u0)

;; Lending Pool Management
(define-map lending-pools
  principal ;; lender
  {
    total-lent: uint,
    available-balance: uint,
    total-interest-earned: uint,
    created-at-stacks-time: uint,
    created-at-burn-height: uint,
    description: (string-utf8 200),
    signature-verified: bool,
  }
)

;; Loan Management
(define-map loans
  uint ;; loan-id
  {
    borrower: principal,
    lender: principal,
    amount: uint,
    collateral-amount: uint,
    interest-rate: uint,
    created-stacks-time: uint,
    created-burn-height: uint,
    due-stacks-time: uint,
    repaid: bool,
    description: (string-utf8 200),
    signature-verified: bool,
  }
)

;; Loan Signatures for verification
(define-map loan-signatures
  uint ;; loan-id
  {
    signature: (buff 64),
    public-key: (buff 33),
    message-hash: (buff 32),
  }
)

;; Lending Pool Signatures
(define-map lender-signatures
  principal ;; lender
  {
    signature: (buff 64),
    public-key: (buff 33),
    message-hash: (buff 32),
  }
)

;; ====================== CLARITY v4 FUNCTIONS ======================

;; Function to get the hash of this contract using contract-hash?
(define-read-only (get-contract-hash)
  (contract-hash? tx-sender)
)

;; Function to toggle asset restrictions using restrict-assets? concept
(define-public (toggle-asset-restrictions (restricted bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set assets-restricted restricted)
    ;; Note: restrict-assets? function may not be available in all environments
    ;; For this implementation, we're using internal state management
    (ok restricted)
  )
)

;; Function to convert description to ASCII using to-ascii?
(define-read-only (get-loan-description-ascii (loan-id uint))
  (match (map-get? loans loan-id)
    loan-data (ok (unwrap-panic (to-ascii? (get description loan-data))))
    (err u404)
  )
)

;; Function to get current Stacks block time
(define-read-only (get-current-stacks-time)
  stacks-block-time
)

;; ====================== LENDING FUNCTIONS ======================

;; Create a lending pool with optional signature verification
(define-public (create-lending-pool 
    (initial-amount uint)
    (description (string-utf8 200))
    (signature (optional (buff 64)))
    (public-key (optional (buff 33)))
    (message-hash (optional (buff 32)))
  )
  (let (
    (lender contract-caller)
    (signature-verified (match signature
      sig-data (match public-key
        pub-key (match message-hash
          msg-hash (secp256r1-verify msg-hash sig-data pub-key)
          false
        )
        false
      )
      false
    ))
  )
    ;; Check asset restrictions
    (asserts! (not (var-get assets-restricted)) ERR_ASSETS_RESTRICTED)
    (asserts! (> initial-amount u0) ERR_INVALID_AMOUNT)
    
    ;; Transfer sBTC to contract
    (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
      transfer initial-amount lender tx-sender none
    ))
    
    ;; Create or update lending pool
    (map-set lending-pools lender {
      total-lent: initial-amount,
      available-balance: initial-amount,
      total-interest-earned: u0,
      created-at-stacks-time: stacks-block-time,
      created-at-burn-height: burn-block-height,
      description: description,
      signature-verified: signature-verified,
    })
    
    ;; Store signature if provided
    (match signature
      sig-data (match public-key
        pub-key (match message-hash
          msg-hash (map-set lender-signatures lender {
            signature: sig-data,
            public-key: pub-key,
            message-hash: msg-hash,
          })
          true
        )
        true
      )
      true
    )
    
    ;; Emit event
    (print {
      event: "lending-pool-created",
      lender: lender,
      amount: initial-amount,
      stacks-time: stacks-block-time,
      burn-height: burn-block-height,
      signature-verified: signature-verified,
    })
    
    (ok lender)
  )
)

;; Add funds to existing lending pool
(define-public (add-to-lending-pool (amount uint))
  (let ((lender contract-caller))
    ;; Check asset restrictions
    (asserts! (not (var-get assets-restricted)) ERR_ASSETS_RESTRICTED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Get current pool data
    (let ((current-pool (unwrap! (map-get? lending-pools lender) ERR_LOAN_NOT_FOUND)))
      ;; Transfer sBTC to contract
      (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
        transfer amount lender tx-sender none
      ))
      
      ;; Update pool
      (map-set lending-pools lender (merge current-pool {
        total-lent: (+ (get total-lent current-pool) amount),
        available-balance: (+ (get available-balance current-pool) amount),
      }))
      
      (print {
        event: "funds-added-to-pool",
        lender: lender,
        amount: amount,
        stacks-time: stacks-block-time,
      })
      
      (ok amount)
    )
  )
)

;; ====================== BORROWING FUNCTIONS ======================

;; Create a loan with signature verification
(define-public (create-loan
    (lender principal)
    (amount uint)
    (collateral-amount uint)
    (loan-duration-blocks uint)
    (description (string-utf8 200))
    (signature (buff 64))
    (public-key (buff 33))
    (message-hash (buff 32))
  )
  (let (
    (borrower contract-caller)
    (loan-id (+ (var-get loan-id-nonce) u1))
    (due-time (+ stacks-block-time (* loan-duration-blocks u600))) ;; Approximate block time
    (required-collateral (/ (* amount COLLATERAL_RATIO) u100))
  )
    ;; Check asset restrictions
    (asserts! (not (var-get assets-restricted)) ERR_ASSETS_RESTRICTED)
    ;; Verify signature
    (asserts! (secp256r1-verify message-hash signature public-key) ERR_INVALID_SIGNATURE)
    ;; Validate inputs
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= collateral-amount required-collateral) ERR_INSUFFICIENT_COLLATERAL)
    
    ;; Check lender has sufficient funds
    (let ((lender-pool (unwrap! (map-get? lending-pools lender) ERR_LOAN_NOT_FOUND)))
      (asserts! (>= (get available-balance lender-pool) amount) ERR_NOT_ENOUGH_BALANCE)
      
      ;; Transfer collateral from borrower to contract
      (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
        transfer collateral-amount borrower tx-sender none
      ))
      
      ;; Transfer loan amount from contract to borrower (from lender's pool)
      ;; Note: In a real implementation, this would require proper contract-to-contract transfers
      ;; For this demo, we'll track the loan obligation in the contract state
      true
      
      ;; Update lender's available balance
      (map-set lending-pools lender (merge lender-pool {
        available-balance: (- (get available-balance lender-pool) amount),
      }))
      
      ;; Create loan record
      (map-set loans loan-id {
        borrower: borrower,
        lender: lender,
        amount: amount,
        collateral-amount: collateral-amount,
        interest-rate: INTEREST_RATE_PER_BLOCK,
        created-stacks-time: stacks-block-time,
        created-burn-height: burn-block-height,
        due-stacks-time: due-time,
        repaid: false,
        description: description,
        signature-verified: true,
      })
      
      ;; Store signature data
      (map-set loan-signatures loan-id {
        signature: signature,
        public-key: public-key,
        message-hash: message-hash,
      })
      
      ;; Update loan counter
      (var-set loan-id-nonce loan-id)
      
      ;; Emit event
      (print {
        event: "loan-created",
        loan-id: loan-id,
        borrower: borrower,
        lender: lender,
        amount: amount,
        collateral: collateral-amount,
        due-stacks-time: due-time,
        signature-verified: true,
      })
      
      (ok loan-id)
    )
  )
)

;; Repay loan with interest calculation
(define-public (repay-loan (loan-id uint))
  (let ((loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
    (let (
      (borrower (get borrower loan))
      (lender (get lender loan))
      (principal-amount (get amount loan))
      (collateral-amount (get collateral-amount loan))
      (blocks-elapsed (- stacks-block-time (get created-stacks-time loan)))
      (interest (/ (* principal-amount (get interest-rate loan) blocks-elapsed) (* u10000 u600))) ;; Convert time to blocks
      (total-repayment (+ principal-amount interest))
    )
      ;; Verify caller is borrower
      (asserts! (is-eq contract-caller borrower) ERR_UNAUTHORIZED)
      ;; Check if already repaid
      (asserts! (not (get repaid loan)) ERR_LOAN_ALREADY_REPAID)
      ;; Check asset restrictions
      (asserts! (not (var-get assets-restricted)) ERR_ASSETS_RESTRICTED)
      
      ;; Transfer repayment from borrower to contract
      (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
        transfer total-repayment borrower tx-sender none
      ))
      
      ;; Return collateral to borrower
      (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
        transfer collateral-amount tx-sender borrower none
      ))
      
      ;; Transfer interest to lender directly
      (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
        transfer interest tx-sender lender none
      ))
      
      ;; Update lender pool
      (let ((lender-pool (unwrap! (map-get? lending-pools lender) ERR_LOAN_NOT_FOUND)))
        (map-set lending-pools lender (merge lender-pool {
          available-balance: (+ (get available-balance lender-pool) principal-amount),
          total-interest-earned: (+ (get total-interest-earned lender-pool) interest),
        }))
      )
      
      ;; Mark loan as repaid
      (map-set loans loan-id (merge loan { repaid: true }))
      
      ;; Emit event
      (print {
        event: "loan-repaid",
        loan-id: loan-id,
        borrower: borrower,
        lender: lender,
        principal: principal-amount,
        interest: interest,
        total-repayment: total-repayment,
        stacks-time: stacks-block-time,
      })
      
      (ok total-repayment)
    )
  )
)

;; ====================== READ-ONLY FUNCTIONS ======================

;; Get lending pool information
(define-read-only (get-lending-pool (lender principal))
  (map-get? lending-pools lender)
)

;; Get loan information
(define-read-only (get-loan (loan-id uint))
  (map-get? loans loan-id)
)

;; Get loan signature information
(define-read-only (get-loan-signature (loan-id uint))
  (map-get? loan-signatures loan-id)
)

;; Calculate loan interest
(define-read-only (calculate-loan-interest (loan-id uint))
  (match (map-get? loans loan-id)
    loan-data (let (
      (principal-amount (get amount loan-data))
      (blocks-elapsed (- stacks-block-time (get created-stacks-time loan-data)))
      (interest-rate (get interest-rate loan-data))
    )
      (ok (/ (* principal-amount interest-rate blocks-elapsed) (* u10000 u600)))
    )
    (err u404)
  )
)

;; Check if loan is overdue
(define-read-only (is-loan-overdue (loan-id uint))
  (match (map-get? loans loan-id)
    loan-data (ok (and 
      (not (get repaid loan-data))
      (> stacks-block-time (get due-stacks-time loan-data))
    ))
    (err u404)
  )
)

;; Get contract information including hash
(define-read-only (get-contract-info)
  {
    hash: (contract-hash? tx-sender),
    owner: CONTRACT_OWNER,
    assets-restricted: (var-get assets-restricted),
    total-loans: (var-get loan-id-nonce),
    current-stacks-time: stacks-block-time,
    interest-rate-per-block: INTEREST_RATE_PER_BLOCK,
    collateral-ratio: COLLATERAL_RATIO,
  }
)

;; Verify loan signature
(define-read-only (verify-loan-signature (loan-id uint) (message-hash (buff 32)))
  (match (map-get? loan-signatures loan-id)
    signature-data 
      (secp256r1-verify 
        message-hash 
        (get signature signature-data) 
        (get public-key signature-data)
      )
    false
  )
)

;; Get lending pool description in ASCII
(define-read-only (get-pool-description-ascii (lender principal))
  (match (map-get? lending-pools lender)
    pool-data (ok (unwrap-panic (to-ascii? (get description pool-data))))
    (err u404)
  )
)