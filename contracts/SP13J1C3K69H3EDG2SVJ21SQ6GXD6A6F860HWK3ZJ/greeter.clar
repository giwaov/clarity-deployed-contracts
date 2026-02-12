;; greeter.clar
;; A simple greeting contract

(define-data-var greeting (string-ascii 50) "Hello, Stacks!")

(define-public (set-greeting (new-greeting (string-ascii 50)))
  (ok (var-set greeting new-greeting))
)

(define-read-only (get-greeting)
  (ok (var-get greeting))
)
