;; title: wrapped-stx
;; version:
;; summary:
;; description:

;; Music Royalty Distribution Smart Contract

(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-INVALID-ROYALTY-PERCENTAGE (err u101))
(define-constant ERR-DUPLICATE-SONG-ENTRY (err u102))
(define-constant ERR-SONG-NOT-FOUND (err u103))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u104))
(define-constant ERR-INVALID-RECIPIENT (err u105))
(define-constant ERR-PAYMENT-DISTRIBUTION-FAILED (err u106))
(define-constant ERR-INVALID-STRING-LENGTH (err u107))
(define-constant ERR-INVALID-SONG-TITLE (err u108))
(define-constant ERR-INVALID-PARTICIPANT-ROLE (err u109))
(define-constant ERR-INVALID-ARTIST (err u110))
(define-constant ERR-INVALID-ADMIN (err u111))

;; Data Structures for Music Rights Management
(define-map music-catalog
  { song-id: uint }
  {
    title: (string-ascii 50),
    primary-artist: principal,
    total-revenue: uint,
    release-date: uint,
    is-active: bool,
  }
)

(define-map royalty-allocations
  {
    song-id: uint,
    rights-holder: principal,
  }
  {
    percentage: uint,
    role: (string-ascii 20),
    earned-royalties: uint,
  }
)

;; Contract State Variables
(define-data-var total-registered-tracks uint u0)
(define-data-var contract-owner principal tx-sender)

;; Validation Helpers
(define-private (is-valid-royalty-share (share {
  percentage: uint,
  role: (string-ascii 20),
  earned-royalties: uint,
}))
  (> (get percentage share) u0)
)

(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (validate-royalty-percentage (percentage uint))
  (and (>= percentage u0) (<= percentage u100))
)

(define-private (validate-ascii-string (input (string-ascii 50)))
  (let ((length (len input)))
    (and (> length u0) (<= length u50))
  )
)

(define-private (validate-participant-role (role (string-ascii 20)))
  (let ((length (len role)))
    (and (> length u0) (<= length u20))
  )
)

(define-private (validate-rights-holder (holder principal))
  (and
    (not (is-eq holder tx-sender))
    (not (is-eq holder (var-get contract-owner)))
  )
)

;; Read-Only Query Functions
(define-read-only (get-track-details (song-id uint))
  (map-get? music-catalog { song-id: song-id })
)

(define-read-only (get-royalty-details
    (song-id uint)
    (rights-holder principal)
  )
  (map-get? royalty-allocations {
    song-id: song-id,
    rights-holder: rights-holder,
  })
)

(define-read-only (get-total-tracks)
  (var-get total-registered-tracks)
)

(define-read-only (get-track-royalty-shares (song-id uint))
  (let (
      (track-info (get-track-details song-id))
      (primary-artist (match track-info
        record (get primary-artist record)
        tx-sender
      ))
    )
    (let ((distribution (get-royalty-details song-id primary-artist)))
      (match distribution
        share (list {
          rights-holder: primary-artist,
          percentage: (get percentage share),
        })
        (list)
      )
    )
  )
)

;; Royalty Distribution Mechanism
(define-private (calculate-rights-holder-payment
    (rights-share {
      rights-holder: principal,
      percentage: uint,
    })
    (total-payment uint)
  )
  (let ((holder-payment (/ (* total-payment (get percentage rights-share)) u100)))
    (if (> holder-payment u0)
      (match (stx-transfer? holder-payment tx-sender (get rights-holder rights-share))
        success total-payment
        error u0
      )
      u0
    )
  )
)

(define-private (distribute-royalties
    (song-id uint)
    (total-payment uint)
  )
  (let (
      (royalty-distribution-list (get-track-royalty-shares song-id))
      (total-distributed (fold calculate-rights-holder-payment royalty-distribution-list
        total-payment
      ))
    )
    (begin
      (asserts! (> (len royalty-distribution-list) u0) ERR-SONG-NOT-FOUND)
      (asserts! (> total-distributed u0) ERR-PAYMENT-DISTRIBUTION-FAILED)
      (ok total-distributed)
    )
  )
)

;; Administrative Functions
(define-public (register-track
    (track-title (string-ascii 50))
    (primary-artist principal)
  )
  (let ((new-track-id (+ (var-get total-registered-tracks) u1)))
    (begin
      (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
      (asserts! (validate-ascii-string track-title) ERR-INVALID-SONG-TITLE)
      (asserts! (validate-rights-holder primary-artist) ERR-INVALID-ARTIST)

      (map-set music-catalog { song-id: new-track-id } {
        title: track-title,
        primary-artist: primary-artist,
        total-revenue: u0,
        release-date: stacks-block-height,
        is-active: true,
      })
      (var-set total-registered-tracks new-track-id)
      (ok new-track-id)
    )
  )
)

(define-public (set-royalty-allocation
    (song-id uint)
    (rights-holder principal)
    (percentage uint)
    (participant-role (string-ascii 20))
  )
  (let ((track-record (get-track-details song-id)))
    (begin
      (asserts! (is-some track-record) ERR-SONG-NOT-FOUND)
      (asserts! (validate-royalty-percentage percentage)
        ERR-INVALID-ROYALTY-PERCENTAGE
      )
      (asserts! (validate-participant-role participant-role)
        ERR-INVALID-PARTICIPANT-ROLE
      )
      (asserts! (validate-rights-holder rights-holder) ERR-INVALID-RECIPIENT)

      (map-set royalty-allocations {
        song-id: song-id,
        rights-holder: rights-holder,
      } {
        percentage: percentage,
        role: participant-role,
        earned-royalties: u0,
      })
      (ok true)
    )
  )
)

(define-public (process-royalty-payment
    (song-id uint)
    (payment-amount uint)
  )
  (let ((track-record (get-track-details song-id)))
    (begin
      (asserts! (is-some track-record) ERR-SONG-NOT-FOUND)
      (asserts! (>= (stx-get-balance tx-sender) payment-amount)
        ERR-INSUFFICIENT-PAYMENT
      )

      (try! (distribute-royalties song-id payment-amount))
      (map-set music-catalog { song-id: song-id }
        (merge (unwrap-panic track-record) { total-revenue: (+ (get total-revenue (unwrap-panic track-record)) payment-amount) })
      )
      (ok true)
    )
  )
)

(define-public (update-track-status
    (song-id uint)
    (is-active bool)
  )
  (let ((track-record (get-track-details song-id)))
    (begin
      (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
      (asserts! (is-some track-record) ERR-SONG-NOT-FOUND)

      (map-set music-catalog { song-id: song-id }
        (merge (unwrap-panic track-record) { is-active: is-active })
      )
      (ok true)
    )
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (validate-rights-holder new-owner) ERR-INVALID-ADMIN)

    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Contract Initialization
(begin
  (var-set total-registered-tracks u0)
)
