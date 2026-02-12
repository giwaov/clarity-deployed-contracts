(define-data-var paused bool false)

(define-public (pause)
  (begin
    (var-set paused true)
    (ok true)
  )
)

(define-read-only (is-paused)
  (var-get paused)
)
