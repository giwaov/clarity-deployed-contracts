;; Stacks Timelock - Time-locked Transactions
;; Schedule future transactions and vesting

(define-constant contract-owner tx-sender)
(define-constant err-not-found (err u100))
(define-constant err-not-owner (err u101))
(define-constant err-not-ready (err u102))
(define-constant err-already-executed (err u103))
(define-constant err-cancelled (err u104))

(define-data-var lock-count uint u0)
(define-data-var total-locked uint u0)

(define-map timelocks uint
  {
    creator: principal,
    beneficiary: principal,
    amount: uint,
    unlock-block: uint,
    created-at: uint,
    executed: bool,
    cancelled: bool,
    memo: (optional (string-utf8 128))
  }
)

(define-map user-locks principal (list 50 uint))

(define-read-only (get-timelock (lock-id uint))
  (map-get? timelocks lock-id)
)

(define-read-only (is-unlocked (lock-id uint))
  (match (map-get? timelocks lock-id)
    lock (and 
      (>= stacks-block-height (get unlock-block lock))
      (not (get executed lock))
      (not (get cancelled lock))
    )
    false
  )
)

(define-read-only (get-time-remaining (lock-id uint))
  (match (map-get? timelocks lock-id)
    lock 
    (if (>= stacks-block-height (get unlock-block lock))
      u0
      (- (get unlock-block lock) stacks-block-height)
    )
    u0
  )
)

(define-read-only (get-stats)
  {
    total-locks: (var-get lock-count),
    total-locked: (var-get total-locked)
  }
)

(define-public (create-timelock (beneficiary principal) (amount uint) (unlock-delay uint) (memo (optional (string-utf8 128))))
  (let (
    (lock-id (var-get lock-count))
  )
    (map-set timelocks lock-id {
      creator: tx-sender,
      beneficiary: beneficiary,
      amount: amount,
      unlock-block: (+ stacks-block-height unlock-delay),
      created-at: stacks-block-height,
      executed: false,
      cancelled: false,
      memo: memo
    })
    
    (var-set lock-count (+ lock-id u1))
    (var-set total-locked (+ (var-get total-locked) amount))
    
    (ok { lock-id: lock-id, unlock-block: (+ stacks-block-height unlock-delay) })
  )
)

(define-public (execute-timelock (lock-id uint))
  (match (map-get? timelocks lock-id)
    lock
    (begin
      (asserts! (>= stacks-block-height (get unlock-block lock)) err-not-ready)
      (asserts! (not (get executed lock)) err-already-executed)
      (asserts! (not (get cancelled lock)) err-cancelled)
      (asserts! (is-eq tx-sender (get beneficiary lock)) err-not-owner)
      
      (map-set timelocks lock-id (merge lock { executed: true }))
      (var-set total-locked (- (var-get total-locked) (get amount lock)))
      
      (ok { lock-id: lock-id, amount: (get amount lock), beneficiary: (get beneficiary lock) })
    )
    err-not-found
  )
)

(define-public (cancel-timelock (lock-id uint))
  (match (map-get? timelocks lock-id)
    lock
    (begin
      (asserts! (is-eq tx-sender (get creator lock)) err-not-owner)
      (asserts! (not (get executed lock)) err-already-executed)
      (asserts! (not (get cancelled lock)) err-cancelled)
      
      (map-set timelocks lock-id (merge lock { cancelled: true }))
      (var-set total-locked (- (var-get total-locked) (get amount lock)))
      
      (ok { lock-id: lock-id, refunded: true })
    )
    err-not-found
  )
)

(define-public (extend-timelock (lock-id uint) (additional-blocks uint))
  (match (map-get? timelocks lock-id)
    lock
    (begin
      (asserts! (is-eq tx-sender (get creator lock)) err-not-owner)
      (asserts! (not (get executed lock)) err-already-executed)
      (asserts! (not (get cancelled lock)) err-cancelled)
      
      (map-set timelocks lock-id 
        (merge lock { unlock-block: (+ (get unlock-block lock) additional-blocks) })
      )
      
      (ok { lock-id: lock-id, new-unlock-block: (+ (get unlock-block lock) additional-blocks) })
    )
    err-not-found
  )
)

