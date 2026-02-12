
;; nova-emergency-brake.clar
;; Pauses protocol functions
;; CLARITY VERSION: 2

(define-data-var paused bool false)
(define-data-var admin principal tx-sender)

(define-public (toggle-pause)
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) (err u100))
        (var-set paused (not (var-get paused)))
        (ok (var-get paused))
    )
)

(define-read-only (is-paused)
    (var-get paused)
)
