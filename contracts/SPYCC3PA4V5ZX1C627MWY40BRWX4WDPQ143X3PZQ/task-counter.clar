;; ---------------------------------------------------------
;; Task Counter
;; Generates incremental task IDs
;; ---------------------------------------------------------

(define-data-var task-id uint u0)


;; Increments and returns next task ID
(define-public (next-id)
    (begin
        (var-set task-id (+ (var-get task-id) u1))
        (ok (var-get task-id))
    )
)
