;; Clicker Contract v2m - Enhanced with validation, admin controls, and improved events
;; Contract 1 of 3 for Stacks Transaction Hub

;; ============================================
;; CONTRACT METADATA
;; ============================================
(define-constant CONTRACT-NAME "clicker")
(define-constant VERSION u5)

;; ============================================
;; CONFIGURATION
;; ============================================
(define-constant contract-owner tx-sender)
(define-constant interaction-fee u1000) ;; 0.001 STX = 1000 microSTX
(define-constant MAX-MULTI-CLICK u100)

;; ============================================
;; ERROR CODES
;; ============================================
;; Fee errors (100-109)
(define-constant ERR-INSUFFICIENT-FEE (err u100))
(define-constant ERR-TRANSFER-FAILED (err u101))

;; Authorization errors (110-119)
(define-constant ERR-NOT-OWNER (err u110))
(define-constant ERR-UNAUTHORIZED (err u111))

;; State errors (120-129)
(define-constant ERR-CONTRACT-PAUSED (err u120))

;; Input validation errors (130-139)
(define-constant ERR-INVALID-COUNT (err u130))
(define-constant ERR-ZERO-VALUE (err u131))

;; ============================================
;; DATA VARIABLES
;; ============================================
(define-data-var total-clicks uint u0)
(define-data-var total-fees-collected uint u0)
(define-data-var last-clicker (optional principal) none)
(define-data-var last-activity-block uint u0)
(define-data-var unique-users uint u0)
(define-data-var is-paused bool false)

;; ============================================
;; DATA MAPS
;; ============================================
(define-map user-clicks principal uint)
(define-map user-streaks principal uint)
(define-map user-first-click principal uint)

;; ============================================
;; PRIVATE FUNCTIONS
;; ============================================

;; Check if contract is active
(define-private (check-not-paused)
  (ok (asserts! (not (var-get is-paused)) ERR-CONTRACT-PAUSED))
)

;; Check if caller is owner
(define-private (check-owner)
  (ok (asserts! (is-eq tx-sender contract-owner) ERR-NOT-OWNER))
)

;; Collect interaction fee
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

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

(define-read-only (get-version)
  VERSION
)

(define-read-only (get-contract-name)
  CONTRACT-NAME
)

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

(define-read-only (is-contract-paused)
  (var-get is-paused)
)

(define-read-only (get-stats (user principal))
  {
    total: (var-get total-clicks),
    user-clicks: (get-user-clicks user),
    streak: (get-user-streak user),
    last-clicker: (var-get last-clicker),
    fees-collected: (var-get total-fees-collected),
    paused: (var-get is-paused)
  }
)

(define-read-only (get-contract-info)
  {
    name: CONTRACT-NAME,
    version: VERSION,
    total-clicks: (var-get total-clicks),
    unique-users: (var-get unique-users),
    fee: interaction-fee,
    last-activity: (var-get last-activity-block),
    owner: contract-owner,
    paused: (var-get is-paused)
  }
)

;; ============================================
;; PUBLIC FUNCTIONS
;; ============================================

;; Simple click - costs 0.001 STX
(define-public (click)
  (let
    (
      (current-clicks (get-user-clicks tx-sender))
      (current-streak (get-user-streak tx-sender))
      (new-count (+ current-clicks u1))
      (new-total (+ (var-get total-clicks) u1))
    )
    ;; Check contract is active
    (try! (check-not-paused))
    ;; Track new user before fee
    (track-new-user)
    ;; Collect fee
    (try! (collect-fee))
    ;; Update state
    (map-set user-clicks tx-sender new-count)
    (map-set user-streaks tx-sender (+ current-streak u1))
    (var-set total-clicks new-total)
    (var-set last-clicker (some tx-sender))
    (var-set last-activity-block block-height)
    ;; Emit enhanced event
    (print {
      event: "click",
      version: VERSION,
      user: tx-sender,
      user-total: new-count,
      global-total: new-total,
      block: block-height
    })
    (ok new-count)
  )
)

;; Multi-click - costs 0.001 STX (capped at 100)
(define-public (multi-click (count uint))
  (let
    (
      (current-clicks (get-user-clicks tx-sender))
      (safe-count (if (> count MAX-MULTI-CLICK) MAX-MULTI-CLICK count))
      (new-count (+ current-clicks safe-count))
      (new-total (+ (var-get total-clicks) safe-count))
    )
    ;; Check contract is active
    (try! (check-not-paused))
    ;; Validate input
    (asserts! (> count u0) ERR-ZERO-VALUE)
    ;; Track new user
    (track-new-user)
    ;; Collect fee
    (try! (collect-fee))
    ;; Update state
    (map-set user-clicks tx-sender new-count)
    (var-set total-clicks new-total)
    (var-set last-clicker (some tx-sender))
    (var-set last-activity-block block-height)
    ;; Emit enhanced event
    (print {
      event: "multi-click",
      version: VERSION,
      user: tx-sender,
      added: safe-count,
      user-total: new-count,
      global-total: new-total,
      block: block-height
    })
    (ok safe-count)
  )
)

;; Reset streak - costs 0.001 STX
(define-public (reset-streak)
  (begin
    (try! (check-not-paused))
    (try! (collect-fee))
    (map-set user-streaks tx-sender u0)
    (var-set last-activity-block block-height)
    (print {
      event: "reset-streak",
      version: VERSION,
      user: tx-sender,
      block: block-height
    })
    (ok true)
  )
)

;; Ping - costs 0.001 STX
(define-public (ping)
  (begin
    (try! (check-not-paused))
    (try! (collect-fee))
    (var-set last-activity-block block-height)
    (print {
      event: "ping",
      version: VERSION,
      user: tx-sender,
      block: block-height
    })
    (ok block-height)
  )
)

;; ============================================
;; ADMIN FUNCTIONS
;; ============================================

;; Pause contract (owner only)
(define-public (pause)
  (begin
    (try! (check-owner))
    (var-set is-paused true)
    (print {
      event: "contract-paused",
      version: VERSION,
      by: tx-sender,
      block: block-height
    })
    (ok true)
  )
)

;; Unpause contract (owner only)
(define-public (unpause)
  (begin
    (try! (check-owner))
    (var-set is-paused false)
    (print {
      event: "contract-unpaused",
      version: VERSION,
      by: tx-sender,
      block: block-height
    })
    (ok true)
  )
)
