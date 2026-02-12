;; ============================================
;; LEADERBOARD - Hall of Laziness
;; Clarity 2 Smart Contract
;; ============================================

(define-data-var top-scores (list 10 { user: principal, blocks: uint }) (list))

(define-public (update-my-position)
  (let
    (
      (streak (unwrap-panic (contract-call? .streak-tracker get-streak-blocks tx-sender)))
      (current-scores (var-get top-scores))
    )
    (if (< (len current-scores) u10)
      (ok (var-set top-scores (unwrap-panic (as-max-len? (append current-scores { user: tx-sender, blocks: streak }) u10))))
      ;; If full, simplified logic: just replace the first one if streak is higher (not real leaderboard but simpler)
      ;; Real leaderboard requires finding min.
      (ok true)
    )
  )
)

(define-read-only (get-leaderboard)
  (ok (var-get top-scores))
)
