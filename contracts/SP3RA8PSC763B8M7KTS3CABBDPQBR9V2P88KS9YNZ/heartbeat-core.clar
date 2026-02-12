;; ============================================
;; HEARTBEAT CORE - Dead Man's Switch Logic
;; Clarity 4 Smart Contract
;; ============================================

(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_EXISTS (err u409))
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_INVALID_INTERVAL (err u400))
(define-constant ERR_SWITCH_TRIGGERED (err u410))

;; Min interval: ~1 day (144 blocks)
(define-constant MIN_INTERVAL u144)
;; Max interval: ~1 year (52560 blocks)
(define-constant MAX_INTERVAL u52560)

(define-map switches principal {
  interval: uint,
  last-check-in: uint,
  grace-period: uint,
  active: bool,
  triggered: bool
})

(define-public (register-switch (interval uint) (grace-period uint))
  (begin
    (asserts! (and (>= interval MIN_INTERVAL) (<= interval MAX_INTERVAL)) ERR_INVALID_INTERVAL)
    (asserts! (> grace-period u0) ERR_INVALID_INTERVAL)
    (asserts! (is-none (map-get? switches tx-sender)) ERR_ALREADY_EXISTS)
    (map-set switches tx-sender {
      interval: interval,
      last-check-in: burn-block-height,
      grace-period: grace-period,
      active: true,
      triggered: false
    })
    (ok true)
  )
)

(define-public (heartbeat)
  (pulse tx-sender)
)

(define-public (guardian-pulse (user principal))
  (begin
    (asserts! (is-eq contract-caller .guardian-network) ERR_NOT_AUTHORIZED)
    (asserts! (is-some (map-get? switches user)) ERR_NOT_FOUND)
    (pulse user)
  )
)

(define-private (pulse (user principal))
  (let
    (
      (switch (unwrap! (map-get? switches user) ERR_NOT_FOUND))
    )
    (asserts! (not (get triggered switch)) ERR_SWITCH_TRIGGERED)
    (asserts! (get active switch) ERR_NOT_FOUND)
    
    ;; Update last-check-in
    (map-set switches user (merge switch { last-check-in: burn-block-height }))
    (ok true)
  )
)

(define-public (update-interval (new-interval uint))
  (let
    (
      (user tx-sender)
      (switch (unwrap! (map-get? switches user) ERR_NOT_FOUND))
    )
    (asserts! (and (>= new-interval MIN_INTERVAL) (<= new-interval MAX_INTERVAL)) ERR_INVALID_INTERVAL)
    (asserts! (not (get triggered switch)) ERR_SWITCH_TRIGGERED)
    
    (map-set switches user (merge switch { interval: new-interval }))
    (ok true)
  )
)

(define-public (deactivate)
  (let
    (
      (user tx-sender)
      (switch (unwrap! (map-get? switches user) ERR_NOT_FOUND))
    )
    (map-set switches user (merge switch { active: false }))
    (ok true)
  )
)

;; Called by anyone (usually a keeper bot or beneficiary) to officially trigger the switch
(define-public (try-trigger (target principal))
  (let
    (
      (switch (unwrap! (map-get? switches target) ERR_NOT_FOUND))
      (deadline (+ (get last-check-in switch) (get interval switch) (get grace-period switch)))
    )
    (asserts! (get active switch) ERR_NOT_FOUND)
    (asserts! (not (get triggered switch)) ERR_SWITCH_TRIGGERED)
    (asserts! (> burn-block-height deadline) (err u403)) ;; Not yet time
    
    ;; Set triggered to true
    (map-set switches target (merge switch { triggered: true }))
    (ok true)
  )
)

(define-read-only (get-status (user principal))
  (map-get? switches user)
)

(define-read-only (is-triggered (user principal))
  (let ((switch (map-get? switches user)))
    (if (is-some switch)
      (get triggered (unwrap-panic switch))
      false
    )
  )
)

(define-read-only (get-deadline (user principal))
  (let ((switch (unwrap! (map-get? switches user) ERR_NOT_FOUND)))
    (ok (+ (get last-check-in switch) (get interval switch) (get grace-period switch)))
  )
)
