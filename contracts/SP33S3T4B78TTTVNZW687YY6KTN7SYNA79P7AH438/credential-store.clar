;; Music Royalty Distribution Smart Contract
;; This contract manages music royalty distributions among artists, producers, and rights holders

;; Error codes
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-INVALID-ROYALTY-PERCENTAGE (err u101))
(define-constant ERR-DUPLICATE-SONG-ENTRY (err u102))
(define-constant ERR-SONG-DOES-NOT-EXIST (err u103))
(define-constant ERR-INSUFFICIENT-PAYMENT-FUNDS (err u104))
(define-constant ERR-INVALID-ROYALTY-RECIPIENT (err u105))
(define-constant ERR-PAYMENT-FAILED (err u106))
(define-constant ERR-INVALID-STRING-LENGTH (err u107))
(define-constant ERR-INVALID-SONG-TITLE (err u108))
(define-constant ERR-INVALID-PARTICIPANT-ROLE (err u109))
(define-constant ERR-INVALID-PRIMARY-ARTIST (err u110))
(define-constant ERR-INVALID-ADMINISTRATOR (err u111))

;; Data structures
(define-map RegisteredSongs
  { song-identifier: uint }
  {
    song-title: (string-ascii 50),
    primary-artist: principal,
    accumulated-revenue: uint,
    publication-date: uint,
    song-status-active: bool,
  }
)

(define-map RoyaltyDistribution
  {
    song-identifier: uint,
    royalty-recipient: principal,
  }
  {
    royalty-percentage: uint,
    participant-role: (string-ascii 20),
    accumulated-earnings: uint,
  }
)

;; Track total registered songs
(define-data-var registered-song-count uint u0)

;; Track contract administrator
(define-data-var contract-administrator principal tx-sender)

;; Read-only functions
(define-read-only (get-song-information (song-identifier uint))
  (map-get? RegisteredSongs { song-identifier: song-identifier })
)

(define-read-only (get-royalty-distribution
    (song-identifier uint)
    (royalty-recipient principal)
  )
  (map-get? RoyaltyDistribution {
    song-identifier: song-identifier,
    royalty-recipient: royalty-recipient,
  })
)

(define-read-only (get-total-registered-songs)
  (var-get registered-song-count)
)

;; Get royalty shares for a song
(define-read-only (get-royalty-shares-by-song (song-identifier uint))
  (let (
      (song-info (get-song-information song-identifier))
      (primary-artist (match song-info
        record (get primary-artist record)
        tx-sender
      ))
    )
    (let ((distribution (get-royalty-distribution song-identifier primary-artist)))
      (match distribution
        share (list {
          royalty-recipient: primary-artist,
          royalty-percentage: (get royalty-percentage share),
        })
        (list)
      )
    )
  )
)

;; Helper functions for input validation
(define-private (is-valid-royalty-share (share {
  royalty-percentage: uint,
  participant-role: (string-ascii 20),
  accumulated-earnings: uint,
}))
  (> (get royalty-percentage share) u0)
)

(define-private (verify-contract-administrator)
  (is-eq tx-sender (var-get contract-administrator))
)

(define-private (validate-royalty-percentage (royalty-percentage uint))
  (and (>= royalty-percentage u0) (<= royalty-percentage u100))
)

(define-private (validate-string-ascii (input (string-ascii 50)))
  (let ((length (len input)))
    (and (> length u0) (<= length u50))
  )
)

(define-private (validate-participant-role (role (string-ascii 20)))
  (let ((length (len role)))
    (and (> length u0) (<= length u20))
  )
)

(define-private (validate-principal (principal-to-check principal))
  (and
    (not (is-eq principal-to-check tx-sender)) ;; Can't be the sender
    (not (is-eq principal-to-check (var-get contract-administrator))) ;; Can't be the admin
  )
)

;; Fixed process-royalty-share function
(define-private (process-royalty-share
    (share {
      royalty-recipient: principal,
      royalty-percentage: uint,
    })
    (payment-amount uint)
  )
  (let ((recipient-payment-amount (/ (* payment-amount (get royalty-percentage share)) u100)))
    (if (> recipient-payment-amount u0)
      (match (stx-transfer? recipient-payment-amount tx-sender
        (get royalty-recipient share)
      )
        success payment-amount
        error u0
      )
      u0
    )
  )
)

;; Updated distribute-royalty-payment
(define-private (distribute-royalty-payment
    (song-identifier uint)
    (payment-amount uint)
  )
  (let (
      (royalty-distribution-list (get-royalty-shares-by-song song-identifier))
      (total-distributed (fold process-royalty-share royalty-distribution-list payment-amount))
    )
    (begin
      (asserts! (> (len royalty-distribution-list) u0) ERR-SONG-DOES-NOT-EXIST)
      (asserts! (> total-distributed u0) ERR-PAYMENT-FAILED)
      (ok total-distributed)
    )
  )
)

;; Public functions with added input validation
(define-public (register-new-song
    (song-title (string-ascii 50))
    (primary-artist principal)
  )
  (let ((new-song-identifier (+ (var-get registered-song-count) u1)))
    (begin
      (asserts! (verify-contract-administrator) ERR-UNAUTHORIZED-ACCESS)
      (asserts! (validate-string-ascii song-title) ERR-INVALID-SONG-TITLE)
      (asserts! (validate-principal primary-artist) ERR-INVALID-PRIMARY-ARTIST)

      (map-set RegisteredSongs { song-identifier: new-song-identifier } {
        song-title: song-title,
        primary-artist: primary-artist,
        accumulated-revenue: u0,
        publication-date: stacks-block-height,
        song-status-active: true,
      })
      (var-set registered-song-count new-song-identifier)
      (ok new-song-identifier)
    )
  )
)

(define-public (set-royalty-distribution
    (song-identifier uint)
    (royalty-recipient principal)
    (royalty-percentage uint)
    (participant-role (string-ascii 20))
  )
  (let ((song-record (get-song-information song-identifier)))
    (begin
      (asserts! (is-some song-record) ERR-SONG-DOES-NOT-EXIST)
      (asserts! (validate-royalty-percentage royalty-percentage)
        ERR-INVALID-ROYALTY-PERCENTAGE
      )
      (asserts! (validate-participant-role participant-role)
        ERR-INVALID-PARTICIPANT-ROLE
      )
      (asserts! (validate-principal royalty-recipient)
        ERR-INVALID-ROYALTY-RECIPIENT
      )

      (map-set RoyaltyDistribution {
        song-identifier: song-identifier,
        royalty-recipient: royalty-recipient,
      } {
        royalty-percentage: royalty-percentage,
        participant-role: participant-role,
        accumulated-earnings: u0,
      })
      (ok true)
    )
  )
)

(define-public (process-royalty-payment
    (song-identifier uint)
    (royalty-payment-amount uint)
  )
  (let ((song-record (get-song-information song-identifier)))
    (begin
      (asserts! (is-some song-record) ERR-SONG-DOES-NOT-EXIST)
      (asserts! (>= (stx-get-balance tx-sender) royalty-payment-amount)
        ERR-INSUFFICIENT-PAYMENT-FUNDS
      )

      (try! (distribute-royalty-payment song-identifier royalty-payment-amount))
      (map-set RegisteredSongs { song-identifier: song-identifier }
        (merge (unwrap-panic song-record) { accumulated-revenue: (+ (get accumulated-revenue (unwrap-panic song-record))
          royalty-payment-amount
        ) }
        ))
      (ok true)
    )
  )
)

(define-public (update-song-active-status
    (song-identifier uint)
    (new-active-status bool)
  )
  (let ((song-record (get-song-information song-identifier)))
    (begin
      (asserts! (verify-contract-administrator) ERR-UNAUTHORIZED-ACCESS)
      (asserts! (is-some song-record) ERR-SONG-DOES-NOT-EXIST)

      (map-set RegisteredSongs { song-identifier: song-identifier }
        (merge (unwrap-panic song-record) { song-status-active: new-active-status })
      )
      (ok true)
    )
  )
)

(define-public (transfer-administrator-rights (new-administrator principal))
  (begin
    (asserts! (verify-contract-administrator) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (validate-principal new-administrator) ERR-INVALID-ADMINISTRATOR)

    (var-set contract-administrator new-administrator)
    (ok true)
  )
)

;; Contract initialization
(begin
  (var-set registered-song-count u0)
)
