;; Endorsement System - Endorse users
(define-map endorsements {endorser: principal, endorsee: principal} {count: uint})

(define-public (endorse-user (endorsee principal))
  (let ((current (default-to u0 (get count (map-get? endorsements {endorser: tx-sender, endorsee: endorsee})))))
    (map-set endorsements {endorser: tx-sender, endorsee: endorsee} {count: (+ current u1)})
    (ok true)))

(define-read-only (get-endorsement (endorser principal) (endorsee principal))
  (map-get? endorsements {endorser: endorser, endorsee: endorsee}))
