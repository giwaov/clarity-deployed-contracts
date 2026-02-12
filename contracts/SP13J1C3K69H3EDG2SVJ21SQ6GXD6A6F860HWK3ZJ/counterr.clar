(define-data-var counter uint u0)
(define-data-var owner principal tx-sender) ;; contract deployer is owner
(define-constant ERR_NOT_OWNER u106)

;; Pseudo-random increment using block time
(define-public (increment)
  (let (
        (time stacks-block-time)
        (current (var-get counter))
        ;; VERY basic randomness (good enough for demo)
        (delta (+ u1 (mod time u10)))
       )
    (begin
      (var-set counter (+ current delta))

      ;; Chainhook will listen for this
      (print {
        event: "counter-updated",
        new-value: (var-get counter),
        delta: delta,
        direction: "up",
        timestamp: time,
        caller: tx-sender
      })

      (ok (var-get counter))
    )
  )
)

(define-public (decrement)
  (let (
        (time stacks-block-time)
        (current (var-get counter))
        ;; same pseudo-random delta as increment (1..10)
        (delta (+ u1 (mod time u10)))
       )
    (begin
      ;; subtract if possible, otherwise clamp to zero
      (if (>= current delta)
          (var-set counter (- current delta))
          (var-set counter u0)
      )

      ;; Chainhook will listen for this
      (print {
        event: "counter-updated",
        new-value: (var-get counter),
        delta: delta,
        direction: "down",
        timestamp: time,
        caller: tx-sender
      })

      (ok (var-get counter))
    )
  )
)

;; Reset counter (admin only)
(define-public (reset-counter)
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err ERR_NOT_OWNER))
    (var-set counter u0)
    (print {
      event: "counter-reset",
      caller: tx-sender,
      timestamp: stacks-block-time
    })
    (ok u0)
  )
)

(define-read-only (get-counter)
  (var-get counter)
)
