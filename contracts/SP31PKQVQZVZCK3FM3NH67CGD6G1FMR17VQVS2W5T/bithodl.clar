(define-constant ERR_INSUFFICIENT_BALANCE (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_NOT_OWNER (err u102))

(define-data-var contract-owner principal tx-sender)
(define-data-var interest-rate uint u500)
(define-data-var total-deposits uint u0)

(define-map deposits
  principal
  uint
)

(define-map deposit-timestamps
  principal
  uint
)

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-read-only (get-interest-rate)
  (var-get interest-rate)
)

(define-read-only (get-total-deposits)
  (var-get total-deposits)
)

(define-read-only (get-user-deposit (user principal))
  (default-to u0 (map-get? deposits user)))

(define-read-only (get-user-balance (user principal))
  (let (
    (deposit-amount (default-to u0 (map-get? deposits user)))
    (deposit-time (default-to u0 (map-get? deposit-timestamps user)))
    (current-time u0)
    (time-diff (- current-time deposit-time))
    (current-interest-rate (var-get interest-rate))
  )
    (if (is-eq deposit-amount u0)
      u0
      (if (< deposit-amount u100000000000)
        (+ deposit-amount
           (* deposit-amount
              (/ (* current-interest-rate time-diff) u1000000)))
        u0
      )
    )
  )
)

(define-public (deposit (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    ;; Note: Removed balance check for MVP - we're just tracking balances
    
    (let (
      (current-deposit (default-to u0 (map-get? deposits tx-sender)))
      (new-deposit (+ current-deposit amount))
    )
      (map-set deposits tx-sender new-deposit)
      (map-set deposit-timestamps tx-sender u0)
      (var-set total-deposits (+ (var-get total-deposits) amount))
      
      ;; MVP: Just tracking balances, no actual STX transfer
      (ok true)
    )
  )
)

(define-public (withdraw (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (let (
      (user-balance (get-user-balance tx-sender))
    )
      (asserts! (>= user-balance amount) ERR_INSUFFICIENT_BALANCE)
      
      (let (
        (current-deposit (default-to u0 (map-get? deposits tx-sender)))
        (new-deposit (- current-deposit amount))
      )
        (if (is-eq new-deposit u0)
          (begin
            (map-delete deposits tx-sender)
            (map-delete deposit-timestamps tx-sender)
          )
          (map-set deposits tx-sender new-deposit)
        )
        
        (var-set total-deposits (- (var-get total-deposits) amount))
        
        ;; MVP: Just tracking balances, no actual STX transfer
        (ok true)
      )
    )
  )
)

(define-public (set-interest-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_OWNER)
    (asserts! (and (>= new-rate u0) (<= new-rate u10000)) ERR_INVALID_AMOUNT)
    
    (var-set interest-rate new-rate)
    (ok true)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_OWNER)
    (asserts! (not (is-eq new-owner tx-sender)) ERR_NOT_OWNER)
    
    (var-set contract-owner new-owner)
    (ok true)
  )
)