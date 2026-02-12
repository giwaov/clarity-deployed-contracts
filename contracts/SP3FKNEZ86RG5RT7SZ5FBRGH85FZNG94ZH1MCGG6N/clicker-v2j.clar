;; Clicker Contract v2j - Enhanced with events and leaderboard
;; Contract 1 of 3 for Stacks Transaction Hub

;; Constants
(define-constant contract-owner tx-sender)
(define-constant interaction-fee u1000) ;; 0.001 STX = 1000 microSTX
(define-constant VERSION u2)
(define-constant err-insufficient-fee (err u100))
(define-constant err-transfer-failed (err u101))

;; Data Variables
(define-data-var total-clicks uint u0)
(define-data-var total-fees-collected uint u0)
(define-data-var last-clicker (optional principal) none)
(define-data-var last-activity-block uint u0)
(define-data-var unique-users uint u0)

;; Data Maps
(define-map user-clicks principal uint)
(define-map user-streaks principal uint)
(define-map user-first-click principal uint) ;; block height of first click

;; Private function to collect fee
(define-private (collect-fee)
  (begin
    (try! (stx-transfer? interaction-fee tx-sender contract-owner))
    (var-set total-fees-collected (+ (var-get total-fees-collected) interaction-fee))
    (ok true)
  )
)

;; Track new user
(define-private (track-new-user)
  (if (is-eq (default-to u0 (map-get? user-clicks tx-sender)) u0)
    (begin
      (var-set unique-users (+ (var-get unique-users) u1))
      (map-set user-first-click tx-sender block-height)
      true
    )
    false
  )
)

;; Read-only functions
(define-read-only (get-version) VERSION)

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

(define-read-only (get-unique-users)
  (var-get unique-users)
)

(define-read-only (get-last-activity-block)
  (var-get last-activity-block)
)

(define-read-only (get-user-first-click (user principal))
  (map-get? user-first-click user)
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

(define-read-only (get-contract-info)
  {
    version: VERSION,
    total-clicks: (var-get total-clicks),
    unique-users: (var-get unique-users),
    fee: interaction-fee,
    last-activity: (var-get last-activity-block),
    owner: contract-owner
  }
)

;; Public functions - Each call costs 0.001 STX

;; Simple click - costs 0.001 STX
(define-public (click)
  (let
    (
      (current-clicks (get-user-clicks tx-sender))
      (current-streak (get-user-streak tx-sender))
      (new-count (+ current-clicks u1))
    )
    ;; Track new user before fee
    (track-new-user)
    ;; Collect fee first
    (try! (collect-fee))
    ;; Update user clicks
    (map-set user-clicks tx-sender new-count)
    ;; Update streak
    (map-set user-streaks tx-sender (+ current-streak u1))
    ;; Update global stats
    (var-set total-clicks (+ (var-get total-clicks) u1))
    (var-set last-clicker (some tx-sender))
    (var-set last-activity-block block-height)
    ;; Emit event
    (print { event: "click", user: tx-sender, count: new-count, block: block-height })
    ;; Return success with click count
    (ok new-count)
  )
)

;; Multi-click - costs 0.001 STX (same fee regardless of count)
(define-public (multi-click (count uint))
  (let
    (
      (current-clicks (get-user-clicks tx-sender))
      (safe-count (if (> count u100) u100 count))
      (new-count (+ current-clicks safe-count))
    )
    ;; Track new user
    (track-new-user)
    ;; Collect fee first
    (try! (collect-fee))
    ;; Update user clicks
    (map-set user-clicks tx-sender new-count)
    ;; Update global stats
    (var-set total-clicks (+ (var-get total-clicks) safe-count))
    (var-set last-clicker (some tx-sender))
    (var-set last-activity-block block-height)
    ;; Emit event
    (print { event: "multi-click", user: tx-sender, added: safe-count, total: new-count, block: block-height })
    ;; Return success
    (ok safe-count)
  )
)

;; Reset streak - costs 0.001 STX
(define-public (reset-streak)
  (begin
    (try! (collect-fee))
    (map-set user-streaks tx-sender u0)
    (var-set last-activity-block block-height)
    (print { event: "reset-streak", user: tx-sender, block: block-height })
    (ok true)
  )
)

;; Ping - costs 0.001 STX
(define-public (ping)
  (begin
    (try! (collect-fee))
    (var-set last-activity-block block-height)
    (print { event: "ping", user: tx-sender, block: block-height })
    (ok block-height)
  )
)
