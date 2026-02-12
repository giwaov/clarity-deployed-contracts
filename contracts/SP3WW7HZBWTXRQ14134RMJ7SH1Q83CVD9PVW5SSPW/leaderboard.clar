;; Leaderboard
;; Gaming leaderboard system

(define-constant contract-owner tx-sender)

(define-map player-scores principal uint)
(define-map player-ranks principal uint)

(define-read-only (get-score (player principal))
  (default-to u0 (map-get? player-scores player))
)

(define-read-only (get-rank (player principal))
  (default-to u0 (map-get? player-ranks player))
)

(define-public (update-score (player principal) (score uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err u100))
    (map-set player-scores player score)
    (ok score)
  )
)

(define-public (update-rank (player principal) (rank uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err u100))
    (map-set player-ranks player rank)
    (ok rank)
  )
)
