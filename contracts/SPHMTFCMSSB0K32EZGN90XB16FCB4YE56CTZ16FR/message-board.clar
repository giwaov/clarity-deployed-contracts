;; ---------------------------------------
;; Simple Counter Contract
;; ---------------------------------------

;; Counter value (initially 0)
(define-data-var counter uint u0)

;; ---------------------------------------
;; Public function: increment counter by 1
;; ---------------------------------------
(define-public (increment)
    (let ((new-value (+ (var-get counter) u1)))
        (var-set counter new-value)
        (ok new-value)
    )
)

;; ---------------------------------------
;; Read-only function: get current counter
;; ---------------------------------------
(define-read-only (get-counter)
    (var-get counter)
)
