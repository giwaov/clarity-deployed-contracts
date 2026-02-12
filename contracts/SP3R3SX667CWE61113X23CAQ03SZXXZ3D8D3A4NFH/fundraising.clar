;; Fundraising Campaign Contract
;; A fundraising platform contract to accept crypto donations in STX or sBTC.
;; Supports multiple campaigns identified by a campaign-id.

;; Constants
;; NOTE: `contract-owner` is the deployer and is intended only for platform-level admin.
(define-constant contract-owner tx-sender)

(define-constant err-not-authorized (err u100))
(define-constant err-campaign-ended (err u101))
(define-constant err-not-initialized (err u102))
(define-constant err-not-cancelled (err u103))
(define-constant err-campaign-not-ended (err u104))
(define-constant err-campaign-cancelled (err u105))
(define-constant err-already-initialized (err u106))
(define-constant err-already-withdrawn (err u107))
(define-constant err-invalid-amount (err u108))
(define-constant err-campaign-not-found (err u109))
(define-constant err-invalid-end-at (err u110))

;; sBTC token contract (static identifier required by Clarity for contract-call?)
(define-constant sbtc-token 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token)

;; Default campaign duration in seconds (30 days).
(define-constant default-duration-secs u2592000)

;; Data vars
(define-data-var last-campaign-id uint u0)

;; Maps
(define-map campaigns
  uint
    {
    owner: principal,
    beneficiary: principal,
    goal: uint,
    start: uint,
    createdAt: uint,
    endAt: uint,
    duration: uint,
    totalStx: uint,
    totalSbtc: uint,
    donationCount: uint,
    isCancelled: bool,
    isWithdrawn: bool,
  }
)

(define-map stx-donations
    {
    campaignId: uint,
    donor: principal,
  }
  uint
)
;; (campaignId, donor) -> amount

(define-map sbtc-donations
    {
    campaignId: uint,
    donor: principal,
  }
  uint
)
;; (campaignId, donor) -> amount

;; In Clarity 4, `as-contract` was replaced by `as-contract?`.
;; We use it (with no allowances) to safely obtain the contract principal.
(define-private (get-contract-principal)
  (unwrap-panic (as-contract? () tx-sender))
)

;; Create a new campaign.
;; goal is informational (e.g. USD in UI).
;; endAt is an absolute timestamp in seconds (same basis as stacks-block-time).
;; Pass u0 to use default duration (30 days).
(define-public (create-campaign
    (goal uint)
    (endAt uint)
    (beneficiary principal)
  )
  (let (
      (campaignId (+ (var-get last-campaign-id) u1))
      (startAt stacks-block-time)
      (actual-end-at (if (is-eq endAt u0)
        (+ stacks-block-time default-duration-secs)
        endAt
      ))
    )
    (asserts! (> goal u0) err-invalid-amount)
    (asserts! (> actual-end-at startAt) err-invalid-end-at)
    (var-set last-campaign-id campaignId)
    (map-set campaigns campaignId {
      owner: tx-sender,
      beneficiary: beneficiary,
      goal: goal,
      start: burn-block-height,
      createdAt: startAt,
      endAt: actual-end-at,
      duration: (- actual-end-at startAt),
      totalStx: u0,
      totalSbtc: u0,
      donationCount: u0,
      isCancelled: false,
      isWithdrawn: false,
    })
    (print {
      event: "campaign-created",
      campaignId: campaignId,
      owner: tx-sender,
      beneficiary: beneficiary,
      goal: goal,
    })
    (ok campaignId)
  )
)

;; Cancel a campaign.
;; Only the campaign owner can call this, if not withdrawn.
(define-public (cancel-campaign (campaignId uint))
  (let ((campaign (unwrap! (map-get? campaigns campaignId) err-campaign-not-found)))
    (begin
      (asserts! (is-eq tx-sender (get owner campaign)) err-not-authorized)
      (asserts! (not (get isWithdrawn campaign)) err-already-withdrawn)
      (map-set campaigns campaignId (merge campaign { isCancelled: true }))
      (print {
        event: "campaign-cancelled",
        campaignId: campaignId,
      })
      (ok true)
    )
  )
)

;; Donate STX. Pass amount in microstacks.
(define-public (donate-stx
    (campaignId uint)
    (amount uint)
  )
  (let (
      (campaign (unwrap! (map-get? campaigns campaignId) err-campaign-not-found))
      (end (get endAt campaign))
      (donationKey {
        campaignId: campaignId,
        donor: tx-sender,
      })
    )
    (begin
      (asserts! (> amount u0) err-invalid-amount)
      (asserts! (not (get isCancelled campaign)) err-campaign-cancelled)
      (asserts! (< stacks-block-time end) err-campaign-ended)
      (try! (stx-transfer? amount tx-sender (get-contract-principal)))
      (map-set stx-donations donationKey
        (+ (default-to u0 (map-get? stx-donations donationKey)) amount)
      )
      (map-set campaigns campaignId
        (merge campaign {
          totalStx: (+ (get totalStx campaign) amount),
          donationCount: (+ (get donationCount campaign) u1),
        })
      )
      (print {
        event: "donated-stx",
        campaignId: campaignId,
        donor: tx-sender,
        amount: amount,
      })
      (ok true)
    )
  )
)

;; Donate sBTC. Pass amount in Satoshis.
(define-public (donate-sbtc
    (campaignId uint)
    (amount uint)
  )
  (let (
      (campaign (unwrap! (map-get? campaigns campaignId) err-campaign-not-found))
      (end (get endAt campaign))
      (donationKey {
        campaignId: campaignId,
        donor: tx-sender,
      })
    )
    (begin
      (asserts! (> amount u0) err-invalid-amount)
      (asserts! (not (get isCancelled campaign)) err-campaign-cancelled)
      (asserts! (< stacks-block-time end) err-campaign-ended)
      (try! (contract-call? sbtc-token transfer amount tx-sender
        (get-contract-principal) none
      ))
      (map-set sbtc-donations donationKey
        (+ (default-to u0 (map-get? sbtc-donations donationKey)) amount)
      )
      (map-set campaigns campaignId
        (merge campaign {
          totalSbtc: (+ (get totalSbtc campaign) amount),
          donationCount: (+ (get donationCount campaign) u1),
        })
      )
      (print {
        event: "donated-sbtc",
        campaignId: campaignId,
        donor: tx-sender,
        amount: amount,
      })
      (ok true)
    )
  )
)

;; Withdraw funds for a campaign (only beneficiary, only if campaign is ended)
(define-public (withdraw (campaignId uint))
  (let (
      (campaign (unwrap! (map-get? campaigns campaignId) err-campaign-not-found))
      (end (get endAt campaign))
      (total-stx-amount (get totalStx campaign))
      (total-sbtc-amount (get totalSbtc campaign))
      (beneficiary (get beneficiary campaign))
    )
    (begin
      (asserts! (not (get isCancelled campaign)) err-campaign-cancelled)
      (asserts! (not (get isWithdrawn campaign)) err-already-withdrawn)
      (asserts! (is-eq tx-sender beneficiary) err-not-authorized)
      (asserts! (>= stacks-block-time end) err-campaign-not-ended)
      (try! (as-contract? ((with-stx total-stx-amount) (with-ft sbtc-token "*" total-sbtc-amount))
        (begin
          (if (> total-stx-amount u0)
            (try! (stx-transfer? total-stx-amount tx-sender beneficiary))
            true
          )
          (if (> total-sbtc-amount u0)
            (try! (contract-call? sbtc-token transfer total-sbtc-amount tx-sender beneficiary none))
            true
          )
          true
        )
      ))
      (map-set campaigns campaignId
        (merge campaign {
          isWithdrawn: true,
          totalStx: u0,
          totalSbtc: u0,
        })
      )
      (print {
        event: "campaign-withdrawn",
        campaignId: campaignId,
      })
      (ok true)
    )
  )
)

;; Refund to donor for a cancelled campaign.
(define-public (refund (campaignId uint))
  (let (
      (campaign (unwrap! (map-get? campaigns campaignId) err-campaign-not-found))
      (donationKey {
        campaignId: campaignId,
        donor: tx-sender,
      })
      (stx-amount (default-to u0 (map-get? stx-donations donationKey)))
      (sbtc-amount (default-to u0 (map-get? sbtc-donations donationKey)))
      (contributor tx-sender)
    )
    (begin
      (asserts! (get isCancelled campaign) err-not-cancelled)
      (if (> stx-amount u0)
        (try! (as-contract? ((with-stx stx-amount))
          (begin
            (try! (stx-transfer? stx-amount tx-sender contributor))
            true
          )
        ))
        true
      )
      (if (> sbtc-amount u0)
        (try! (as-contract? ((with-ft sbtc-token "*" sbtc-amount))
          (begin
            (try! (contract-call? sbtc-token transfer sbtc-amount tx-sender contributor none))
            true
          )
        ))
        true
      )
      (map-delete stx-donations donationKey)
      (map-delete sbtc-donations donationKey)
      (map-set campaigns campaignId
        (merge campaign {
          totalStx: (if (>= (get totalStx campaign) stx-amount)
            (- (get totalStx campaign) stx-amount)
            u0
          ),
          totalSbtc: (if (>= (get totalSbtc campaign) sbtc-amount)
            (- (get totalSbtc campaign) sbtc-amount)
            u0
          ),
        })
      )
      (print {
        event: "refunded",
        campaignId: campaignId,
        donor: contributor,
      })
      (ok true)
    )
  )
)

;; Getter functions
(define-read-only (get-last-campaign-id)
  (ok (var-get last-campaign-id))
)

(define-read-only (get-stx-donation
    (campaignId uint)
    (donor principal)
  )
  (ok (default-to u0
    (map-get? stx-donations {
      campaignId: campaignId,
      donor: donor,
    })
  ))
)

(define-read-only (get-sbtc-donation
    (campaignId uint)
    (donor principal)
  )
  (ok (default-to u0
    (map-get? sbtc-donations {
      campaignId: campaignId,
      donor: donor,
    })
  ))
)

(define-read-only (get-campaign-info (campaignId uint))
  (let ((campaign (unwrap! (map-get? campaigns campaignId) err-campaign-not-found)))
    (ok {
      id: campaignId,
      owner: (get owner campaign),
      beneficiary: (get beneficiary campaign),
      startBlock: (get start campaign),
      start: (get createdAt campaign),
      end: (get endAt campaign),
      createdAt: (get createdAt campaign),
      endAt: (get endAt campaign),
      goal: (get goal campaign),
      totalStx: (get totalStx campaign),
      totalSbtc: (get totalSbtc campaign),
      donationCount: (get donationCount campaign),
      isExpired: (>= stacks-block-time (get endAt campaign)),
      isWithdrawn: (get isWithdrawn campaign),
      isCancelled: (get isCancelled campaign),
    })
  )
)

;; Clarity 4 helpers
(define-read-only (get-current-stacks-block-time)
  (ok stacks-block-time)
)

(define-read-only (get-campaign-created-at (campaignId uint))
  (let ((campaign (unwrap! (map-get? campaigns campaignId) err-campaign-not-found)))
    (ok (get createdAt campaign))
  )
)

(define-read-only (get-campaign-end-at (campaignId uint))
  (let ((campaign (unwrap! (map-get? campaigns campaignId) err-campaign-not-found)))
    (ok (get endAt campaign))
  )
)

(define-read-only (principal-to-ascii (p principal))
  (to-ascii? p)
)

(define-read-only (get-sbtc-token-contract)
  (ok sbtc-token)
)

(define-read-only (get-contract-balance)
  (stx-get-balance (get-contract-principal))
)
