;; BitTrust Core Lending Contract
;; A reputation-based micro-lending platform on Stacks

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-insufficient-collateral (err u103))
(define-constant err-loan-active (err u104))
(define-constant err-loan-not-active (err u105))
(define-constant err-invalid-amount (err u106))
(define-constant err-already-exists (err u107))
(define-constant err-insufficient-balance (err u108))

;; Data Variables
(define-data-var loan-nonce uint u0)

;; Data Maps
(define-map loans
  { loan-id: uint }
  {
    borrower: principal,
    lender: principal,
    amount: uint,
    collateral: uint,
    interest-rate: uint,
    duration: uint,
    start-block: uint,
    due-block: uint,
    repaid-amount: uint,
    status: (string-ascii 20),
    collateral-ratio: uint
  }
)

(define-map user-stats
  { user: principal }
  {
    total-borrowed: uint,
    total-lent: uint,
    active-loans-as-borrower: uint,
    active-loans-as-lender: uint,
    total-repaid: uint,
    defaults: uint
  }
)

(define-map collateral-vault
  { loan-id: uint }
  { amount: uint }
)

;; Read-only functions
(define-read-only (get-loan (loan-id uint))
  (map-get? loans { loan-id: loan-id })
)

(define-read-only (get-user-stats (user principal))
  (default-to
    { total-borrowed: u0, total-lent: u0, active-loans-as-borrower: u0, 
      active-loans-as-lender: u0, total-repaid: u0, defaults: u0 }
    (map-get? user-stats { user: user })
  )
)

(define-read-only (calculate-repayment-amount (loan-id uint))
  (let
    (
      (loan (unwrap! (get-loan loan-id) err-not-found))
      (principal-amount (get amount loan))
      (interest-rate (get interest-rate loan))
    )
    (ok (+ principal-amount (/ (* principal-amount interest-rate) u10000)))
  )
)

(define-read-only (is-loan-overdue (loan-id uint))
  (let
    (
      (loan (unwrap! (get-loan loan-id) err-not-found))
    )
    (ok (> stacks-block-height (get due-block loan)))
  )
)

;; Public functions

;; Create a direct peer-to-peer loan
(define-public (create-loan (borrower principal) (amount uint) (collateral-amount uint)
                            (interest-rate uint) (duration uint) (min-collateral-ratio uint))
  (let
    (
      (loan-id (var-get loan-nonce))
      (collateral-ratio (if (> collateral-amount u0)
                           (/ (* collateral-amount u100) amount)
                           u0))
    )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= collateral-ratio min-collateral-ratio) err-insufficient-collateral)
    
    ;; Transfer loan from lender to borrower
    (try! (stx-transfer? amount tx-sender borrower))
    
    ;; Transfer collateral from borrower to lender (held as collateral)
    (if (> collateral-amount u0)
      (try! (stx-transfer? collateral-amount borrower tx-sender))
      true
    )
    
    ;; Store collateral info
    (map-set collateral-vault { loan-id: loan-id } { amount: collateral-amount })
    
    ;; Create loan record
    (map-set loans
      { loan-id: loan-id }
      {
        borrower: borrower,
        lender: tx-sender,
        amount: amount,
        collateral: collateral-amount,
        interest-rate: interest-rate,
        duration: duration,
        start-block: stacks-block-height,
        due-block: (+ stacks-block-height duration),
        repaid-amount: u0,
        status: "active",
        collateral-ratio: collateral-ratio
      }
    )
    
    ;; Update user stats
    (update-user-stats-borrow borrower amount)
    (update-user-stats-lend tx-sender amount)
    
    (var-set loan-nonce (+ loan-id u1))
    (ok loan-id)
  )
)

;; Repay loan
(define-public (repay-loan (loan-id uint) (amount uint))
  (let
    (
      (loan (unwrap! (get-loan loan-id) err-not-found))
      (borrower (get borrower loan))
      (lender (get lender loan))
      (total-repayment (unwrap! (calculate-repayment-amount loan-id) err-not-found))
      (new-repaid (+ (get repaid-amount loan) amount))
      (collateral-amt (get collateral loan))
    )
    (asserts! (is-eq tx-sender borrower) err-unauthorized)
    (asserts! (is-eq (get status loan) "active") err-loan-not-active)
    (asserts! (> amount u0) err-invalid-amount)
    
    ;; Transfer repayment to lender
    (try! (stx-transfer? amount tx-sender lender))
    
    ;; Check if fully repaid
    (if (>= new-repaid total-repayment)
      (begin
        ;; Loan fully repaid - return collateral
        (map-set loans { loan-id: loan-id } (merge loan { 
          repaid-amount: new-repaid,
          status: "repaid"
        }))
        
        ;; Return collateral from lender to borrower
        (if (> collateral-amt u0)
          (try! (stx-transfer? collateral-amt lender borrower))
          true
        )
        
        ;; Update stats
        (update-user-stats-repay borrower (get amount loan))
        (update-user-stats-lend-complete lender)
      )
      ;; Partial repayment
      (map-set loans { loan-id: loan-id } (merge loan { repaid-amount: new-repaid }))
    )
    
    (ok true)
  )
)

;; Liquidate defaulted loan
(define-public (liquidate-loan (loan-id uint))
  (let
    (
      (loan (unwrap! (get-loan loan-id) err-not-found))
      (lender (get lender loan))
    )
    (asserts! (is-eq tx-sender lender) err-unauthorized)
    (asserts! (is-eq (get status loan) "active") err-loan-not-active)
    (asserts! (unwrap! (is-loan-overdue loan-id) err-not-found) err-loan-active)
    
    ;; Update loan status (collateral already with lender)
    (map-set loans { loan-id: loan-id } (merge loan { status: "liquidated" }))
    
    ;; Update borrower stats (add default)
    (let
      (
        (borrower (get borrower loan))
        (stats (get-user-stats borrower))
      )
      (map-set user-stats
        { user: borrower }
        (merge stats { 
          defaults: (+ (get defaults stats) u1),
          active-loans-as-borrower: (- (get active-loans-as-borrower stats) u1)
        })
      )
    )
    
    (ok true)
  )
)

;; Private functions
(define-private (update-user-stats-borrow (user principal) (amount uint))
  (let
    (
      (stats (get-user-stats user))
    )
    (map-set user-stats
      { user: user }
      {
        total-borrowed: (+ (get total-borrowed stats) amount),
        total-lent: (get total-lent stats),
        active-loans-as-borrower: (+ (get active-loans-as-borrower stats) u1),
        active-loans-as-lender: (get active-loans-as-lender stats),
        total-repaid: (get total-repaid stats),
        defaults: (get defaults stats)
      }
    )
  )
)

(define-private (update-user-stats-lend (user principal) (amount uint))
  (let
    (
      (stats (get-user-stats user))
    )
    (map-set user-stats
      { user: user }
      {
        total-borrowed: (get total-borrowed stats),
        total-lent: (+ (get total-lent stats) amount),
        active-loans-as-borrower: (get active-loans-as-borrower stats),
        active-loans-as-lender: (+ (get active-loans-as-lender stats) u1),
        total-repaid: (get total-repaid stats),
        defaults: (get defaults stats)
      }
    )
  )
)

(define-private (update-user-stats-repay (user principal) (amount uint))
  (let
    (
      (stats (get-user-stats user))
    )
    (map-set user-stats
      { user: user }
      (merge stats {
        total-repaid: (+ (get total-repaid stats) amount),
        active-loans-as-borrower: (- (get active-loans-as-borrower stats) u1)
      })
    )
  )
)

(define-private (update-user-stats-lend-complete (user principal))
  (let
    (
      (stats (get-user-stats user))
    )
    (map-set user-stats
      { user: user }
      (merge stats {
        active-loans-as-lender: (- (get active-loans-as-lender stats) u1)
      })
    )
  )
)
