;; ============================================
;; BENEFICIARY MANAGER - Distribution Rules
;; Clarity 4 Smart Contract
;; ============================================

(define-constant ERR_INVALID_PERCENTAGE (err u413))

(define-map beneficiaries principal (list 10 {
  recipient: principal,
  percentage: uint
}))

;; Helper for summing percentages
(define-private (sum-percentages (item { recipient: principal, percentage: uint }) (acc uint))
  (+ (get percentage item) acc)
)

(define-public (set-beneficiaries (new-list (list 10 { recipient: principal, percentage: uint })))
  (let
    (
      (total-percent (fold sum-percentages new-list u0))
    )
    (asserts! (<= total-percent u100) ERR_INVALID_PERCENTAGE)
    (map-set beneficiaries tx-sender new-list)
    (ok true)
  )
)

(define-read-only (get-beneficiaries (user principal))
  (match (map-get? beneficiaries user)
    list-found list-found
    (list)
  )
)
