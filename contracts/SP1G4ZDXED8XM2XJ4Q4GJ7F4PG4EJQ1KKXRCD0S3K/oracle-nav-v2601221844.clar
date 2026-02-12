(define-constant ERR-UNAUTHORIZED u100)

(define-data-var governor principal tx-sender)

(define-map navs
  { vault: principal }
  { nav: uint, updated-at: uint }
)

(define-read-only (is-governor)
  (is-eq tx-sender (var-get governor))
)

(define-public (set-governor (new-governor principal))
  (begin
    (asserts! (is-governor) (err ERR-UNAUTHORIZED))
    (var-set governor new-governor)
    (ok true)
  )
)

(define-read-only (get-nav (vault principal))
  (map-get? navs { vault: vault })
)

(define-public (set-nav (vault principal) (nav uint))
  (begin
    (asserts! (is-governor) (err ERR-UNAUTHORIZED))
    (map-set navs { vault: vault } { nav: nav, updated-at: u0 })
    (ok true)
  )
)
