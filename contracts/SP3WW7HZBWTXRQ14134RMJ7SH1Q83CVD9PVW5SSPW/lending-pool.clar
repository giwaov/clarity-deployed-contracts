;; DeFi Lending Pool Contract
;; Enables collateralized lending and borrowing of STX and SIP-010 tokens

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-collateral (err u101))
(define-constant err-insufficient-liquidity (err u102))
(define-constant err-loan-not-found (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-already-liquidated (err u105))

;; Data Variables
(define-data-var total-deposits uint u0)
(define-data-var total-borrows uint u0)
(define-data-var collateral-ratio uint u150) ;; 150% collateralization required
(define-data-var paused bool false)

;; Data Maps
(define-map user-deposits principal uint)
(define-map user-collateral principal uint)
(define-map user-borrows principal uint)
(define-map loan-details 
  uint 
  {
    borrower: principal,
    collateral-amount: uint,
    borrow-amount: uint,
    interest-rate: uint,
    timestamp: uint,
    liquidated: bool
  }
)

(define-data-var next-loan-id uint u1)

;; Read-only functions
(define-read-only (get-pool-info)
  {
    total-deposits: (var-get total-deposits),
    total-borrows: (var-get total-borrows),
    available-liquidity: (- (var-get total-deposits) (var-get total-borrows)),
    collateral-ratio: (var-get collateral-ratio)
  }
)

(define-read-only (get-user-deposits (user principal))
  (default-to u0 (map-get? user-deposits user))
)

(define-read-only (get-user-collateral (user principal))
  (default-to u0 (map-get? user-collateral user))
)

(define-read-only (get-user-borrows (user principal))
  (default-to u0 (map-get? user-borrows user))
)

(define-read-only (get-loan-details (loan-id uint))
  (map-get? loan-details loan-id)
)

(define-read-only (calculate-max-borrow (collateral-amount uint))
  (/ (* collateral-amount u100) (var-get collateral-ratio))
)

;; Public functions
(define-public (deposit (amount uint))
  (begin
    (asserts! (not (var-get paused)) (err u106))
    (asserts! (> amount u0) err-invalid-amount)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set user-deposits tx-sender 
      (+ (get-user-deposits tx-sender) amount))
    (var-set total-deposits (+ (var-get total-deposits) amount))
    
    (ok amount)
  )
)

(define-public (withdraw (amount uint))
  (let (
    (user-balance (get-user-deposits tx-sender))
  )
    (asserts! (not (var-get paused)) (err u106))
    (asserts! (>= user-balance amount) err-insufficient-liquidity)
    
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    
    (map-set user-deposits tx-sender (- user-balance amount))
    (var-set total-deposits (- (var-get total-deposits) amount))
    
    (ok amount)
  )
)

(define-public (deposit-collateral (amount uint))
  (begin
    (asserts! (not (var-get paused)) (err u106))
    (asserts! (> amount u0) err-invalid-amount)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set user-collateral tx-sender 
      (+ (get-user-collateral tx-sender) amount))
    
    (ok amount)
  )
)

(define-public (borrow (amount uint))
  (let (
    (user-collateral-amount (get-user-collateral tx-sender))
    (max-borrow (calculate-max-borrow user-collateral-amount))
    (current-borrows (get-user-borrows tx-sender))
    (available-liquidity (- (var-get total-deposits) (var-get total-borrows)))
    (loan-id (var-get next-loan-id))
  )
    (asserts! (not (var-get paused)) (err u106))
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= max-borrow (+ current-borrows amount)) err-insufficient-collateral)
    (asserts! (>= available-liquidity amount) err-insufficient-liquidity)
    
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    
    (map-set user-borrows tx-sender (+ current-borrows amount))
    (var-set total-borrows (+ (var-get total-borrows) amount))
    
    (map-set loan-details loan-id {
      borrower: tx-sender,
      collateral-amount: user-collateral-amount,
      borrow-amount: amount,
      interest-rate: u5,
      timestamp: block-height,
      liquidated: false
    })
    
    (var-set next-loan-id (+ loan-id u1))
    
    (ok loan-id)
  )
)

(define-public (repay (amount uint))
  (let (
    (current-borrows (get-user-borrows tx-sender))
  )
    (asserts! (not (var-get paused)) (err u106))
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= current-borrows amount) (err u107))
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set user-borrows tx-sender (- current-borrows amount))
    (var-set total-borrows (- (var-get total-borrows) amount))
    
    (ok amount)
  )
)

(define-public (withdraw-collateral (amount uint))
  (let (
    (user-collateral-amount (get-user-collateral tx-sender))
    (current-borrows (get-user-borrows tx-sender))
    (remaining-collateral (- user-collateral-amount amount))
    (required-collateral (/ (* current-borrows (var-get collateral-ratio)) u100))
  )
    (asserts! (not (var-get paused)) (err u106))
    (asserts! (>= user-collateral-amount amount) err-insufficient-collateral)
    (asserts! (>= remaining-collateral required-collateral) err-insufficient-collateral)
    
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    
    (map-set user-collateral tx-sender remaining-collateral)
    
    (ok amount)
  )
)

;; Admin functions
(define-public (set-collateral-ratio (new-ratio uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set collateral-ratio new-ratio)
    (ok true)
  )
)

(define-public (toggle-pause)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set paused (not (var-get paused)))
    (ok (var-get paused))
  )
)
