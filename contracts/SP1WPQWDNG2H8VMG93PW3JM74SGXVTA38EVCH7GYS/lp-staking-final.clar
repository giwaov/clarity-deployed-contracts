;; LP Staking Final - Absolutely NO as-contract usage
;; Users manage their own LP tokens, contract only tracks and mints rewards

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant VDEX_TOKEN .vdex-token)
(define-constant ERR_NOT_AUTHORIZED (err u501))
(define-constant ERR_ALREADY_INITIALIZED (err u502))
(define-constant ERR_NOT_INITIALIZED (err u503))
(define-constant ERR_ZERO_AMOUNT (err u504))
(define-constant ERR_NO_STAKE (err u505))

;; Reward rate: 100 VDEX per block (with 6 decimals)
(define-constant REWARD_PER_BLOCK u100000000)

;; Data variables
(define-data-var initialized bool false)
(define-data-var total-staked uint u0)

;; Data maps - just track amounts, no token custody
(define-map stakes principal {amount: uint, reward-checkpoint: uint})

;; Initialize
(define-public (initialize)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (not (var-get initialized)) ERR_ALREADY_INITIALIZED)
    (var-set initialized true)
    (ok true)
  )
)

;; Register stake - user has already sent LP tokens elsewhere, we just record it
(define-public (register-stake (amount uint))
  (let (
    (current-stake (default-to {amount: u0, reward-checkpoint: u0}
                               (map-get? stakes tx-sender)))
    (current-amount (get amount current-stake))
    (pending-rewards (get reward-checkpoint current-stake))
  )
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)

    ;; Update stake record
    (map-set stakes tx-sender {
      amount: (+ current-amount amount),
      reward-checkpoint: (+ pending-rewards (* amount block-height))
    })
    (var-set total-staked (+ (var-get total-staked) amount))

    (ok (+ current-amount amount))
  )
)

;; Unregister stake - user withdraws their tokens themselves, we just update records
(define-public (unregister-stake (amount uint))
  (let (
    (user-stake (unwrap! (map-get? stakes tx-sender) ERR_NO_STAKE))
    (staked-amount (get amount user-stake))
    (checkpoint (get reward-checkpoint user-stake))
  )
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (asserts! (>= staked-amount amount) ERR_NO_STAKE)

    ;; Calculate and mint rewards
    (let (
      (blocks-staked (- (* staked-amount block-height) checkpoint))
      (total (var-get total-staked))
      (rewards (if (> total u0)
                 (/ (* REWARD_PER_BLOCK blocks-staked) total)
                 u0))
      (remaining (- staked-amount amount))
    )
      ;; Mint rewards if any
      (if (> rewards u0)
        (try! (contract-call? VDEX_TOKEN mint rewards tx-sender))
        true
      )

      ;; Update or delete stake
      (if (> remaining u0)
        (map-set stakes tx-sender {
          amount: remaining,
          reward-checkpoint: (* remaining block-height)
        })
        (map-delete stakes tx-sender)
      )
      (var-set total-staked (- total amount))

      (ok {amount: amount, rewards: rewards})
    )
  )
)

;; Claim rewards only
(define-public (claim-rewards)
  (let (
    (user-stake (unwrap! (map-get? stakes tx-sender) ERR_NO_STAKE))
    (staked-amount (get amount user-stake))
    (checkpoint (get reward-checkpoint user-stake))
    (blocks-staked (- (* staked-amount block-height) checkpoint))
    (total (var-get total-staked))
    (rewards (if (> total u0)
               (/ (* REWARD_PER_BLOCK blocks-staked) total)
               u0))
  )
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (> rewards u0) ERR_ZERO_AMOUNT)

    ;; Mint rewards
    (try! (contract-call? VDEX_TOKEN mint rewards tx-sender))

    ;; Reset checkpoint
    (map-set stakes tx-sender {
      amount: staked-amount,
      reward-checkpoint: (* staked-amount block-height)
    })

    (ok rewards)
  )
)

;; Read-only functions
(define-read-only (get-stake (account principal))
  (map-get? stakes account)
)

(define-read-only (get-pending-rewards (account principal))
  (match (map-get? stakes account)
    stake
    (let (
      (staked-amount (get amount stake))
      (checkpoint (get reward-checkpoint stake))
      (blocks-staked (- (* staked-amount block-height) checkpoint))
      (total (var-get total-staked))
      (rewards (if (> total u0)
                 (/ (* REWARD_PER_BLOCK blocks-staked) total)
                 u0))
    )
      (ok rewards)
    )
    (ok u0)
  )
)

(define-read-only (get-total-staked)
  (ok (var-get total-staked))
)

(define-read-only (is-initialized)
  (var-get initialized)
)
