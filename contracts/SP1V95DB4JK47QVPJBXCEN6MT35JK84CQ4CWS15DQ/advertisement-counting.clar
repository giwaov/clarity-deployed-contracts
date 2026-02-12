(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u1200))
(define-constant ERR_CAMPAIGN_NOT_FOUND (err u1201))
(define-constant ERR_TRACK_NOT_FOUND (err u1202))

(define-data-var next-campaign-id uint u1)

(define-map ad-campaigns
  uint
  {
    advertiser: principal,
    name: (string-ascii 128),
    budget: uint,
    reward-per-action: uint,
    start-time: uint,
    end-time: uint,
    active: bool
  }
)

(define-map user-tracking
  {campaign-id: uint, user: principal}
  {
    track-start-time: uint,
    track-end-time: uint,
    actions-completed: uint,
    rewards-earned: uint
  }
)

(define-map campaign-stats
  uint
  {
    total-users: uint,
    total-actions: uint,
    total-rewards: uint
  }
)

(define-read-only (get-contract-hash)
  (contract-hash? .advertisement-counting)
)

(define-read-only (get-campaign (campaign-id uint))
  (ok (unwrap! (map-get? ad-campaigns campaign-id) ERR_CAMPAIGN_NOT_FOUND))
)

(define-read-only (get-user-tracking (campaign-id uint) (user principal))
  (ok (map-get? user-tracking {campaign-id: campaign-id, user: user}))
)

(define-public (create-campaign 
  (name (string-ascii 128))
  (budget uint)
  (reward-per-action uint)
  (duration uint)
)
  (let
    (
      (campaign-id (var-get next-campaign-id))
      (start stacks-block-height)
    )
    (map-set ad-campaigns campaign-id {
      advertiser: tx-sender,
      name: name,
      budget: budget,
      reward-per-action: reward-per-action,
      start-time: start,
      end-time: (+ start duration),
      active: true
    })
    (map-set campaign-stats campaign-id {
      total-users: u0,
      total-actions: u0,
      total-rewards: u0
    })
    (var-set next-campaign-id (+ campaign-id u1))
    (ok campaign-id)
  )
)

(define-public (on-track-start (campaign-id uint))
  (let
    (
      (campaign-data (unwrap! (map-get? ad-campaigns campaign-id) ERR_CAMPAIGN_NOT_FOUND))
      (existing-track (map-get? user-tracking {campaign-id: campaign-id, user: tx-sender}))
    )
    (asserts! (get active campaign-data) ERR_NOT_AUTHORIZED)
    (asserts! (>= stacks-block-time (get start-time campaign-data)) ERR_NOT_AUTHORIZED)
    (asserts! (<= stacks-block-time (get end-time campaign-data)) ERR_NOT_AUTHORIZED)
    (if (is-none existing-track)
      (let
        (
          (stats (unwrap! (map-get? campaign-stats campaign-id) ERR_CAMPAIGN_NOT_FOUND))
        )
        (map-set campaign-stats campaign-id (merge stats {
          total-users: (+ (get total-users stats) u1)
        }))
        true
      )
      true
    )
    (map-set user-tracking 
      {campaign-id: campaign-id, user: tx-sender}
      {
        track-start-time: stacks-block-time,
        track-end-time: u0,
        actions-completed: u0,
        rewards-earned: u0
      }
    )
    (ok true)
  )
)

(define-public (on-track-end (campaign-id uint) (actions-completed uint))
  (let
    (
      (campaign-data (unwrap! (map-get? ad-campaigns campaign-id) ERR_CAMPAIGN_NOT_FOUND))
      (track-data (unwrap! (map-get? user-tracking {campaign-id: campaign-id, user: tx-sender}) ERR_TRACK_NOT_FOUND))
      (stats (unwrap! (map-get? campaign-stats campaign-id) ERR_CAMPAIGN_NOT_FOUND))
      (reward-amount (* actions-completed (get reward-per-action campaign-data)))
    )
    (map-set user-tracking 
      {campaign-id: campaign-id, user: tx-sender}
      (merge track-data {
        track-end-time: stacks-block-time,
        actions-completed: actions-completed,
        rewards-earned: reward-amount
      })
    )
    (map-set campaign-stats campaign-id (merge stats {
      total-actions: (+ (get total-actions stats) actions-completed),
      total-rewards: (+ (get total-rewards stats) reward-amount)
    }))
    (ok reward-amount)
  )
)

(define-public (claim-reward (campaign-id uint))
  (let
    (
      (track-data (unwrap! (map-get? user-tracking {campaign-id: campaign-id, user: tx-sender}) ERR_TRACK_NOT_FOUND))
      (campaign-data (unwrap! (map-get? ad-campaigns campaign-id) ERR_CAMPAIGN_NOT_FOUND))
    )
    (asserts! (> (get rewards-earned track-data) u0) ERR_NOT_AUTHORIZED)
    (try! (stx-transfer? (get rewards-earned track-data) CONTRACT_OWNER tx-sender))
    (map-set user-tracking 
      {campaign-id: campaign-id, user: tx-sender}
      (merge track-data {rewards-earned: u0})
    )
    (ok true)
  )
)

(define-read-only (get-campaign-stats (campaign-id uint))
  (ok (unwrap! (map-get? campaign-stats campaign-id) ERR_CAMPAIGN_NOT_FOUND))
)

(define-read-only (verify-signature-r1 (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (ok (secp256r1-verify message signature public-key))
)

(define-read-only (get-time)
  stacks-block-time
)
