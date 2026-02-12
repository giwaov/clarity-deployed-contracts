;; Contract: Verified Causes
;; Description: Whitelist of approved charities.

(define-map approved-orgs principal bool)
(define-constant admin tx-sender)

(define-public (add-org (org-address principal))
    (begin
        (asserts! (is-eq tx-sender admin) (err u403))
        (ok (map-set approved-orgs org-address true))
    )
)

(define-read-only (is-verified (org principal))
    (default-to false (map-get? approved-orgs org))
)