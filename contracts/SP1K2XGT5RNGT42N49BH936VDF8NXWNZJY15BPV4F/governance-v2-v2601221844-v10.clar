(define-constant ERR-UNAUTHORIZED u100)

(define-data-var governor principal tx-sender)
(define-data-var paused bool false)

(define-read-only (is-governor (who principal))
  (is-eq who (var-get governor))
)

(define-read-only (is-paused)
  (var-get paused)
)

(define-public (set-governor (new-governor principal))
  (begin
    (asserts! (is-eq tx-sender (var-get governor)) (err ERR-UNAUTHORIZED))
    (var-set governor new-governor)
    (ok true)
  )
)

(define-public (set-paused (flag bool))
  (begin
    (asserts! (is-eq tx-sender (var-get governor)) (err ERR-UNAUTHORIZED))
    (var-set paused flag)
    (ok true)
  )
)
