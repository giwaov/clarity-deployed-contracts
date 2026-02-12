;; ---------------------------------------------------------
;; Task Submission
;; Stores submitted work proofs
;; ---------------------------------------------------------

(define-map submissions uint {
    worker: principal,
    proof: (string-ascii 64)
})


(define-public (submit (task-id uint) (proof (string-ascii 64)))
    (begin
        (map-set submissions task-id {
            worker: tx-sender,
            proof: proof
        })
        (ok proof)
    )
)
