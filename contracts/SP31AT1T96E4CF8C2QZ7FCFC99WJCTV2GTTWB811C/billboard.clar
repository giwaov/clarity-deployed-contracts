(define-data-var message (string-utf8 50) u"")
(define-data-var price uint u100)

(define-public (set-message (msg (string-utf8 50)))
    (begin
        (var-set message msg)
        (ok true)
    )
)
