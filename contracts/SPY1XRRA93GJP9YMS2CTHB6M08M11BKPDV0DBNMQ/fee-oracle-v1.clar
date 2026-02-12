;; ============================================
;; CONTRACT #1: ZERLIN FEE ORACLE
;; ============================================
;; Main contract that stores canonical fee data for the Stacks network
;; This is the source of truth for current and historical gas prices

;; ============================================
;; ERROR CODES
;; ============================================
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-FEE (err u101))
(define-constant ERR-INVALID-BLOCK (err u102))
(define-constant ERR-ALREADY-INITIALIZED (err u103))
(define-constant ERR-NOT-INITIALIZED (err u104))

;; ============================================
;; DATA VARIABLES
;; ============================================
(define-data-var contract-owner principal tx-sender)
(define-data-var is-initialized bool false)
(define-data-var latest-fee-rate uint u0)
(define-data-var latest-update-block uint u0)
(define-data-var total-updates uint u0)

;; ============================================
;; DATA MAPS
;; ============================================

;; Historical fee data indexed by block height
(define-map fee-history
  { block-height: uint }
  {
    fee-rate: uint,                    ;; Fee rate in microSTX per byte
    timestamp: uint,                   ;; Bitcoin block height (burn-block-height)
    network-congestion: (string-ascii 10), ;; "low", "medium", "high"
    recorded-by: principal             ;; Oracle that submitted this data
  }
)

;; Rolling average fees for transaction types
(define-map transaction-averages
  { tx-type: (string-ascii 30) }
  { 
    avg-fee: uint,
    sample-count: uint,
    last-updated: uint
  }
)

;; Authorized oracles map
(define-map authorized-oracles
  { oracle: principal }
  { authorized: bool }
)

;; ============================================
;; INITIALIZATION
;; ============================================

(define-public (initialize (initial-fee-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (not (var-get is-initialized)) ERR-ALREADY-INITIALIZED)
    (asserts! (> initial-fee-rate u0) ERR-INVALID-FEE)
    
    (var-set latest-fee-rate initial-fee-rate)
    (var-set latest-update-block stacks-block-height)
    (var-set is-initialized true)
    (var-set total-updates u1)
    
    (map-set fee-history
      { block-height: stacks-block-height }
      {
        fee-rate: initial-fee-rate,
        timestamp: burn-block-height,
        network-congestion: "medium",
        recorded-by: tx-sender
      }
    )
    
    ;; Authorize deployer
    (map-set authorized-oracles { oracle: tx-sender } { authorized: true })
    
    (print { event: "oracle-initialized", fee-rate: initial-fee-rate })
    (ok true)
  )
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

;; Get current fee rate
(define-read-only (get-current-fee-rate)
  (ok (var-get latest-fee-rate))
)

;; Get last update block
(define-read-only (get-last-update-block)
  (ok (var-get latest-update-block))
)

;; Get total updates
(define-read-only (get-total-updates)
  (ok (var-get total-updates))
)

;; Check if initialized
(define-read-only (is-oracle-initialized)
  (ok (var-get is-initialized))
)

;; Check if authorized oracle
(define-read-only (is-authorized-oracle (oracle principal))
  (ok (default-to false (get authorized (map-get? authorized-oracles { oracle: oracle }))))
)

;; Get fee at specific block
(define-read-only (get-fee-at-block (block-height-input uint))
  (match (map-get? fee-history { block-height: block-height-input })
    fee-data (ok fee-data)
    ERR-INVALID-BLOCK
  )
)

;; Get transaction average
(define-read-only (get-transaction-average (tx-type (string-ascii 30)))
  (match (map-get? transaction-averages { tx-type: tx-type })
    avg-data (ok (get avg-fee avg-data))
    (ok u0)
  )
)

;; Get fee summary
(define-read-only (get-fee-summary)
  (ok {
    current-fee: (var-get latest-fee-rate),
    last-update-block: (var-get latest-update-block),
    total-updates: (var-get total-updates),
    is-initialized: (var-get is-initialized)
  })
)

;; Get recommended buffer (2x current fee)
(define-read-only (get-recommended-buffer)
  (let ((current-fee (var-get latest-fee-rate)))
    (ok (* current-fee u2))
  )
)

;; ============================================
;; ESTIMATION FUNCTIONS
;; ============================================

;; Estimate STX transfer fee
(define-read-only (estimate-transfer-fee)
  (let (
    (base-fee (var-get latest-fee-rate))
    (tx-size u180)
  )
    (ok (* base-fee tx-size))
  )
)

;; Estimate contract call fee
(define-read-only (estimate-contract-call-fee (function-complexity uint))
  (let (
    (base-fee (var-get latest-fee-rate))
    (estimated-size (+ u250 (* function-complexity u50)))
  )
    (ok (* base-fee estimated-size))
  )
)

;; Estimate NFT mint fee
(define-read-only (estimate-nft-mint-fee)
  (match (map-get? transaction-averages { tx-type: "nft-mint" })
    avg-data (ok (get avg-fee avg-data))
    (ok (* (var-get latest-fee-rate) u450))
  )
)

;; Estimate swap fee
(define-read-only (estimate-swap-fee (dex-name (string-ascii 30)))
  (match (map-get? transaction-averages { tx-type: dex-name })
    avg-data (ok (get avg-fee avg-data))
    (ok (* (var-get latest-fee-rate) u500))
  )
)

;; Check sufficient balance
(define-read-only (check-sufficient-balance 
  (user-address principal)
  (required-fee uint)
)
  (let ((user-balance (stx-get-balance user-address)))
    (ok (>= user-balance required-fee))
  )
)

;; ============================================
;; WRITE FUNCTIONS
;; ============================================

;; Update fee rate (owner only)
(define-public (update-fee-rate 
  (new-fee-rate uint)
  (congestion (string-ascii 10))
)
  (let ((current-block stacks-block-height))
    (asserts! (default-to false (get authorized (map-get? authorized-oracles { oracle: tx-sender }))) ERR-UNAUTHORIZED)
    (asserts! (var-get is-initialized) ERR-NOT-INITIALIZED)
    (asserts! (> new-fee-rate u0) ERR-INVALID-FEE)
    
    (var-set latest-fee-rate new-fee-rate)
    (var-set latest-update-block current-block)
    (var-set total-updates (+ (var-get total-updates) u1))
    
    (map-set fee-history
      { block-height: current-block }
      {
        fee-rate: new-fee-rate,
        timestamp: burn-block-height,
        network-congestion: congestion,
        recorded-by: tx-sender
      }
    )
    
    (print { 
      event: "fee-updated", 
      fee-rate: new-fee-rate, 
      congestion: congestion,
      block: current-block
    })
    
    (ok true)
  )
)

;; Update transaction average
(define-public (update-transaction-average
  (tx-type (string-ascii 30))
  (observed-fee uint)
)
  (begin
    (asserts! (default-to false (get authorized (map-get? authorized-oracles { oracle: tx-sender }))) ERR-UNAUTHORIZED)
    (asserts! (> observed-fee u0) ERR-INVALID-FEE)
    
    (match (map-get? transaction-averages { tx-type: tx-type })
      existing (let (
        (old-avg (get avg-fee existing))
        (old-count (get sample-count existing))
        (new-count (+ old-count u1))
        (new-avg (/ (+ (* old-avg old-count) observed-fee) new-count))
      )
        (map-set transaction-averages
          { tx-type: tx-type }
          { 
            avg-fee: new-avg, 
            sample-count: new-count,
            last-updated: stacks-block-height
          }
        )
      )
      (map-set transaction-averages
        { tx-type: tx-type }
        { 
          avg-fee: observed-fee, 
          sample-count: u1,
          last-updated: stacks-block-height
        }
      )
    )
    
    (print { event: "average-updated", tx-type: tx-type, fee: observed-fee })
    (ok true)
  )
)

;; ============================================
;; ADMIN FUNCTIONS
;; ============================================

;; Transfer ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (print { event: "ownership-transferred", new-owner: new-owner })
    (ok true)
  )
)

(define-public (authorize-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (map-set authorized-oracles { oracle: oracle } { authorized: true })
    (print { event: "oracle-authorized", oracle: oracle })
    (ok true)
  )
)

(define-public (revoke-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (map-set authorized-oracles { oracle: oracle } { authorized: false })
    (print { event: "oracle-revoked", oracle: oracle })
    (ok true)
  )
)

(define-private (batch-update-avg-helper (update (tuple (tx-type (string-ascii 30)) (observed-fee uint))))
  (match (update-transaction-average (get tx-type update) (get observed-fee update))
    success true
    error false
  )
)

(define-public (batch-update-averages (updates (list 10 (tuple (tx-type (string-ascii 30)) (observed-fee uint)))))
  (begin
    (asserts! (default-to false (get authorized (map-get? authorized-oracles { oracle: tx-sender }))) ERR-UNAUTHORIZED)
    (ok (map batch-update-avg-helper updates))
  )
)
