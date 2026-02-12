;; ============================================
;; TREASURY - Protocol Revenue Management
;; Clarity 4 Smart Contract
;; ============================================

(define-constant CONTRACT_OWNER tx-sender)
(define-constant COMMUNITY-SHARE u20)

(define-constant ERR_NOT_OWNER (err u401))
(define-constant ERR_INSUFFICIENT_FUNDS (err u402))

(define-data-var total-revenue uint u0)
(define-data-var community-pool uint u0)

(define-public (receive-payment (amount uint))
  (let
    (
      (community-amount (/ (* amount COMMUNITY-SHARE) u100))
    )
    (try! (stx-transfer? amount tx-sender .treasury))
    (var-set total-revenue (+ (var-get total-revenue) amount))
    (var-set community-pool (+ (var-get community-pool) community-amount))
    (ok true)
  )
)

(define-public (withdraw-owner (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
    (asserts! (<= amount (- (var-get total-revenue) (var-get community-pool))) ERR_INSUFFICIENT_FUNDS)
    (as-contract (stx-transfer? amount tx-sender CONTRACT_OWNER))
  )
)

(define-public (community-reward (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
    (asserts! (<= amount (var-get community-pool)) ERR_INSUFFICIENT_FUNDS)
    (var-set community-pool (- (var-get community-pool) amount))
    (as-contract (stx-transfer? amount tx-sender recipient))
  )
)

(define-read-only (get-stats)
  (ok {
    total-revenue: (var-get total-revenue),
    community-pool: (var-get community-pool),
    owner-available: (- (var-get total-revenue) (var-get community-pool))
  })
)

(define-read-only (get-contract-balance)
  (ok (stx-get-balance .treasury))
)
