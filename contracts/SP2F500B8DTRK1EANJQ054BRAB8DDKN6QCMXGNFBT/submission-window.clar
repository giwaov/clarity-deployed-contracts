(define-data-var closes-at uint u0)

(define-public (set-window (end uint))
  (begin (var-set closes-at end) (ok end))
)

(define-read-only (is-open)
  (> (var-get closes-at) burn-block-height)
)
