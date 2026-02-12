;; Voting System
(define-map votes {proposal-id: uint, voter: principal} {vote: bool, weight: uint, cast-at: uint})
(define-public (cast-vote (proposal-id uint) (vote bool) (weight uint) (cast-at uint))
  (begin (map-set votes {proposal-id: proposal-id, voter: tx-sender} {vote: vote, weight: weight, cast-at: cast-at}) (ok true)))
(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes {proposal-id: proposal-id, voter: voter}))
