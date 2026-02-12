;; ============================================
;; STREAK TRACKER - Inactivity Measurement
;; Clarity 2 Smart Contract
;; ============================================

(define-constant ERR_UNAUTHORIZED (err u401))

(define-map user-start-block principal uint)

(define-public (start-streak (user principal))
  (begin
    (asserts! (is-eq contract-caller .procrastination-vault) ERR_UNAUTHORIZED)
    (map-set user-start-block user burn-block-height)
    (ok true)
  )
)

(define-public (end-streak (user principal))
  (begin
    (asserts! (is-eq contract-caller .procrastination-vault) ERR_UNAUTHORIZED)
    (map-delete user-start-block user)
    (ok true)
  )
)

(define-read-only (get-streak-blocks (user principal))
  (let ((start (map-get? user-start-block user)))
    (if (is-some start)
      (ok (- burn-block-height (unwrap-panic start)))
      (ok u0)
    )
  )
)

(define-read-only (get-streak-days (user principal))
  (let ((blocks (unwrap-panic (get-streak-blocks user))))
    (ok (/ blocks u144))
  )
)
