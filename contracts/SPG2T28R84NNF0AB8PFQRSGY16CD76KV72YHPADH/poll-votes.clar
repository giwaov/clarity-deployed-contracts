;; Poll Votes
(define-map poll-votes {poll-id: uint, voter: principal} {option: uint, voted-at: uint})
(define-public (vote-poll (poll-id uint) (option uint) (voted-at uint))
  (begin (map-set poll-votes {poll-id: poll-id, voter: tx-sender} {option: option, voted-at: voted-at}) (ok true)))
(define-read-only (get-poll-vote (poll-id uint) (voter principal))
  (map-get? poll-votes {poll-id: poll-id, voter: voter}))
