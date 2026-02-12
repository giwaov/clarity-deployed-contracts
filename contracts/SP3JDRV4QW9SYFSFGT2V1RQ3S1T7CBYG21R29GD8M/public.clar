;; Simple Storage Contract

;; Store a single number
(define-data-var stored-number uint u0)

;; Set the number
(define-public (set-number (value uint))
  (begin
    (var-set stored-number value)
    (ok true)
  )
)

;; Get the number
(define-read-only (get-number)
  (var-get stored-number)
)