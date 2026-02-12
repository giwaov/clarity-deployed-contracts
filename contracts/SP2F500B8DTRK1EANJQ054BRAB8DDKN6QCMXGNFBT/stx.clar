
;; Simple Storage Contract
(define-data-var message (string-utf8 500) u"Hello Stacks")

(define-public (write-message (new-message (string-utf8 500)))
    (begin
        (print new-message)
        (var-set message new-message)
        (ok "Message updated")
    )
)

(define-read-only (read-message)
    (ok (var-get message))
)
