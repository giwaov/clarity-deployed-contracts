(define-data-var next-round-id uint u0)
(define-data-var paused bool false)
(define-data-var admin (optional principal) none)

(define-private (is-admin (p principal))
  (match (var-get admin)
    admin-p (is-eq p admin-p)
    false))

(define-public (init-admin (p principal))
  (if (is-none (var-get admin))
      (begin (var-set admin (some p)) (ok true))
      (err u1002)))
(define-map rounds {id: uint} {topic: uint, pool: uint})
(define-map pledges {round: uint, submission: uint, pledger: principal} {amount: uint})

(define-public (create-round (topic uint) (pool uint))
  (if (var-get paused)
      (err u1000)
      (begin
        (var-set next-round-id (+ (var-get next-round-id) u1))
        (map-set rounds {id: (var-get next-round-id)} {topic: topic, pool: pool})
        (ok (var-get next-round-id))
      )))

(define-public (pledge (round uint) (submission uint) (amount uint))
  (if (var-get paused)
      (err u1000)
      (begin
        (map-set pledges {round: round, submission: submission, pledger: tx-sender} {amount: amount})
        (ok true)
      )))

(define-public (pause)
  (if (is-admin tx-sender)
      (begin (var-set paused true) (ok true))
      (err u1003)))

(define-public (unpause)
  (if (is-admin tx-sender)
      (begin (var-set paused false) (ok true))
      (err u1003)))
