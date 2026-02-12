(define-map user-gm-stats principal {
  total-gms: uint,
  last-gm-block: uint,
  last-gm-timestamp: uint
})

(define-map daily-gm-count uint uint)

(define-map recent-gms uint {
  user: principal,
  block-height: uint,
  timestamp: uint
})

(define-data-var next-gm-id uint u0)
(define-data-var total-gms-alltime uint u0)

(define-constant BLOCKS_PER_DAY u144)

(define-public (say-gm)
  (let
    (
      (sender tx-sender)
      (current-block burn-block-height)
      (gm-id (var-get next-gm-id))
      (day-number (/ current-block BLOCKS_PER_DAY))
      (user-stats (default-to
        {total-gms: u0, last-gm-block: u0, last-gm-timestamp: u0}
        (map-get? user-gm-stats sender)))
      (daily-count (default-to u0 (map-get? daily-gm-count day-number)))
      (current-timestamp stacks-block-time)
    )
    (map-set user-gm-stats sender {
      total-gms: (+ (get total-gms user-stats) u1),
      last-gm-block: current-block,
      last-gm-timestamp: current-timestamp
    })
    (map-set daily-gm-count day-number (+ daily-count u1))
    (map-set recent-gms gm-id {
      user: sender,
      block-height: current-block,
      timestamp: current-timestamp
    })
    (var-set next-gm-id (+ gm-id u1))
    (var-set total-gms-alltime (+ (var-get total-gms-alltime) u1))
    (ok gm-id)
  )
)

(define-read-only (get-user-stats (user principal))
  (ok (default-to
    {total-gms: u0, last-gm-block: u0, last-gm-timestamp: u0}
    (map-get? user-gm-stats user)))
)

(define-read-only (get-user-total-gms (user principal))
  (ok (get total-gms (default-to
    {total-gms: u0, last-gm-block: u0, last-gm-timestamp: u0}
    (map-get? user-gm-stats user))))
)

(define-read-only (get-daily-gm-count)
  (let ((day-number (/ burn-block-height BLOCKS_PER_DAY)))
    (ok (default-to u0 (map-get? daily-gm-count day-number))))
)

(define-read-only (get-daily-gm-count-for-day (day uint))
  (ok (default-to u0 (map-get? daily-gm-count day)))
)

(define-read-only (get-total-gms-alltime)
  (ok (var-get total-gms-alltime))
)

(define-read-only (get-last-three-gms)
  (let
    (
      (total (var-get next-gm-id))
      (last-id (if (> total u0) (- total u1) u0))
      (second-id (if (> total u1) (- total u2) u0))
      (third-id (if (> total u2) (- total u3) u0))
    )
    (ok {
      first: (map-get? recent-gms last-id),
      second: (map-get? recent-gms second-id),
      third: (map-get? recent-gms third-id)
    })
  )
)

(define-read-only (get-gm-by-id (gm-id uint))
  (ok (map-get? recent-gms gm-id))
)

(define-read-only (get-current-day)
  (ok (/ burn-block-height BLOCKS_PER_DAY))
)

(define-read-only (get-total-gms-as-string)
  (to-ascii? (var-get total-gms-alltime))
)

(define-read-only (get-user-gm-count-as-string (user principal))
  (let
    (
      (user-stats (default-to
        {total-gms: u0, last-gm-block: u0, last-gm-timestamp: u0}
        (map-get? user-gm-stats user)))
    )
    (to-ascii? (get total-gms user-stats))
  )
)

(define-read-only (get-user-last-gm-timestamp (user principal))
  (let
    (
      (user-stats (default-to
        {total-gms: u0, last-gm-block: u0, last-gm-timestamp: u0}
        (map-get? user-gm-stats user)))
    )
    (ok (get last-gm-timestamp user-stats))
  )
)
