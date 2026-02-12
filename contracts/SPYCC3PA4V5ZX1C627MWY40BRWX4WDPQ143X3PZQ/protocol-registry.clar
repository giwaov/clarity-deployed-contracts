;; ---------------------------------------------------------
;; Protocol Registry
;; Stores global protocol state and versioning
;; ---------------------------------------------------------

(define-constant CONTRACT-OWNER tx-sender)
(define-data-var paused bool false)
(define-constant VERSION "1.0.0")


;; Allows owner to pause or unpause the protocol
(define-public (set-paused (state bool))
    (if (is-eq tx-sender CONTRACT-OWNER)
        (begin
            (var-set paused state)
            (ok state)
        )
        (err u401)
    )
)


;; Returns current pause state
(define-read-only (is-paused)
    (var-get paused)
)


;; Returns protocol version
(define-read-only (get-version)
    VERSION
)
