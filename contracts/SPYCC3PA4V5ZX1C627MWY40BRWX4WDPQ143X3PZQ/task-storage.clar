;; ---------------------------------------------------------
;; Task Storage
;; Stores core task metadata
;; --------------------------------------------------------

(define-map tasks uint {
    creator: principal,
    bounty: uint,
    status: uint
})


;; Creates a new task entry
(define-public (create-task (id uint) (bounty uint))
    (begin
        (map-set tasks id {
            creator: tx-sender,
            bounty: bounty,
            status: u0
        })
        (ok id)
    )
)


;; Returns task data
(define-read-only (get-task (id uint))
    (map-get? tasks id)
)
