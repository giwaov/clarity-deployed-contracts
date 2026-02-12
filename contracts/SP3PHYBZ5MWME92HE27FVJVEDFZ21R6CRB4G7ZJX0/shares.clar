;; Contract: Shares Registry
;; Description: Defines payment splits.

(define-map splits principal uint)

(define-public (set-share (user principal) (percent uint))
    (ok (map-set splits user percent))
)

(define-read-only (get-share (user principal))
    (default-to u0 (map-get? splits user))
)