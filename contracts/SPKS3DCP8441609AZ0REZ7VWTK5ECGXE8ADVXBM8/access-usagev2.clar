;; ------------------------------------------------------------
;; StackGate Access Counter v1 (Clarity 4)
;; Simple per-wallet access counter
;; ------------------------------------------------------------

;; ================================
;; Data Variables
;; ================================
(define-data-var total-access uint u0)

;; ================================
;; Data Maps
;; ================================
(define-map access-count
  { user: principal }
  { count: uint }
)

;; ================================
;; Read-Only Functions
;; ================================

;; Total access attempts
(define-read-only (get-total-access)
  (var-get total-access)
)

;; Get access count for a user
(define-read-only (get-user-access (user principal))
  (match (map-get? access-count { user: user })
    entry (some (get count entry))
    none
  )
)

;; ------------------------------------------------
;; Clarity 4 REQUIRED HELPERS
;; ------------------------------------------------

(define-read-only (get-user-as-string (user principal))
  (to-ascii? user)
)

(define-read-only (get-total-access-as-string)
  (to-ascii? (var-get total-access))
)

;; ================================
;; Public Functions
;; ================================

;; Record an access attempt
(define-public (record-access)
  (begin
    (if (is-some (map-get? access-count { user: tx-sender }))
        ;; existing user
        (map-set access-count
          { user: tx-sender }
          {
            count: (+ (get count (unwrap-panic (map-get? access-count { user: tx-sender }))) u1)
          }
        )
        ;; first-time user
        (map-set access-count
          { user: tx-sender }
          { count: u1 }
        )
    )

    (var-set total-access (+ (var-get total-access) u1))
    (ok true)
  )
)
