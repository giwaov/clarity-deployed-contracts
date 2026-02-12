
;; Profile Storage
;; Stores simplified user profile data on-chain

(define-data-var profile-score uint u100)

(define-read-only (get-score)
    (ok (var-get profile-score))
)

(define-public (update-score (new-score uint))
    (begin
        (var-set profile-score new-score)
        (ok new-score)
    )
)
