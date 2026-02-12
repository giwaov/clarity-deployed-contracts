;; ------------------------------------------------------------
;; Allowlist (Whitelist) Smart Contract
;; Simple access control for token launches & gated features
;; ------------------------------------------------------------

;; ================================
;; Constants (Errors)
;; ================================
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_ADMIN (err u101))
(define-constant ERR_ALREADY_ALLOWED (err u102))
(define-constant ERR_NOT_ALLOWED (err u103))

;; ================================
;; Data Variables
;; ================================
(define-data-var contract-admin (optional principal) none)

;; ================================
;; Data Maps
;; ================================
(define-map allowlist
  { wallet: principal }
  { allowed: bool }
)

;; ================================
;; Read-Only Functions
;; ================================

;; Check if a wallet is allowed
(define-read-only (is-allowed (wallet principal))
  (is-some (map-get? allowlist { wallet: wallet }))
)

;; Get current admin
(define-read-only (get-admin)
  (var-get contract-admin)
)

;; Clarity 4: Format principal as ASCII string
(define-read-only (get-admin-as-string (admin principal))
  (to-ascii? admin)
)

;; ================================
;; Public Functions
;; ================================

;; Initialize admin (can only be called once)
(define-public (set-admin (admin principal))
  (if (is-none (var-get contract-admin))
      (begin
        (var-set contract-admin (some admin))
        (ok admin)
      )
      ERR_UNAUTHORIZED
  )
)

;; Add wallet to allowlist (admin only)
(define-public (add-wallet (wallet principal))
  (let
    (
      (admin-opt (var-get contract-admin))
    )
    (if (is-none admin-opt)
        ERR_UNAUTHORIZED
        (let
          (
            (admin (unwrap-panic admin-opt))
          )
          (begin
            (asserts! (is-eq tx-sender admin) ERR_NOT_ADMIN)
            (asserts! (not (is-allowed wallet)) ERR_ALREADY_ALLOWED)

            (map-set allowlist
              { wallet: wallet }
              { allowed: true }
            )

            (ok true)
          )
        )
    )
  )
)

;; Remove wallet from allowlist (admin only)
(define-public (remove-wallet (wallet principal))
  (let
    (
      (admin-opt (var-get contract-admin))
    )
    (if (is-none admin-opt)
        ERR_UNAUTHORIZED
        (let
          (
            (admin (unwrap-panic admin-opt))
          )
          (begin
            (asserts! (is-eq tx-sender admin) ERR_NOT_ADMIN)
            (asserts! (is-allowed wallet) ERR_NOT_ALLOWED)

            (map-delete allowlist { wallet: wallet })

            (ok true)
          )
        )
    )
  )
)
