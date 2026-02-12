;; ---------------------------------------------------------
;; Reputation Core
;; Tracks reputation scores per user
;; ---------------------------------------------------------

(define-map reputation principal int)


;; Increases a user's reputation
(define-public (increase (user principal) (amount int))
    (let ((current (default-to 0 (map-get? reputation user))))
        (map-set reputation user (+ current amount))
        (ok (+ current amount))
    )
)


;; Returns reputation score
(define-read-only (get-rep (user principal))
    (default-to 0 (map-get? reputation user))
)
