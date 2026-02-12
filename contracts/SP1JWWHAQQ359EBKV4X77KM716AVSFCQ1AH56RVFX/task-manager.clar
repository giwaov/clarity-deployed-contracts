;; Task Manager Contract
;; Core task lifecycle management

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-TASK-NOT-FOUND (err u301))
(define-constant ERR-INVALID-STATUS (err u302))
(define-constant ERR-TASK-ALREADY-ASSIGNED (err u303))
(define-constant ERR-TASK-NOT-ASSIGNED (err u304))
(define-constant ERR-DEADLINE-PASSED (err u305))
(define-constant ERR-INVALID-TITLE (err u306))
(define-constant ERR-INVALID-DESCRIPTION (err u307))
(define-constant ERR-INVALID-CATEGORY (err u308))
(define-constant ERR-ESCROW-FAILED (err u309))
(define-constant ERR-ALREADY-SUBMITTED (err u310))
(define-constant ERR-NOT-SUBMITTED (err u311))

;; Task Status Constants
(define-constant STATUS-OPEN u0)
(define-constant STATUS-ASSIGNED u1)
(define-constant STATUS-SUBMITTED u2)
(define-constant STATUS-APPROVED u3)
(define-constant STATUS-DISPUTED u4)
(define-constant STATUS-CANCELLED u5)
(define-constant STATUS-REJECTED u6)

;; Data Variables
(define-data-var task-counter uint u0)

;; Data Maps
(define-map tasks
    { task-id: uint }
    {
        creator: principal,
        worker: (optional principal),
        title: (string-ascii 100),
        description: (string-utf8 500),
        category: (string-ascii 50),
        reward: uint,
        status: uint,
        created-at: uint,
        deadline: uint,
        submission-url: (optional (string-utf8 200)),
        submission-notes: (optional (string-utf8 300)),
        submitted-at: (optional uint),
        completed-at: (optional uint)
    }
)

;; Track tasks by creator
(define-map creator-tasks
    { creator: principal, task-id: uint }
    bool
)

;; Track tasks by worker
(define-map worker-tasks
    { worker: principal, task-id: uint }
    bool
)

;; Contract references (to be set after deployment)
(define-data-var escrow-contract (optional principal) none)
(define-data-var reputation-contract (optional principal) none)

;; Read-only functions

(define-read-only (get-task (task-id uint))
    (ok (map-get? tasks { task-id: task-id }))
)

(define-read-only (get-task-count)
    (ok (var-get task-counter))
)

(define-read-only (get-escrow-contract)
    (ok (var-get escrow-contract))
)

(define-read-only (get-reputation-contract)
    (ok (var-get reputation-contract))
)

(define-read-only (is-task-creator (task-id uint) (user principal))
    (match (map-get? tasks { task-id: task-id })
        task-data (ok (is-eq (get creator task-data) user))
        (ok false)
    )
)

(define-read-only (is-task-worker (task-id uint) (user principal))
    (match (map-get? tasks { task-id: task-id })
        task-data 
        (match (get worker task-data)
            worker (ok (is-eq worker user))
            (ok false)
        )
        (ok false)
    )
)

;; Private functions

(define-private (validate-title (title (string-ascii 100)))
    (> (len title) u0)
)

(define-private (validate-description (description (string-utf8 500)))
    (> (len description) u0)
)

(define-private (validate-category (category (string-ascii 50)))
    (> (len category) u0)
)

;; Public functions

(define-public (set-escrow-contract (contract principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set escrow-contract (some contract))
        (ok true)
    )
)

(define-public (set-reputation-contract (contract principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set reputation-contract (some contract))
        (ok true)
    )
)

(define-public (create-task 
    (title (string-ascii 100))
    (description (string-utf8 500))
    (category (string-ascii 50))
    (reward uint)
    (deadline uint))
    (let (
        (task-id (+ (var-get task-counter) u1))
    )
    
    ;; Validate inputs
    (asserts! (validate-title title) ERR-INVALID-TITLE)
    (asserts! (validate-description description) ERR-INVALID-DESCRIPTION)
    (asserts! (validate-category category) ERR-INVALID-CATEGORY)
    (asserts! (> deadline block-height) ERR-DEADLINE-PASSED)
    
    ;; Ensure escrow contract is set
    (asserts! (is-some (var-get escrow-contract)) ERR-ESCROW-FAILED)
    
    ;; Deposit escrow
    (unwrap! (contract-call? .task-escrow deposit-escrow task-id reward tx-sender) ERR-ESCROW-FAILED)
    
    ;; Record task creation in reputation contract (if set)
    (match (var-get reputation-contract)
        rep-contract (try! (contract-call? .reputation-tracker record-task-created tx-sender reward))
        true
    )
    
    ;; Create task
    (map-set tasks
        { task-id: task-id }
        {
            creator: tx-sender,
            worker: none,
            title: title,
            description: description,
            category: category,
            reward: reward,
            status: STATUS-OPEN,
            created-at: block-height,
            deadline: deadline,
            submission-url: none,
            submission-notes: none,
            submitted-at: none,
            completed-at: none
        }
    )
    
    ;; Track task for creator
    (map-set creator-tasks { creator: tx-sender, task-id: task-id } true)
    
    ;; Increment counter
    (var-set task-counter task-id)
    
    (ok task-id))
)

(define-public (assign-task (task-id uint) (worker principal))
    (let (
        (task-data (unwrap! (map-get? tasks { task-id: task-id }) ERR-TASK-NOT-FOUND))
    )
    
    ;; Only creator can assign
    (asserts! (is-eq tx-sender (get creator task-data)) ERR-NOT-AUTHORIZED)
    
    ;; Must be in OPEN status
    (asserts! (is-eq (get status task-data) STATUS-OPEN) ERR-INVALID-STATUS)
    
    ;; Check deadline hasn't passed
    (asserts! (< block-height (get deadline task-data)) ERR-DEADLINE-PASSED)
    
    ;; Update worker in escrow
    (unwrap! (contract-call? .task-escrow set-worker task-id worker) ERR-ESCROW-FAILED)
    
    ;; Update task
    (map-set tasks
        { task-id: task-id }
        (merge task-data {
            worker: (some worker),
            status: STATUS-ASSIGNED
        })
    )
    
    ;; Track task for worker
    (map-set worker-tasks { worker: worker, task-id: task-id } true)
    
    (ok true))
)

(define-public (submit-work 
    (task-id uint) 
    (submission-url (string-utf8 200))
    (notes (string-utf8 300)))
    (let (
        (task-data (unwrap! (map-get? tasks { task-id: task-id }) ERR-TASK-NOT-FOUND))
        (worker (unwrap! (get worker task-data) ERR-TASK-NOT-ASSIGNED))
    )
    
    ;; Only assigned worker can submit
    (asserts! (is-eq tx-sender worker) ERR-NOT-AUTHORIZED)
    
    ;; Must be in ASSIGNED status
    (asserts! (is-eq (get status task-data) STATUS-ASSIGNED) ERR-INVALID-STATUS)
    
    ;; Check deadline hasn't passed
    (asserts! (< block-height (get deadline task-data)) ERR-DEADLINE-PASSED)
    
    ;; Update task
    (map-set tasks
        { task-id: task-id }
        (merge task-data {
            status: STATUS-SUBMITTED,
            submission-url: (some submission-url),
            submission-notes: (some notes),
            submitted-at: (some block-height)
        })
    )
    
    (ok true))
)

(define-public (approve-task (task-id uint) (rating uint))
    (let (
        (task-data (unwrap! (map-get? tasks { task-id: task-id }) ERR-TASK-NOT-FOUND))
        (worker (unwrap! (get worker task-data) ERR-TASK-NOT-ASSIGNED))
        (reward (get reward task-data))
        (reputation-contract-addr (var-get reputation-contract))
    )
    
    ;; Only creator can approve
    (asserts! (is-eq tx-sender (get creator task-data)) ERR-NOT-AUTHORIZED)
    
    ;; Must be in SUBMITTED status
    (asserts! (is-eq (get status task-data) STATUS-SUBMITTED) ERR-INVALID-STATUS)
    
    ;; Release funds from escrow
    (unwrap! (contract-call? .task-escrow release-funds task-id) ERR-ESCROW-FAILED)
    
    ;; Record completion in reputation contract (if set)
    (match reputation-contract-addr
        rep-contract (begin
            (unwrap! (contract-call? .reputation-tracker record-completion worker true rating) ERR-ESCROW-FAILED)
            (unwrap! (contract-call? .reputation-tracker record-task-earned worker reward) ERR-ESCROW-FAILED)
            true
        )
        true
    )
    
    ;; Update task
    (map-set tasks
        { task-id: task-id }
        (merge task-data {
            status: STATUS-APPROVED,
            completed-at: (some block-height)
        })
    )
    
    (ok true))
)

(define-public (reject-task (task-id uint) (reason (string-utf8 200)))
    (let (
        (task-data (unwrap! (map-get? tasks { task-id: task-id }) ERR-TASK-NOT-FOUND))
    )
    
    ;; Only creator can reject
    (asserts! (is-eq tx-sender (get creator task-data)) ERR-NOT-AUTHORIZED)
    
    ;; Must be in SUBMITTED status
    (asserts! (is-eq (get status task-data) STATUS-SUBMITTED) ERR-INVALID-STATUS)
    
    ;; Refund creator from escrow
    (unwrap! (contract-call? .task-escrow refund-creator task-id) ERR-ESCROW-FAILED)
    
    ;; Update task
    (map-set tasks
        { task-id: task-id }
        (merge task-data {
            status: STATUS-REJECTED
        })
    )
    
    (ok true))
)

(define-public (open-dispute (task-id uint))
    (let (
        (task-data (unwrap! (map-get? tasks { task-id: task-id }) ERR-TASK-NOT-FOUND))
        (worker (unwrap! (get worker task-data) ERR-TASK-NOT-ASSIGNED))
    )
    
    ;; Only creator or worker can open dispute
    (asserts! (or 
        (is-eq tx-sender (get creator task-data))
        (is-eq tx-sender worker)
    ) ERR-NOT-AUTHORIZED)
    
    ;; Must be in SUBMITTED or REJECTED status
    (asserts! (or
        (is-eq (get status task-data) STATUS-SUBMITTED)
        (is-eq (get status task-data) STATUS-REJECTED)
    ) ERR-INVALID-STATUS)
    
    ;; Open dispute in escrow
    (unwrap! (contract-call? .task-escrow open-dispute task-id) ERR-ESCROW-FAILED)
    
    ;; Update task
    (map-set tasks
        { task-id: task-id }
        (merge task-data {
            status: STATUS-DISPUTED
        })
    )
    
    (ok true))
)

(define-public (cancel-task (task-id uint))
    (let (
        (task-data (unwrap! (map-get? tasks { task-id: task-id }) ERR-TASK-NOT-FOUND))
    )
    
    ;; Only creator can cancel
    (asserts! (is-eq tx-sender (get creator task-data)) ERR-NOT-AUTHORIZED)
    
    ;; Can only cancel if OPEN or ASSIGNED
    (asserts! (or
        (is-eq (get status task-data) STATUS-OPEN)
        (is-eq (get status task-data) STATUS-ASSIGNED)
    ) ERR-INVALID-STATUS)
    
    ;; Refund creator from escrow
    (unwrap! (contract-call? .task-escrow refund-creator task-id) ERR-ESCROW-FAILED)
    
    ;; Update task
    (map-set tasks
        { task-id: task-id }
        (merge task-data {
            status: STATUS-CANCELLED
        })
    )
    
    (ok true))
)
