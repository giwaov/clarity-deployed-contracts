(define-map rewards principal uint)

(define-public (add-reward (user principal) (amount uint))
  (begin
    (map-set rewards user (+ amount (default-to u0 (map-get? rewards user))))
    (ok amount)
  )
)
