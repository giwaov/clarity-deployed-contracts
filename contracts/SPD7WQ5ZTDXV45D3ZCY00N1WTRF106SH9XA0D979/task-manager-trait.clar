;; Task Manager Trait
;; Defines the interface for task manager contracts

(define-trait task-manager-trait
    (
        ;; Create a new task
        (create-task ((string-ascii 100) (string-ascii 500) uint) (response uint uint))
        
        ;; Submit a task completion
        (submit-task (uint (string-ascii 500)) (response bool uint))
        
        ;; Get task information
        (get-task (uint) (response (optional {
            creator: principal,
            title: (string-ascii 100),
            description: (string-ascii 500),
            reward-amount: uint,
            status: (string-ascii 20),
            created-at: uint,
            completed-by: (optional principal),
            completed-at: (optional uint)
        }) uint))
    )
)
