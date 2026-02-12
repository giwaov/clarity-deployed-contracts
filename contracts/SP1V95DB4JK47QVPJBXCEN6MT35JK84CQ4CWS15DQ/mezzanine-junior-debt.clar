(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u104))
(define-constant err-invalid-tranche (err u112))
(define-constant err-tranche-full (err u113))

(define-data-var tranche-nonce uint u0)

(define-map tranches
  uint
  {
    issuer: principal,
    tranche-type: (string-ascii 20),
    total-amount: uint,
    raised-amount: uint,
    interest-rate: uint,
    subordination-level: uint,
    maturity-block: uint,
    active: bool,
    issue-block: uint
  }
)

(define-map investments
  {tranche-id: uint, investor: principal}
  {
    amount: uint,
    entry-block: uint,
    claimed: uint
  }
)

(define-map tranche-investors uint (list 100 principal))
(define-map investor-tranches principal (list 50 uint))

(define-public (create-tranche (tranche-type (string-ascii 20)) (amount uint) (rate uint) (subordination uint) (term uint))
  (let
    (
      (tranche-id (+ (var-get tranche-nonce) u1))
    )
    (asserts! (> amount u0) err-invalid-amount)
    (map-set tranches tranche-id {
      issuer: tx-sender,
      tranche-type: tranche-type,
      total-amount: amount,
      raised-amount: u0,
      interest-rate: rate,
      subordination-level: subordination,
      maturity-block: (+ stacks-block-height term),
      active: true,
      issue-block: stacks-block-height
    })
    (var-set tranche-nonce tranche-id)
    (ok tranche-id)
  )
)

(define-public (invest (tranche-id uint) (amount uint))
  (let
    (
      (tranche (unwrap! (map-get? tranches tranche-id) err-not-found))
      (new-raised (+ (get raised-amount tranche) amount))
      (existing (default-to {amount: u0, entry-block: stacks-block-height, claimed: u0} 
                 (map-get? investments {tranche-id: tranche-id, investor: tx-sender})))
    )
    (asserts! (get active tranche) err-invalid-tranche)
    (asserts! (<= new-raised (get total-amount tranche)) err-tranche-full)
    (try! (stx-transfer? amount tx-sender (get issuer tranche)))
    (map-set investments {tranche-id: tranche-id, investor: tx-sender} {
      amount: (+ (get amount existing) amount),
      entry-block: (get entry-block existing),
      claimed: (get claimed existing)
    })
    (map-set tranches tranche-id (merge tranche {raised-amount: new-raised}))
    (map-set tranche-investors tranche-id 
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? tranche-investors tranche-id)) tx-sender) u100)))
    (map-set investor-tranches tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? investor-tranches tx-sender)) tranche-id) u50)))
    (ok true)
  )
)

(define-public (claim-returns (tranche-id uint))
  (let
    (
      (tranche (unwrap! (map-get? tranches tranche-id) err-not-found))
      (investment (unwrap! (map-get? investments {tranche-id: tranche-id, investor: tx-sender}) err-not-found))
      (returns (calculate-returns tranche-id tx-sender))
      (claimable (- returns (get claimed investment)))
    )
    (asserts! (>= stacks-block-height (get maturity-block tranche)) err-unauthorized)
    (try! (stx-transfer? claimable (get issuer tranche) tx-sender))
    (map-set investments {tranche-id: tranche-id, investor: tx-sender}
      (merge investment {claimed: returns}))
    (ok claimable)
  )
)

(define-public (close-tranche (tranche-id uint))
  (let
    (
      (tranche (unwrap! (map-get? tranches tranche-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get issuer tranche)) err-unauthorized)
    (map-set tranches tranche-id (merge tranche {active: false}))
    (ok true)
  )
)

(define-read-only (get-tranche (tranche-id uint))
  (ok (map-get? tranches tranche-id))
)

(define-read-only (get-investment (tranche-id uint) (investor principal))
  (ok (map-get? investments {tranche-id: tranche-id, investor: investor}))
)

(define-read-only (get-investor-tranches (investor principal))
  (ok (map-get? investor-tranches investor))
)

(define-read-only (calculate-returns (tranche-id uint) (investor principal))
  (let
    (
      (tranche (unwrap-panic (map-get? tranches tranche-id)))
      (investment (unwrap-panic (map-get? investments {tranche-id: tranche-id, investor: investor})))
      (amount (get amount investment))
      (rate (get interest-rate tranche))
      (elapsed (- stacks-block-height (get entry-block investment)))
    )
    (+ amount (/ (* amount (* rate elapsed)) u10000000))
  )
)

(define-read-only (get-tranche-status (tranche-id uint))
  (let
    (
      (tranche (unwrap-panic (map-get? tranches tranche-id)))
    )
    (ok {
      active: (get active tranche),
      raised: (get raised-amount tranche),
      remaining: (- (get total-amount tranche) (get raised-amount tranche)),
      subordination: (get subordination-level tranche)
    })
  )
)
