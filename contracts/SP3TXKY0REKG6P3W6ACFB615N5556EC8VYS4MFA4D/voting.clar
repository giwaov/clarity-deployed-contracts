;; simple-voting.clar

(define-constant ERR-ALREADY-VOTED u101)

(define-data-var yes uint u0)
(define-data-var no uint u0)
(define-map voted {voter: principal} {v: bool})

(define-public (vote-yes)
  (if (is-some (map-get? voted {voter: tx-sender}))
    (err ERR-ALREADY-VOTED)
    (begin
      (map-set voted {voter: tx-sender} {v: true})
      (var-set yes (+ (var-get yes) u1))
      (ok true))))

(define-public (vote-no)
  (if (is-some (map-get? voted {voter: tx-sender}))
    (err ERR-ALREADY-VOTED)
    (begin
      (map-set voted {voter: tx-sender} {v: true})
      (var-set no (+ (var-get no) u1))
      (ok true))))

(define-read-only (get-results)
  (ok {yes: (var-get yes), no: (var-get no)}))
