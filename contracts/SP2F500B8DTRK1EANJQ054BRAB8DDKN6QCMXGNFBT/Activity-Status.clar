
;; Activity Status
;; A simple contract to toggle a status flag

(define-data-var status bool true)

(define-read-only (get-status)
    (ok (var-get status))
)

(define-public (toggle-status)
    (begin
        (var-set status (not (var-get status)))
        (ok (var-get status))
    )
)
