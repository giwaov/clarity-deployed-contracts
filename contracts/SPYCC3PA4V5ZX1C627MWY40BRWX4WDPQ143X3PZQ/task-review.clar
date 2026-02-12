;; ---------------------------------------------------------
;; Task Review
;; Approves or rejects submissions
;; ---------------------------------------------------------

(define-map reviews uint bool)


(define-public (review (task-id uint) (approved bool))
    (begin
        (map-set reviews task-id approved)
        (ok approved)
    )
)
