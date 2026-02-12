;; Greeter contract

(define-data-var greeting (string-utf8 100) u"Hello, World!")

(define-read-only (get-greeting)
  (ok (var-get greeting))
)

(define-public (set-greeting (new-greeting (string-utf8 100)))
  (begin
    (asserts! (> (len new-greeting) u0) (err u1))
    (var-set greeting new-greeting)
    (ok new-greeting)
  )
)
