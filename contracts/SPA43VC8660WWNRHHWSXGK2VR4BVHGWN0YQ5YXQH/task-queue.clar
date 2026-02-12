;; task-queue.clar
;; Simulates a task processing queue for distributed workers

(define-map tasks 
    uint 
    { name: (string-ascii 64), priority: uint, status: (string-ascii 20) }
)

(define-data-var task-counter uint u0)

(define-public (add-task (name (string-ascii 64)) (priority uint))
    (let ((id (+ (var-get task-counter) u1)))
        (map-set tasks id { name: name, priority: priority, status: "pending" })
        (var-set task-counter id)
        (ok id)
    )
)

(define-public (complete-task (id uint))
    (begin 
        (match (map-get? tasks id)
            task (map-set tasks id (merge task { status: "completed" }))
            false
        )
        (ok true)
    )
)
