(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-campaign-inactive (err u105))

(define-data-var campaign-nonce uint u0)
(define-data-var impression-nonce uint u0)

(define-map ad-campaigns
  uint
  {
    advertiser: principal,
    campaign-name: (string-ascii 50),
    ad-content-hash: (buff 32),
    budget: uint,
    spent: uint,
    cost-per-impression: uint,
    target-impressions: uint,
    actual-impressions: uint,
    active: bool
  }
)

(define-map ad-impressions
  uint
  {
    campaign-id: uint,
    publisher: principal,
    viewer-hash: (buff 32),
    impression-block: uint,
    payment-amount: uint,
    verified: bool
  }
)

(define-map publisher-earnings
  principal
  uint
)

(define-map campaign-impressions uint (list 1000 uint))
(define-map advertiser-campaigns principal (list 50 uint))

(define-public (create-ad-campaign (campaign-name (string-ascii 50)) (ad-content-hash (buff 32)) (budget uint) (cost-per-impression uint) (target-impressions uint))
  (let
    (
      (campaign-id (+ (var-get campaign-nonce) u1))
    )
    (asserts! (> budget u0) err-invalid-amount)
    (asserts! (> cost-per-impression u0) err-invalid-amount)
    (asserts! (> target-impressions u0) err-invalid-amount)
    (try! (stx-transfer? budget tx-sender (as-contract tx-sender)))
    (map-set ad-campaigns campaign-id
      {
        advertiser: tx-sender,
        campaign-name: campaign-name,
        ad-content-hash: ad-content-hash,
        budget: budget,
        spent: u0,
        cost-per-impression: cost-per-impression,
        target-impressions: target-impressions,
        actual-impressions: u0,
        active: true
      }
    )
    (map-set advertiser-campaigns tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? advertiser-campaigns tx-sender)) campaign-id) u50)))
    (var-set campaign-nonce campaign-id)
    (ok campaign-id)
  )
)

(define-public (record-impression (campaign-id uint) (viewer-hash (buff 32)))
  (let
    (
      (campaign (unwrap! (map-get? ad-campaigns campaign-id) err-not-found))
      (impression-id (+ (var-get impression-nonce) u1))
      (payment (get cost-per-impression campaign))
    )
    (asserts! (get active campaign) err-campaign-inactive)
    (asserts! (< (get actual-impressions campaign) (get target-impressions campaign)) err-campaign-inactive)
    (asserts! (<= (+ (get spent campaign) payment) (get budget campaign)) err-invalid-amount)
    (map-set ad-impressions impression-id
      {
        campaign-id: campaign-id,
        publisher: tx-sender,
        viewer-hash: viewer-hash,
        impression-block: stacks-block-height,
        payment-amount: payment,
        verified: false
      }
    )
    (map-set campaign-impressions campaign-id
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? campaign-impressions campaign-id)) impression-id) u1000)))
    (var-set impression-nonce impression-id)
    (ok impression-id)
  )
)

(define-public (verify-and-pay-impression (impression-id uint))
  (let
    (
      (impression (unwrap! (map-get? ad-impressions impression-id) err-not-found))
      (campaign (unwrap! (map-get? ad-campaigns (get campaign-id impression)) err-not-found))
    )
    (asserts! (is-eq tx-sender (get advertiser campaign)) err-unauthorized)
    (asserts! (not (get verified impression)) err-already-exists)
    (try! (as-contract (stx-transfer? (get payment-amount impression) tx-sender (get publisher impression))))
    (map-set ad-impressions impression-id (merge impression {verified: true}))
    (map-set ad-campaigns (get campaign-id impression) (merge campaign {
      spent: (+ (get spent campaign) (get payment-amount impression)),
      actual-impressions: (+ (get actual-impressions campaign) u1)
    }))
    (map-set publisher-earnings (get publisher impression)
      (+ (default-to u0 (map-get? publisher-earnings (get publisher impression))) (get payment-amount impression)))
    (ok true)
  )
)

(define-public (pause-campaign (campaign-id uint))
  (let
    (
      (campaign (unwrap! (map-get? ad-campaigns campaign-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get advertiser campaign)) err-unauthorized)
    (map-set ad-campaigns campaign-id (merge campaign {active: false}))
    (ok true)
  )
)

(define-public (resume-campaign (campaign-id uint))
  (let
    (
      (campaign (unwrap! (map-get? ad-campaigns campaign-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get advertiser campaign)) err-unauthorized)
    (asserts! (< (get actual-impressions campaign) (get target-impressions campaign)) err-campaign-inactive)
    (map-set ad-campaigns campaign-id (merge campaign {active: true}))
    (ok true)
  )
)

(define-public (withdraw-remaining-budget (campaign-id uint))
  (let
    (
      (campaign (unwrap! (map-get? ad-campaigns campaign-id) err-not-found))
      (remaining (- (get budget campaign) (get spent campaign)))
    )
    (asserts! (is-eq tx-sender (get advertiser campaign)) err-unauthorized)
    (asserts! (not (get active campaign)) err-campaign-inactive)
    (asserts! (> remaining u0) err-invalid-amount)
    (try! (as-contract (stx-transfer? remaining tx-sender (get advertiser campaign))))
    (map-set ad-campaigns campaign-id (merge campaign {budget: (get spent campaign)}))
    (ok true)
  )
)

(define-read-only (get-ad-campaign (campaign-id uint))
  (ok (map-get? ad-campaigns campaign-id))
)

(define-read-only (get-impression (impression-id uint))
  (ok (map-get? ad-impressions impression-id))
)

(define-read-only (get-publisher-earnings (publisher principal))
  (ok (map-get? publisher-earnings publisher))
)

(define-read-only (get-campaign-impressions (campaign-id uint))
  (ok (map-get? campaign-impressions campaign-id))
)

(define-read-only (get-advertiser-campaigns (advertiser principal))
  (ok (map-get? advertiser-campaigns advertiser))
)
