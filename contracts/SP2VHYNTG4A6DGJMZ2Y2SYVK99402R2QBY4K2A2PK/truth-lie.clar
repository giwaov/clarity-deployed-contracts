(define-data-var truth-count uint u0)
(define-data-var lie-count uint u0)

(define-public (vote-truth)
  (begin
    (var-set truth-count (+ (var-get truth-count) u1))
    (ok "Truth")
  )
)

(define-public (vote-lie)
  (begin
    (var-set lie-count (+ (var-get lie-count) u1))
    (ok "Lie")
  )
)

(define-read-only (final-results)
  {
    truth: (var-get truth-count),
    lie: (var-get lie-count)
  }
)
