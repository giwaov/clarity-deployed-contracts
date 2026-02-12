(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-market-closed (err u105))
(define-constant err-market-not-resolved (err u106))

(define-data-var market-nonce uint u0)

(define-map prediction-markets
  uint
  {
    creator: principal,
    question: (string-ascii 100),
    description-hash: (buff 32),
    resolution-source-hash: (buff 32),
    total-yes-stakes: uint,
    total-no-stakes: uint,
    resolution-deadline: uint,
    resolved: bool,
    outcome: (optional bool),
    resolved-at: (optional uint)
  }
)

(define-map user-positions
  {market-id: uint, user: principal}
  {
    yes-stake: uint,
    no-stake: uint,
    claimed: bool
  }
)

(define-map creator-markets principal (list 50 uint))
(define-map market-participants uint (list 500 uint))

(define-public (create-market (question (string-ascii 100)) (description-hash (buff 32)) (resolution-source-hash (buff 32)) (resolution-deadline uint))
  (let
    (
      (market-id (+ (var-get market-nonce) u1))
    )
    (asserts! (> resolution-deadline stacks-block-height) err-invalid-amount)
    (map-set prediction-markets market-id
      {
        creator: tx-sender,
        question: question,
        description-hash: description-hash,
        resolution-source-hash: resolution-source-hash,
        total-yes-stakes: u0,
        total-no-stakes: u0,
        resolution-deadline: resolution-deadline,
        resolved: false,
        outcome: none,
        resolved-at: none
      }
    )
    (map-set creator-markets tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? creator-markets tx-sender)) market-id) u50)))
    (var-set market-nonce market-id)
    (ok market-id)
  )
)

(define-public (stake-yes (market-id uint) (amount uint))
  (let
    (
      (market (unwrap! (map-get? prediction-markets market-id) err-not-found))
      (position (default-to {yes-stake: u0, no-stake: u0, claimed: false} (map-get? user-positions {market-id: market-id, user: tx-sender})))
    )
    (asserts! (not (get resolved market)) err-market-closed)
    (asserts! (< stacks-block-height (get resolution-deadline market)) err-market-closed)
    (asserts! (> amount u0) err-invalid-amount)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set user-positions {market-id: market-id, user: tx-sender}
      (merge position {yes-stake: (+ (get yes-stake position) amount)}))
    (map-set prediction-markets market-id (merge market {
      total-yes-stakes: (+ (get total-yes-stakes market) amount)
    }))
    (ok true)
  )
)

(define-public (stake-no (market-id uint) (amount uint))
  (let
    (
      (market (unwrap! (map-get? prediction-markets market-id) err-not-found))
      (position (default-to {yes-stake: u0, no-stake: u0, claimed: false} (map-get? user-positions {market-id: market-id, user: tx-sender})))
    )
    (asserts! (not (get resolved market)) err-market-closed)
    (asserts! (< stacks-block-height (get resolution-deadline market)) err-market-closed)
    (asserts! (> amount u0) err-invalid-amount)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set user-positions {market-id: market-id, user: tx-sender}
      (merge position {no-stake: (+ (get no-stake position) amount)}))
    (map-set prediction-markets market-id (merge market {
      total-no-stakes: (+ (get total-no-stakes market) amount)
    }))
    (ok true)
  )
)

(define-public (resolve-market (market-id uint) (outcome bool))
  (let
    (
      (market (unwrap! (map-get? prediction-markets market-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get creator market)) err-unauthorized)
    (asserts! (not (get resolved market)) err-already-exists)
    (asserts! (>= stacks-block-height (get resolution-deadline market)) err-market-closed)
    (map-set prediction-markets market-id (merge market {
      resolved: true,
      outcome: (some outcome),
      resolved-at: (some stacks-block-height)
    }))
    (ok true)
  )
)

(define-public (claim-winnings (market-id uint))
  (let
    (
      (market (unwrap! (map-get? prediction-markets market-id) err-not-found))
      (position (unwrap! (map-get? user-positions {market-id: market-id, user: tx-sender}) err-not-found))
      (outcome (unwrap! (get outcome market) err-market-not-resolved))
    )
    (asserts! (get resolved market) err-market-not-resolved)
    (asserts! (not (get claimed position)) err-already-exists)
    (let
      (
        (winning-stake (if outcome (get yes-stake position) (get no-stake position)))
        (total-winning-stakes (if outcome (get total-yes-stakes market) (get total-no-stakes market)))
        (total-pool (+ (get total-yes-stakes market) (get total-no-stakes market)))
        (payout (if (> total-winning-stakes u0) (/ (* winning-stake total-pool) total-winning-stakes) u0))
      )
      (asserts! (> payout u0) err-invalid-amount)
      (try! (as-contract (stx-transfer? payout tx-sender tx-sender)))
      (map-set user-positions {market-id: market-id, user: tx-sender} (merge position {claimed: true}))
      (ok payout)
    )
  )
)

(define-read-only (get-market (market-id uint))
  (ok (map-get? prediction-markets market-id))
)

(define-read-only (get-position (market-id uint) (user principal))
  (ok (map-get? user-positions {market-id: market-id, user: user}))
)

(define-read-only (get-creator-markets (creator principal))
  (ok (map-get? creator-markets creator))
)

(define-read-only (get-market-odds (market-id uint))
  (let
    (
      (market (unwrap! (map-get? prediction-markets market-id) err-not-found))
      (total-pool (+ (get total-yes-stakes market) (get total-no-stakes market)))
    )
    (ok {
      yes-probability: (if (> total-pool u0) (/ (* (get total-yes-stakes market) u10000) total-pool) u0),
      no-probability: (if (> total-pool u0) (/ (* (get total-no-stakes market) u10000) total-pool) u0)
    })
  )
)
