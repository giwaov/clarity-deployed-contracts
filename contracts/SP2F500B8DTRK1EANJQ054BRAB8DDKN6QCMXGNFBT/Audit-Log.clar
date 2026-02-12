
;; Audit Log
;; Securely logs system events for compliance

(define-data-var last-entry (string-ascii 50) "System Init")

(define-read-only (get-last-entry)
    (ok (var-get last-entry))
)

(define-public (log-event (message (string-ascii 50)))
    (begin
        (var-set last-entry message)
        (ok message)
    )
)
