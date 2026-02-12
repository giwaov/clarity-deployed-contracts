;; Clicker Contract - Earn 0.001 STX per interaction
;; Contract 1 of 3 for Stacks Transaction Hub

;; Constants
(define-constant contract-owner tx-sender)
(define-constant interaction-fee u1000) ;; 0.001 STX = 1000 microSTX
(define-constant err-insufficient-fee (err u100))
(define-constant err-transfer-failed (err u101))

;; Data Variables
(define-data-var total-clicks uint u0)
(define-data-var total-fees-collected uint u0)
(define-data-var last-clicker (optional principal) none)

;; Data Maps
(define-map user-clicks principal uint)
(define-map user-streaks principal uint)

;; Private function to collect fee
(define-private (collect-fee)
  (begin
    (try! (stx-transfer? interaction-fee tx-sender contract-owner))
    (var-set total-fees-collected (+ (var-get total-fees-collected) interaction-fee))
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-total-clicks)
  (var-get total-clicks)
)

(define-read-only (get-total-fees-collected)
  (var-get total-fees-collected)
)

(define-read-only (get-interaction-fee)
  interaction-fee
)

(define-read-only (get-user-clicks (user principal))
  (default-to u0 (map-get? user-clicks user))
)

(define-read-only (get-user-streak (user principal))
  (default-to u0 (map-get? user-streaks user))
)

(define-read-only (get-last-clicker)
  (var-get last-clicker)
)

(define-read-only (get-stats (user principal))
  {
    total: (var-get total-clicks),
    user-clicks: (get-user-clicks user),
    streak: (get-user-streak user),
    last-clicker: (var-get last-clicker),
    fees-collected: (var-get total-fees-collected)
  }
)

;; Public functions - Each call costs 0.001 STX

;; Simple click - costs 0.001 STX
(define-public (click)
  (let
    (
      (current-clicks (get-user-clicks tx-sender))
      (current-streak (get-user-streak tx-sender))
    )
    ;; Collect fee first
    (try! (collect-fee))
    ;; Update user clicks
    (map-set user-clicks tx-sender (+ current-clicks u1))
    ;; Update streak
    (map-set user-streaks tx-sender (+ current-streak u1))
    ;; Update global stats
    (var-set total-clicks (+ (var-get total-clicks) u1))
    (var-set last-clicker (some tx-sender))
    ;; Return success with click count
    (ok (+ current-clicks u1))
  )
)

;; Multi-click - costs 0.001 STX (same fee regardless of count)
(define-public (multi-click (count uint))
  (let
    (
      (current-clicks (get-user-clicks tx-sender))
      (safe-count (if (> count u100) u100 count))
    )
    ;; Collect fee first
    (try! (collect-fee))
    ;; Update user clicks
    (map-set user-clicks tx-sender (+ current-clicks safe-count))
    ;; Update global stats
    (var-set total-clicks (+ (var-get total-clicks) safe-count))
    (var-set last-clicker (some tx-sender))
    ;; Return success
    (ok safe-count)
  )
)

;; Reset streak - costs 0.001 STX
(define-public (reset-streak)
  (begin
    (try! (collect-fee))
    (map-set user-streaks tx-sender u0)
    (ok true)
  )
)

;; Ping - costs 0.001 STX
(define-public (ping)
  (begin
    (try! (collect-fee))
    (ok block-height)
  )
)
