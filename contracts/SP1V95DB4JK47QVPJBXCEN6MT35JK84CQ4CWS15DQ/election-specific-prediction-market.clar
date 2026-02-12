(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-market-closed (err u102))
(define-constant err-invalid-outcome (err u103))

(define-map markets
  uint
  {
    election-name: (string-ascii 128),
    outcomes: (list 10 (string-ascii 64)),
    end-block: uint,
    resolved: bool,
    winning-outcome: uint
  })

(define-map positions
  {market-id: uint, user: principal, outcome: uint}
  {shares: uint, avg-price: uint})

(define-map outcome-pools
  {market-id: uint, outcome: uint}
  {total-shares: uint, total-liquidity: uint})

(define-data-var next-market-id uint u0)

(define-read-only (get-market (market-id uint))
  (ok (map-get? markets market-id)))

(define-read-only (get-position (market-id uint) (user principal) (outcome uint))
  (ok (map-get? positions {market-id: market-id, user: user, outcome: outcome})))

(define-read-only (get-outcome-pool (market-id uint) (outcome uint))
  (ok (map-get? outcome-pools {market-id: market-id, outcome: outcome})))

(define-public (create-market (name (string-ascii 128)) (outcomes (list 10 (string-ascii 64))) (duration uint))
  (let ((market-id (var-get next-market-id)))
    (map-set markets market-id
      {election-name: name, outcomes: outcomes, end-block: (+ stacks-block-height duration),
       resolved: false, winning-outcome: u0})
    (var-set next-market-id (+ market-id u1))
    (ok market-id)))

(define-public (buy-shares (market-id uint) (outcome uint) (amount uint) (price uint))
  (let ((market (unwrap! (map-get? markets market-id) err-not-found)))
    (asserts! (< stacks-block-height (get end-block market)) err-market-closed)
    (asserts! (not (get resolved market)) err-market-closed)
    (try! (stx-transfer? (* amount price) tx-sender (as-contract tx-sender)))
    (map-set positions {market-id: market-id, user: tx-sender, outcome: outcome}
      {shares: amount, avg-price: price})
    (ok true)))

(define-public (resolve-market (market-id uint) (winning-outcome uint))
  (let ((market (unwrap! (map-get? markets market-id) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (>= stacks-block-height (get end-block market)) err-market-closed)
    (ok (map-set markets market-id (merge market {resolved: true, winning-outcome: winning-outcome})))))

(define-public (claim-winnings (market-id uint) (outcome uint))
  (let ((market (unwrap! (map-get? markets market-id) err-not-found))
        (position (unwrap! (map-get? positions {market-id: market-id, user: tx-sender, outcome: outcome}) err-not-found)))
    (asserts! (get resolved market) err-market-closed)
    (asserts! (is-eq (get winning-outcome market) outcome) err-invalid-outcome)
    (try! (as-contract (stx-transfer? (* (get shares position) (get avg-price position)) tx-sender tx-sender)))
    (ok true)))
