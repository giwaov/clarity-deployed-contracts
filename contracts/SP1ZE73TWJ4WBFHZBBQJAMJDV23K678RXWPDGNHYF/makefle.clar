;; title: Simple Staking Contract
;; version: 1.0.0
;; summary: A simple staking contract for STX tokens
;; description: Allows users to stake and unstake STX tokens with basic reward tracking

;; constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-BALANCE (err u101))
(define-constant ERR-NOTHING-STAKED (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))

;; data vars
(define-data-var total-staked uint u0)
(define-data-var reward-rate uint u100) ;; 100 = 1% reward rate (basis points)

;; data maps
(define-map staked-balances principal uint)

;; public functions

;; Stake STX tokens
;; Note: STX must be sent as part of the transaction (via post-conditions)
(define-public (stake (amount uint))
  (begin
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (let ((current-balance (default-to u0 (map-get? staked-balances tx-sender))))
      (map-set staked-balances tx-sender (+ current-balance amount))
      (var-set total-staked (+ (var-get total-staked) amount))
      (ok true)
    )
  )
)

;; Unstake STX tokens
(define-public (unstake (amount uint))
  (begin
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (let ((staked (default-to u0 (map-get? staked-balances tx-sender))))
      (asserts! (>= staked amount) ERR-INSUFFICIENT-BALANCE)
      (let ((new-balance (- staked amount)))
        (if (is-eq new-balance u0)
          (map-delete staked-balances tx-sender)
          (map-set staked-balances tx-sender new-balance)
        )
        (var-set total-staked (- (var-get total-staked) amount))
        (ok true)
      )
    )
  )
)

;; Claim rewards (simple percentage-based reward)
(define-public (claim-rewards)
  (let ((staked (default-to u0 (map-get? staked-balances tx-sender))))
    (asserts! (> staked u0) ERR-NOTHING-STAKED)
    (let ((rewards (/ (* staked (var-get reward-rate)) u10000)))
      (if (> rewards u0)
        (ok rewards)
        (ok u0)
      )
    )
  )
)

;; read only functions

;; Get staked balance for a user
(define-read-only (get-staked-balance (user principal))
  (ok (default-to u0 (map-get? staked-balances user)))
)

;; Get total staked amount
(define-read-only (get-total-staked)
  (ok (var-get total-staked))
)

;; Get reward rate
(define-read-only (get-reward-rate)
  (ok (var-get reward-rate))
)

;; Calculate pending rewards for a user (simple percentage-based)
(define-read-only (get-pending-rewards (user principal))
  (let ((staked (default-to u0 (map-get? staked-balances user))))
    (if (is-eq staked u0)
      (ok u0)
      (ok (/ (* staked (var-get reward-rate)) u10000))
    )
  )
)