;; ---------------------------------------------------------
;; Task Assigner
;; Assigns tasks to contributors
;; ---------------------------------------------------------

(define-map assignments uint principal)


(define-public (assign (task-id uint) (worker principal))
    (begin
        (map-set assignments task-id worker)
        (ok worker)
    )
)


(define-read-only (get-worker (task-id uint))
    (map-get? assignments task-id)
)
