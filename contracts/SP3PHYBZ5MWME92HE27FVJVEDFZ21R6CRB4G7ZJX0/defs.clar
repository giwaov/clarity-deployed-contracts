;; Contract: Badge Definitions
;; Description: Defines what badges exist.

(define-data-var badge-name (string-ascii 20) "Early Adopter")

(define-read-only (get-badge-name)
    (ok (var-get badge-name))
)

(define-public (update-badge (new-name (string-ascii 20)))
    (ok (var-get badge-name))
)