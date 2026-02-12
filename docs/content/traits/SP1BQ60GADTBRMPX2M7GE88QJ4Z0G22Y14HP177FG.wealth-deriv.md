---
title: "Trait wealth-deriv"
draft: true
---
```
;; title: wealth-deriv
;; version:
;; summary:
;; description:

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-listed (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-not-authorized (err u104))
(define-constant err-kyc-required (err u105))
(define-constant err-vote-exists (err u106))
(define-constant err-vote-ended (err u107))
(define-constant err-price-expired (err u108))

(define-constant MAX-ASSET-VALUE u1000000000000) ;; 1 trillion
(define-constant MIN-ASSET-VALUE u1000) ;; 1 thousand
(define-constant MAX-DURATION u144) ;; ~1 day in blocks
(define-constant MIN-DURATION u12) ;; ~1 hour in blocks
(define-constant MAX-KYC-LEVEL u5)
(define-constant MAX-EXPIRY u52560) ;; ~1 year in blocks

;; Add new error codes
(define-constant err-invalid-uri (err u110))
(define-constant err-invalid-value (err u111))
(define-constant err-invalid-duration (err u112))
(define-constant err-invalid-kyc-level (err u113))
(define-constant err-invalid-expiry (err u114))
(define-constant err-invalid-votes (err u115))
(define-constant err-invalid-address (err u116))
(define-constant err-invalid-title (err u117))

;; Data Maps
(define-map assets
  { asset-id: uint }
  {
    owner: principal,
    metadata-uri: (string-ascii 256),
    asset-value: uint,
    is-locked: bool,
    creation-height: uint,
    last-price-update: uint,
    total-dividends: uint,
  }
)

(define-map token-balances
  {
    owner: principal,
    asset-id: uint,
  }
  { balance: uint }
)

(define-map kyc-status
  { address: principal }
  {
    is-approved: bool,
    level: uint,
    expiry: uint,
  }
)

(define-map proposals
  { proposal-id: uint }
  {
    title: (string-ascii 256),
    asset-id: uint,
    start-height: uint,
    end-height: uint,
    executed: bool,
    votes-for: uint,
    votes-against: uint,
    minimum-votes: uint,
  }
)

(define-map votes
  {
    proposal-id: uint,
    voter: principal,
  }
  { vote-amount: uint }
)

(define-map dividend-claims
  {
    asset-id: uint,
    claimer: principal,
  }
  { last-claimed-amount: uint }
)

(define-map price-feeds
  { asset-id: uint }
  {
    price: uint,
    decimals: uint,
    last-updated: uint,
    oracle: principal,
  }
)

;; SFTs per asset
(define-constant tokens-per-asset u100000)

;; Helper functions for input validation
(define-private (validate-asset-value (value uint))
  (and
    (>= value MIN-ASSET-VALUE)
    (<= value MAX-ASSET-VALUE)
  )
)

(define-private (validate-duration (duration uint))
  (and
    (>= duration MIN-DURATION)
    (<= duration MAX-DURATION)
  )
)

(define-private (validate-kyc-level (level uint))
  (<= level MAX-KYC-LEVEL)
)

(define-private (validate-expiry (expiry uint))
  (and
    (> expiry stacks-block-height)
    (<= (- expiry stacks-block-height) MAX-EXPIRY)
  )
)

(define-private (validate-minimum-votes (vote-count uint))
  (and
    (> vote-count u0)
    (<= vote-count tokens-per-asset)
  )
)

(define-private (validate-metadata-uri (uri (string-ascii 256)))
  (and
    (> (len uri) u0)
    (<= (len uri) u256)
  )
)

(define-public (register-asset
    (metadata-uri (string-ascii 256))
    (asset-value uint)
  )
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (validate-metadata-uri metadata-uri) err-invalid-uri)
    (asserts! (validate-asset-value asset-value) err-invalid-value)

    (let ((asset-id (get-next-asset-id)))
      (map-set assets { asset-id: asset-id } {
        owner: contract-owner,
        metadata-uri: metadata-uri,
        asset-value: asset-value,
        is-locked: false,
        creation-height: stacks-block-height,
        last-price-update: stacks-block-height,
        total-dividends: u0,
      })
      (map-set token-balances {
        owner: contract-owner,
        asset-id: asset-id,
      } { balance: tokens-per-asset }
      )
      (ok asset-id)
    )
  )
)

;; Read Functions
(define-read-only (get-asset-info (asset-id uint))
  (map-get? assets { asset-id: asset-id })
)

(define-read-only (get-balance
    (owner principal)
    (asset-id uint)
  )
  (default-to u0
    (get balance
      (map-get? token-balances {
        owner: owner,
        asset-id: asset-id,
      })
    ))
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

(define-read-only (get-vote
    (proposal-id uint)
    (voter principal)
  )
  (map-get? votes {
    proposal-id: proposal-id,
    voter: voter,
  })
)

(define-read-only (get-price-feed (asset-id uint))
  (map-get? price-feeds { asset-id: asset-id })
)

(define-read-only (get-last-claim
    (asset-id uint)
    (claimer principal)
  )
  (default-to u0
    (get last-claimed-amount
      (map-get? dividend-claims {
        asset-id: asset-id,
        claimer: claimer,
      })
    ))
)

;; Private Functions
(define-private (get-next-asset-id)
  (default-to u1 (get-last-asset-id))
)

(define-private (get-next-proposal-id)
  (default-to u1 (get-last-proposal-id))
)

(define-private (get-last-asset-id)
  none
)

(define-private (get-last-proposal-id)
  none
)

(define-public (claim-dividends (asset-id uint))
  (let (
      (asset (unwrap! (get-asset-info asset-id) err-not-found))
      (balance (get-balance tx-sender asset-id))
      (last-claim (get-last-claim asset-id tx-sender))
      (total-dividends (get total-dividends asset))
      (claimable-amount (/ (* balance (- total-dividends last-claim)) tokens-per-asset))
    )
    (asserts! (> claimable-amount u0) err-invalid-amount)
    (ok (map-set dividend-claims {
      asset-id: asset-id,
      claimer: tx-sender,
    } { last-claimed-amount: total-dividends }
    ))
  )
)

(define-public (create-proposal
    (asset-id uint)
    (title (string-ascii 256))
    (duration uint)
    (minimum-votes uint)
  )
  (begin
    (asserts! (validate-duration duration) err-invalid-duration)
    (asserts! (validate-minimum-votes minimum-votes) err-invalid-votes)
    (asserts! (validate-metadata-uri title) err-invalid-title)
    (asserts! (>= (get-balance tx-sender asset-id) (/ tokens-per-asset u10))
      err-not-authorized
    )

    (let ((proposal-id (get-next-proposal-id)))
      (ok (map-set proposals { proposal-id: proposal-id } {
        title: title,
        asset-id: asset-id,
        start-height: stacks-block-height,
        end-height: (+ stacks-block-height duration),
        executed: false,
        votes-for: u0,
        votes-against: u0,
        minimum-votes: minimum-votes,
      }))
    )
  )
)

(define-public (vote
    (proposal-id uint)
    (vote-for bool)
    (amount uint)
  )
  (let (
      (proposal (unwrap! (get-proposal proposal-id) err-not-found))
      (asset-id (get asset-id proposal))
      (balance (get-balance tx-sender asset-id))
    )
    (begin
      (asserts! (>= balance amount) err-invalid-amount)
      (asserts! (< stacks-block-height (get end-height proposal)) err-vote-ended)
      (asserts! (is-none (get-vote proposal-id tx-sender)) err-vote-exists)

      (map-set votes {
        proposal-id: proposal-id,
        voter: tx-sender,
      } { vote-amount: amount }
      )
      (ok (map-set proposals { proposal-id: proposal-id }
        (merge proposal {
          votes-for: (if vote-for
            (+ (get votes-for proposal) amount)
            (get votes-for proposal)
          ),
          votes-against: (if vote-for
            (get votes-against proposal)
            (+ (get votes-against proposal) amount)
          ),
        })
      ))
    )
  )
)

```
