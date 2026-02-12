(define-data-var counter uint u0)

(define-map user-counts
  principal
  uint
)

(define-public (increment)
  (begin
    (var-set counter (+ (var-get counter) u1))
    (ok (var-get counter))
  )
)

(define-public (decrement)
  (begin
    (var-set counter (- (var-get counter) u1))
    (ok (var-get counter))
  )
)

(define-public (increment-user-count)
  (let ((current (default-to u0 (map-get? user-counts tx-sender))))
    (map-set user-counts tx-sender (+ current u1))
    (ok (+ current u1))
  )
)

(define-read-only (get-counter)
  (ok (var-get counter))
)

(define-read-only (get-user-count (user principal))
  (ok (default-to u0 (map-get? user-counts user)))
)
