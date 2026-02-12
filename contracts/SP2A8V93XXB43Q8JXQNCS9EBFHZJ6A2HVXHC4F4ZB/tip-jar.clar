;; STX Tip Jar - Clarity contract
;; - Immutable creator address
;; - Minimum tip enforced on-chain
;; - Tracks total STX tipped and last 5 tippers

(define-constant CREATOR 'SP2VHX4R7QMX5SPMGV359YVB9V3GAC645P0Y5YG3C)
(define-constant MIN_TIP u100000) ;; 0.1 STX in microSTX

(define-data-var total-tips uint u0)
(define-data-var tip-counter uint u0)

(define-map recent-tips { index: uint } { tipper: principal, amount: uint })

(define-read-only (get-total-tips)
  (var-get total-tips)
)

(define-read-only (get-recent-tip (index uint))
  (map-get? recent-tips { index: index })
)

(define-public (tip (amount uint))
  (begin
    (asserts! (>= amount MIN_TIP) (err u100))
    (try! (stx-transfer? amount tx-sender CREATOR))

    (var-set total-tips (+ (var-get total-tips) amount))

    (let ((new-counter (+ (var-get tip-counter) u1)))
      (var-set tip-counter new-counter)
      (let ((slot (mod (- new-counter u1) u5)))
        (map-set recent-tips { index: slot } { tipper: tx-sender, amount: amount })
      )
    )

    (ok true)
  )
)
