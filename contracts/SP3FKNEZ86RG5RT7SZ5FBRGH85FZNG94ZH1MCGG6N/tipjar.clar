;; TipJar Contract - Earn 0.001 STX per interaction
;; Contract 2 of 3 for Stacks Transaction Hub

;; Constants
(define-constant contract-owner tx-sender)
(define-constant interaction-fee u1000) ;; 0.001 STX = 1000 microSTX
(define-constant err-insufficient-balance (err u100))
(define-constant err-transfer-failed (err u101))

;; Data Variables
(define-data-var total-tips uint u0)
(define-data-var tip-count uint u0)
(define-data-var total-fees-collected uint u0)

;; Data Maps
(define-map user-tips-sent principal uint)
(define-map user-tips-received principal uint)
(define-map user-tip-count principal uint)

;; Private function to collect fee
(define-private (collect-fee)
  (begin
    (try! (stx-transfer? interaction-fee tx-sender contract-owner))
    (var-set total-fees-collected (+ (var-get total-fees-collected) interaction-fee))
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-total-tips)
  (var-get total-tips)
)

(define-read-only (get-tip-count)
  (var-get tip-count)
)

(define-read-only (get-total-fees-collected)
  (var-get total-fees-collected)
)

(define-read-only (get-interaction-fee)
  interaction-fee
)

(define-read-only (get-user-tips-sent (user principal))
  (default-to u0 (map-get? user-tips-sent user))
)

(define-read-only (get-user-tips-received (user principal))
  (default-to u0 (map-get? user-tips-received user))
)

(define-read-only (get-user-tip-count (user principal))
  (default-to u0 (map-get? user-tip-count user))
)

(define-read-only (get-stats)
  {
    total-tips: (var-get total-tips),
    tip-count: (var-get tip-count),
    fees-collected: (var-get total-fees-collected)
  }
)

;; Public functions - Each call costs 0.001 STX fee to contract owner

;; Tip the owner - send additional STX + 0.001 STX fee
(define-public (tip-jar (amount uint))
  (let
    (
      (current-sent (get-user-tips-sent tx-sender))
      (current-count (get-user-tip-count tx-sender))
    )
    ;; Collect fee first
    (try! (collect-fee))
    ;; Transfer tip amount to owner
    (try! (stx-transfer? amount tx-sender contract-owner))
    ;; Update stats
    (map-set user-tips-sent tx-sender (+ current-sent amount))
    (map-set user-tip-count tx-sender (+ current-count u1))
    (var-set total-tips (+ (var-get total-tips) amount))
    (var-set tip-count (+ (var-get tip-count) u1))
    (ok amount)
  )
)

;; Quick tip - preset small amount (1000 microSTX = 0.001 STX) + 0.001 fee
(define-public (quick-tip)
  (tip-jar u1000)
)

;; Tip someone else - costs 0.001 STX fee
(define-public (tip-user (recipient principal) (amount uint))
  (let
    (
      (current-sent (get-user-tips-sent tx-sender))
      (current-received (get-user-tips-received recipient))
    )
    ;; Collect fee first
    (try! (collect-fee))
    ;; Transfer STX to recipient
    (try! (stx-transfer? amount tx-sender recipient))
    ;; Update stats
    (map-set user-tips-sent tx-sender (+ current-sent amount))
    (map-set user-tips-received recipient (+ current-received amount))
    (var-set total-tips (+ (var-get total-tips) amount))
    (var-set tip-count (+ (var-get tip-count) u1))
    (ok amount)
  )
)

;; Self-ping - costs 0.001 STX fee
(define-public (self-ping)
  (begin
    (try! (collect-fee))
    (ok tx-sender)
  )
)

;; Donate to owner - costs 0.001 STX fee + donation
(define-public (donate (amount uint))
  (begin
    (try! (collect-fee))
    (try! (stx-transfer? amount tx-sender contract-owner))
    (var-set total-tips (+ (var-get total-tips) amount))
    (ok true)
  )
)
