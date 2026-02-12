;; ------------------------------------------------------------
;; StackGate Access Request Contract (Clarity 4)
;; Users can request access on-chain
;; ------------------------------------------------------------

;; ================================
;; Constants (Errors)
;; ================================
(define-constant ERR_ALREADY_REQUESTED (err u100))

;; ================================
;; Data Maps
;; ================================
(define-map access-requests
  { requester: principal }
  { requested-at: uint }
)

;; ================================
;; Data Variables
;; ================================
(define-data-var total-requests uint u0)

;; ================================
;; Read-Only Functions
;; ================================

;; Check if a wallet has requested access
(define-read-only (has-requested (user principal))
  (is-some (map-get? access-requests { requester: user }))
)

;; Get request timestamp
(define-read-only (get-request-time (user principal))
  (match (map-get? access-requests { requester: user })
    entry (some (get requested-at entry))
    none
  )
)

;; Get total access requests
(define-read-only (get-total-requests)
  (var-get total-requests)
)

;; Clarity 4: Format principal as ASCII
(define-read-only (get-user-as-string (user principal))
  (to-ascii? user)
)

;; ================================
;; Public Functions
;; ================================

;; Request access (one time per wallet)
(define-public (request-access)
  (begin
    ;; Prevent duplicate requests
    (asserts!
      (not (has-requested tx-sender))
      ERR_ALREADY_REQUESTED
    )

    ;; Store request with block height
    (map-set access-requests
      { requester: tx-sender }
      { requested-at: stacks-block-height }
    )

    ;; Update stats
    (var-set total-requests (+ (var-get total-requests) u1))

    (ok true)
  )
)
