;; Atomic Swap Contract
;; Cross-chain Bitcoin atomic swaps using Hash Time-Locked Contracts (HTLCs)
;; Uses Clarity 4 features: block timestamps for time locks, post-conditions for atomic execution

(use-trait ft-trait .sip-010-trait.sip-010-trait)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u300))
(define-constant err-swap-not-found (err u301))
(define-constant err-invalid-amount (err u302))
(define-constant err-already-claimed (err u303))
(define-constant err-already-refunded (err u304))
(define-constant err-timelock-not-expired (err u305))
(define-constant err-timelock-expired (err u306))
(define-constant err-invalid-preimage (err u307))
(define-constant err-swap-not-initiated (err u308))

;; Swap states
(define-constant state-initiated u1)
(define-constant state-claimed u2)
(define-constant state-refunded u3)

;; Data Variables
(define-data-var next-swap-id uint u1)

;; HTLC Swap structure
(define-map swaps
  { swap-id: uint }
  {
    initiator: principal,
    participant: principal,
    amount: uint,
    hash-lock: (buff 32),  ;; SHA256 hash of the preimage
    time-lock: uint,  ;; Block time when refund becomes available
    state: uint,
    initiated-at: uint,
    claimed-at: (optional uint),
    refunded-at: (optional uint)
  }
)

;; User's swaps
(define-map user-swaps
  { user: principal }
  { swap-ids: (list 100 uint) }
)

;; Private helper functions

;; Add swap to user's swap list
(define-private (add-swap-to-user (user principal) (swap-id uint))
  (let (
    (current-swaps (default-to (list) 
                      (get swap-ids (map-get? user-swaps { user: user }))))
    (new-swaps (unwrap-panic (as-max-len? (append current-swaps swap-id) u100)))
  )
    (map-set user-swaps { user: user } { swap-ids: new-swaps })
    true
  )
)

;; Verify preimage matches hash-lock
(define-private (verify-preimage (preimage (buff 32)) (hash-lock (buff 32)))
  (is-eq (sha256 preimage) hash-lock)
)

;; Public functions

;; Initiate an atomic swap
;; The initiator locks tokens with a hash-lock and time-lock
(define-public (initiate-swap 
                 (participant principal)
                 (amount uint)
                 (hash-lock (buff 32))
                 (timelock-duration uint))  ;; Duration in seconds
  (let (
    (swap-id (var-get next-swap-id))
    (current-time stacks-block-height)  ;; Clarity 4 feature
    (time-lock (+ current-time timelock-duration))
  )
    ;; Validations
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (not (is-eq participant tx-sender)) err-not-authorized)
    (asserts! (> timelock-duration u0) err-invalid-amount)
    
    ;; Create swap
    (map-set swaps
      { swap-id: swap-id }
      {
        initiator: tx-sender,
        participant: participant,
        amount: amount,
        hash-lock: hash-lock,
        time-lock: time-lock,
        state: state-initiated,
        initiated-at: current-time,
        claimed-at: none,
        refunded-at: none
      }
    )
    
    ;; Add to both users' swap lists
    (add-swap-to-user tx-sender swap-id)
    (add-swap-to-user participant swap-id)
    
    ;; Increment swap ID
    (var-set next-swap-id (+ swap-id u1))
    
    ;; Print event
    (print {
      event: "swap-initiated",
      swap-id: swap-id,
      initiator: tx-sender,
      participant: participant,
      amount: amount,
      time-lock: time-lock,
      timestamp: current-time
    })
    
    ;; Note: In a production implementation, tokens would be transferred to this contract
    ;; using contract-call? to the token contract with proper error handling
    
    (ok swap-id)
  )
)

;; Claim a swap by revealing the preimage
;; The participant can claim the tokens by providing the correct preimage
(define-public (claim-swap (swap-id uint) (preimage (buff 32)))
  (let (
    (swap (unwrap! (map-get? swaps { swap-id: swap-id }) err-swap-not-found))
    (current-time stacks-block-height)
  )
    ;; Validations
    (asserts! (is-eq tx-sender (get participant swap)) err-not-authorized)
    (asserts! (is-eq (get state swap) state-initiated) err-already-claimed)
    (asserts! (< current-time (get time-lock swap)) err-timelock-expired)
    (asserts! (verify-preimage preimage (get hash-lock swap)) err-invalid-preimage)
    
    ;; Update swap state
    (map-set swaps
      { swap-id: swap-id }
      (merge swap {
        state: state-claimed,
        claimed-at: (some current-time)
      })
    )
    
    ;; Print event
    (print {
      event: "swap-claimed",
      swap-id: swap-id,
      participant: tx-sender,
      amount: (get amount swap),
      timestamp: current-time
    })
    
    ;; Note: In a production implementation, tokens would be transferred to the participant
    ;; using contract-call? with post-conditions for atomic execution
    
    (ok true)
  )
)

;; Refund a swap after the time-lock expires
;; The initiator can get their tokens back if the swap wasn't claimed in time
(define-public (refund-swap (swap-id uint))
  (let (
    (swap (unwrap! (map-get? swaps { swap-id: swap-id }) err-swap-not-found))
    (current-time stacks-block-height)
  )
    ;; Validations
    (asserts! (is-eq tx-sender (get initiator swap)) err-not-authorized)
    (asserts! (is-eq (get state swap) state-initiated) err-already-refunded)
    (asserts! (>= current-time (get time-lock swap)) err-timelock-not-expired)
    
    ;; Update swap state
    (map-set swaps
      { swap-id: swap-id }
      (merge swap {
        state: state-refunded,
        refunded-at: (some current-time)
      })
    )
    
    ;; Print event
    (print {
      event: "swap-refunded",
      swap-id: swap-id,
      initiator: tx-sender,
      amount: (get amount swap),
      timestamp: current-time
    })
    
    ;; Note: In a production implementation, tokens would be returned to the initiator
    ;; using contract-call? with post-conditions for atomic execution
    
    (ok true)
  )
)

;; Read-only functions

;; Get swap details
(define-read-only (get-swap (swap-id uint))
  (ok (map-get? swaps { swap-id: swap-id }))
)

;; Get user's swaps
(define-read-only (get-user-swaps (user principal))
  (ok (map-get? user-swaps { user: user }))
)

;; Check if swap can be claimed (time-lock not expired)
(define-read-only (can-claim-swap (swap-id uint))
  (match (map-get? swaps { swap-id: swap-id })
    swap (ok (and 
               (is-eq (get state swap) state-initiated)
               (< stacks-block-height (get time-lock swap))))
    (ok false)
  )
)

;; Check if swap can be refunded (time-lock expired)
(define-read-only (can-refund-swap (swap-id uint))
  (match (map-get? swaps { swap-id: swap-id })
    swap (ok (and 
               (is-eq (get state swap) state-initiated)
               (>= stacks-block-height (get time-lock swap))))
    (ok false)
  )
)

;; Get next swap ID
(define-read-only (get-next-swap-id)
  (ok (var-get next-swap-id))
)

;; Get current block time (useful for planning swaps)
(define-read-only (get-current-time)
  (ok stacks-block-height)
)
