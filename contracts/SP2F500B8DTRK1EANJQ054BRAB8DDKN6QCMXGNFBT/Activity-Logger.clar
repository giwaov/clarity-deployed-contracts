
;; Activity Logger
;; A simple contract to log short messages on-chain

(define-data-var last-message (string-ascii 50) "Hello Stacks")

(define-read-only (get-message)
    (ok (var-get last-message))
)

(define-public (log-message (message (string-ascii 50)))
    (begin
        (var-set last-message message)
        (ok message)
    )
)
