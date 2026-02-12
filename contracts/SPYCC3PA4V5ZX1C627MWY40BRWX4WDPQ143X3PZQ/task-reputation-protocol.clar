;; =========================================================
;; Task & Reputation Protocol
;; Version: 1.0.0
;; =========================================================
;; A single-contract protocol for:
;; - Creating tasks with STX escrow
;; - Assigning and completing tasks
;; - Paying workers in STX
;; - Tracking reputation
;; - Supporting task cancellation
;; - Emergency fund recovery
;; =========================================================

;; ---------------------------------------------------------
;; Constants & Admin
;; ---------------------------------------------------------

;; Deployer is protocol admin
(define-constant ADMIN tx-sender)

;; Protocol version
(define-constant VERSION "1.0.0")

;; ---------------------------------------------------------
;; Protocol State
;; ---------------------------------------------------------

(define-data-var paused bool false)
(define-data-var next-task-id uint u1)

;; ---------------------------------------------------------
;; User & Reputation System
;; ---------------------------------------------------------

;; Registered users
(define-map users principal uint)

;; Reputation score per user
(define-map reputation principal int)

;; ---------------------------------------------------------
;; Task System
;; ---------------------------------------------------------

;; Task status codes
(define-constant STATUS-OPEN u0)
(define-constant STATUS-ASSIGNED u1)
(define-constant STATUS-SUBMITTED u2)
(define-constant STATUS-COMPLETED u3)
(define-constant STATUS-CANCELLED u4)

;; Task storage
(define-map tasks uint {
  creator: principal,
  worker: (optional principal),
  bounty: uint,
  status: uint
})

;; Submission proof (IPFS hash, URL, etc.)
(define-map submissions uint (string-ascii 64))

;; ---------------------------------------------------------
;; Internal Guards
;; ---------------------------------------------------------

(define-private (assert-not-paused)
  (begin
    (asserts! (not (var-get paused)) (err u100))
    (ok true)
  )
)

(define-private (assert-admin)
  (begin
    (asserts! (is-eq tx-sender ADMIN) (err u401))
    (ok true)
  )
)

;; ---------------------------------------------------------
;; User Registration
;; ---------------------------------------------------------

(define-public (register)
  (begin
    (try! (assert-not-paused))
    (map-set users tx-sender stacks-block-height)

    (print { event: "user_registered", user: tx-sender })

    (ok true)
  )
)

(define-read-only (get-reputation (user principal))
    (default-to 0 (map-get? reputation user))
)

;; ---------------------------------------------------------
;; Task Creation (STX Escrow)
;; ---------------------------------------------------------

(define-public (create-task (bounty uint))
  (begin
    (try! (assert-not-paused))
    (asserts! (is-some (map-get? users tx-sender)) (err u101))

    ;; Lock STX into contract escrow
    (try! (stx-transfer? bounty tx-sender (as-contract tx-sender)))

    (let ((task-id (var-get next-task-id)))
      (map-set tasks task-id {
        creator: tx-sender,
        worker: none,
        bounty: bounty,
        status: STATUS-OPEN
      })

      (var-set next-task-id (+ task-id u1))

      (print {
        event: "task_created",
        task_id: task-id,
        creator: tx-sender,
        bounty: bounty
      })

      (ok task-id)
    )
  )
)

;; ---------------------------------------------------------
;; Task Assignment
;; ---------------------------------------------------------

(define-public (assign-task (task-id uint) (worker principal))
  (let ((task (unwrap! (map-get? tasks task-id) (err u404))))
    (asserts! (is-eq tx-sender (get creator task)) (err u401))
    (asserts! (is-eq (get status task) STATUS-OPEN) (err u102))

    (map-set tasks task-id {
      creator: (get creator task),
      worker: (some worker),
      bounty: (get bounty task),
      status: STATUS-ASSIGNED
    })

    (print {
      event: "task_assigned",
      task_id: task-id,
      worker: worker
    })

    (ok true)
  )
)

;; ---------------------------------------------------------
;; Task Submission
;; ---------------------------------------------------------

(define-public (submit-task (task-id uint) (proof (string-ascii 64)))
  (let ((task (unwrap! (map-get? tasks task-id) (err u404))))
    (asserts! (is-eq (some tx-sender) (get worker task)) (err u401))
    (asserts! (is-eq (get status task) STATUS-ASSIGNED) (err u103))

    (map-set submissions task-id proof)

    (map-set tasks task-id {
      creator: (get creator task),
      worker: (get worker task),
      bounty: (get bounty task),
      status: STATUS-SUBMITTED
    })

    (print {
      event: "task_submitted",
      task_id: task-id,
      worker: tx-sender
    })

    (ok true)
  )
)

;; ---------------------------------------------------------
;; Task Review & Payout
;; ---------------------------------------------------------

(define-public (review-task (task-id uint) (approve bool))
  (let ((task (unwrap! (map-get? tasks task-id) (err u404))))
    (asserts! (is-eq tx-sender (get creator task)) (err u401))
    (asserts! (is-eq (get status task) STATUS-SUBMITTED) (err u104))

    (if approve
        ;; APPROVE TASK
        (let ((worker (unwrap! (get worker task) (err u500)))
              (bounty (get bounty task)))

          ;; Pay worker from escrow
          (as-contract
            (try! (stx-transfer? bounty tx-sender worker))
          )

          ;; Increase worker reputation
          (let ((rep (default-to 0 (map-get? reputation worker))))
            (map-set reputation worker (+ rep 10)))

          (map-set tasks task-id {
            creator: (get creator task),
            worker: (get worker task),
            bounty: bounty,
            status: STATUS-COMPLETED
          })

          (print {
            event: "task_completed",
            task_id: task-id,
            worker: worker,
            bounty: bounty
          })

          (ok true)
        )

        ;; REJECT TASK
        (begin
          (map-set tasks task-id {
            creator: (get creator task),
            worker: none,
            bounty: (get bounty task),
            status: STATUS-OPEN
          })

          (print {
            event: "task_rejected",
            task_id: task-id
          })

          (ok false)
        )
    )
  )
)

;; ---------------------------------------------------------
;; Task Cancellation
;; ---------------------------------------------------------

(define-public (cancel-task (task-id uint))
  (let ((task (unwrap! (map-get? tasks task-id) (err u404))))
    (asserts! (is-eq tx-sender (get creator task)) (err u401))
    (asserts! (not (is-eq (get status task) STATUS-COMPLETED)) (err u105))
    (asserts! (not (is-eq (get status task) STATUS-CANCELLED)) (err u106))

    ;; Refund escrow to creator
    (as-contract
      (try! (stx-transfer? (get bounty task) tx-sender (get creator task)))
    )

    (map-set tasks task-id {
      creator: (get creator task),
      worker: none,
      bounty: (get bounty task),
      status: STATUS-CANCELLED
    })

    (print {
      event: "task_cancelled",
      task_id: task-id,
      creator: tx-sender
    })

    (ok true)
  )
)

;; ---------------------------------------------------------
;; Emergency Withdraw (Admin Only)
;; ---------------------------------------------------------

(define-public (emergency-withdraw)
  (begin
    (try! (assert-admin))

    (let ((balance (stx-get-balance (as-contract tx-sender))))
      (asserts! (> balance u0) (err u402))

      (as-contract
        (try! (stx-transfer? balance tx-sender ADMIN))
      )

      (print {
        event: "emergency_withdraw",
        admin: tx-sender,
        amount: balance
      })

      (ok balance)
    )
  )
)

;; ---------------------------------------------------------
;; Admin Controls
;; ---------------------------------------------------------

(define-public (set-paused (state bool))
  (begin
    (try! (assert-admin))
    (var-set paused state)

    (print {
      event: "protocol_paused",
      paused: state
    })

    (ok state)
  )
)

;; ---------------------------------------------------------
;; Read-only Views (Frontend Friendly)
;; ---------------------------------------------------------

(define-read-only (get-task (task-id uint))
  (map-get? tasks task-id)
)

(define-read-only (get-submission (task-id uint))
  (map-get? submissions task-id)
)

(define-read-only (get-next-task-id)
  (var-get next-task-id)
)

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)
