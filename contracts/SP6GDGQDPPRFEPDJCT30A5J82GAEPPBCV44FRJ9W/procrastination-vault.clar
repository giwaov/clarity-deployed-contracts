;; ============================================
;; PROCRASTINATION VAULT - The Lazy Locker
;; Clarity 2 Smart Contract
;; ============================================

(define-constant ERR_NO_ACTIVE_STREAK (err u404))
(define-constant ERR_ALREADY_ACTIVE (err u409))

(define-map locked-amounts principal uint)

(define-public (start-procrastinating (amount uint))
  (begin
    (asserts! (is-none (map-get? locked-amounts tx-sender)) ERR_ALREADY_ACTIVE)
    (try! (stx-transfer? amount tx-sender .procrastination-vault))
    (map-set locked-amounts tx-sender amount)
    (as-contract (contract-call? .streak-tracker start-streak tx-sender))
  )
)

(define-public (quit-procrastinating)
  (let
    (
      (user tx-sender)
      (amount (unwrap! (map-get? locked-amounts user) ERR_NO_ACTIVE_STREAK))
      (penalty (/ amount u10)) ;; 10%
      (refund (- amount penalty))
    )
    ;; Send penalty to pool
    (try! (as-contract (stx-transfer? penalty tx-sender .penalty-pool)))
    ;; Send refund to user
    (try! (as-contract (stx-transfer? refund tx-sender user)))
    
    ;; Cleanup
    (map-delete locked-amounts user)
    (as-contract (contract-call? .streak-tracker end-streak user))
  )
)

(define-public (claim-rewards)
  (let
    (
      (user tx-sender)
      (amount (unwrap! (map-get? locked-amounts user) ERR_NO_ACTIVE_STREAK))
      (streak-days (unwrap-panic (contract-call? .streak-tracker get-streak-days user)))
      (multiplier (get-multiplier streak-days))
      (bonus (if (> multiplier u100) (/ (* amount (- multiplier u100)) u100) u0))
    )
    ;; Must be at least 1 day to claim without penalty
    (asserts! (>= streak-days u1) (err u403))
    
    ;; Return principal
    (try! (as-contract (stx-transfer? amount tx-sender user)))
    
    ;; Request bonus from pool (if any)
    (if (> bonus u0)
      (match (contract-call? .penalty-pool request-reward bonus user)
        success true
        error false ;; If pool empty, just ignore bonus
      )
      true
    )
    
    ;; Cleanup
    (map-delete locked-amounts user)
    (as-contract (contract-call? .streak-tracker end-streak user))
  )
)

(define-read-only (get-multiplier (days uint))
  (if (>= days u30) u105 ;; 5% bonus
    (if (>= days u14) u103 ;; 3% bonus
      (if (>= days u7) u101 ;; 1% bonus
        u100 ;; 0% bonus
      )
    )
  )
)

;; Called by temptation generator
(define-public (apply-temptation-bonus (user principal) (amount uint))
  (begin
    (asserts! (is-eq contract-caller .temptation-generator) (err u401))
    ;; Payout user principal + amount
    (let
      (
        (locked (unwrap! (map-get? locked-amounts user) ERR_NO_ACTIVE_STREAK))
      )
      (try! (as-contract (stx-transfer? locked tx-sender user)))
      (match (contract-call? .penalty-pool request-reward amount user)
        success true
        error false
      )
      (map-delete locked-amounts user)
      (as-contract (contract-call? .streak-tracker end-streak user))
    )
  )
)
