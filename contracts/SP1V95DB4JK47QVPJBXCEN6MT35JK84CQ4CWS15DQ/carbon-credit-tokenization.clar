(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u104))
(define-constant err-already-retired (err u123))

(define-data-var credit-nonce uint u0)

(define-map carbon-credits
  uint
  {
    issuer: principal,
    project-id: (string-ascii 50),
    tonnes-co2: uint,
    vintage-year: uint,
    verification-standard: (string-ascii 30),
    location-hash: (buff 32),
    retired: bool,
    issued-block: uint
  }
)

(define-map credit-ownership
  {credit-id: uint, owner: principal}
  {
    amount: uint,
    acquired-block: uint
  }
)

(define-map credit-retirements
  {credit-id: uint, retirement-id: uint}
  {
    retiree: principal,
    amount: uint,
    beneficiary: (string-ascii 50),
    retirement-block: uint
  }
)

(define-map credit-trades
  {credit-id: uint, trade-id: uint}
  {
    seller: principal,
    buyer: principal,
    amount: uint,
    price: uint,
    block: uint
  }
)

(define-map retirement-counter uint uint)
(define-map trade-counter uint uint)
(define-map issuer-credits principal (list 100 uint))
(define-map owner-credits principal (list 200 uint))

(define-public (issue-credits (project-id (string-ascii 50)) (tonnes uint) (vintage uint) 
                               (standard (string-ascii 30)) (location (buff 32)))
  (let
    (
      (credit-id (+ (var-get credit-nonce) u1))
    )
    (asserts! (> tonnes u0) err-invalid-amount)
    (map-set carbon-credits credit-id {
      issuer: tx-sender,
      project-id: project-id,
      tonnes-co2: tonnes,
      vintage-year: vintage,
      verification-standard: standard,
      location-hash: location,
      retired: false,
      issued-block: stacks-block-height
    })
    (map-set credit-ownership {credit-id: credit-id, owner: tx-sender} {
      amount: tonnes,
      acquired-block: stacks-block-height
    })
    (map-set retirement-counter credit-id u0)
    (map-set trade-counter credit-id u0)
    (map-set issuer-credits tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? issuer-credits tx-sender)) credit-id) u100)))
    (map-set owner-credits tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? owner-credits tx-sender)) credit-id) u200)))
    (var-set credit-nonce credit-id)
    (ok credit-id)
  )
)

(define-public (trade-credits (credit-id uint) (buyer principal) (amount uint) (price uint))
  (let
    (
      (credit (unwrap! (map-get? carbon-credits credit-id) err-not-found))
      (seller-ownership (unwrap! (map-get? credit-ownership {credit-id: credit-id, owner: tx-sender}) err-not-found))
      (buyer-ownership (default-to {amount: u0, acquired-block: stacks-block-height}
                        (map-get? credit-ownership {credit-id: credit-id, owner: buyer})))
      (trade-id (+ (default-to u0 (map-get? trade-counter credit-id)) u1))
    )
    (asserts! (not (get retired credit)) err-already-retired)
    (asserts! (>= (get amount seller-ownership) amount) err-invalid-amount)
    (try! (stx-transfer? price buyer tx-sender))
    (map-set credit-trades {credit-id: credit-id, trade-id: trade-id} {
      seller: tx-sender,
      buyer: buyer,
      amount: amount,
      price: price,
      block: stacks-block-height
    })
    (map-set trade-counter credit-id trade-id)
    (map-set credit-ownership {credit-id: credit-id, owner: tx-sender}
      (merge seller-ownership {amount: (- (get amount seller-ownership) amount)}))
    (map-set credit-ownership {credit-id: credit-id, owner: buyer}
      {amount: (+ (get amount buyer-ownership) amount), acquired-block: (get acquired-block buyer-ownership)})
    (map-set owner-credits buyer
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? owner-credits buyer)) credit-id) u200)))
    (ok trade-id)
  )
)

(define-public (retire-credits (credit-id uint) (amount uint) (beneficiary (string-ascii 50)))
  (let
    (
      (credit (unwrap! (map-get? carbon-credits credit-id) err-not-found))
      (ownership (unwrap! (map-get? credit-ownership {credit-id: credit-id, owner: tx-sender}) err-not-found))
      (retirement-id (+ (default-to u0 (map-get? retirement-counter credit-id)) u1))
    )
    (asserts! (not (get retired credit)) err-already-retired)
    (asserts! (>= (get amount ownership) amount) err-invalid-amount)
    (map-set credit-retirements {credit-id: credit-id, retirement-id: retirement-id} {
      retiree: tx-sender,
      amount: amount,
      beneficiary: beneficiary,
      retirement-block: stacks-block-height
    })
    (map-set retirement-counter credit-id retirement-id)
    (map-set credit-ownership {credit-id: credit-id, owner: tx-sender}
      (merge ownership {amount: (- (get amount ownership) amount)}))
    (ok retirement-id)
  )
)

(define-read-only (get-credit (credit-id uint))
  (ok (map-get? carbon-credits credit-id))
)

(define-read-only (get-ownership (credit-id uint) (owner principal))
  (ok (map-get? credit-ownership {credit-id: credit-id, owner: owner}))
)

(define-read-only (get-retirement (credit-id uint) (retirement-id uint))
  (ok (map-get? credit-retirements {credit-id: credit-id, retirement-id: retirement-id}))
)

(define-read-only (get-trade (credit-id uint) (trade-id uint))
  (ok (map-get? credit-trades {credit-id: credit-id, trade-id: trade-id}))
)

(define-read-only (get-owner-credits (owner principal))
  (ok (map-get? owner-credits owner))
)

(define-read-only (calculate-total-retired (credit-id uint))
  u0
)
