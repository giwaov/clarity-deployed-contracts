;; Synthetic Assets Platform

(define-data-var next-synth-id uint u1)
(define-map synthetic-assets uint { underlying: (string-ascii 32), collateral: uint, debt: uint, liquidation-ratio: uint })

(define-public (mint-synthetic (underlying (string-ascii 32)) (collateral-amount uint))
  (let ((synth-id (var-get next-synth-id)))
    (try! (stx-transfer? collateral-amount tx-sender (as-contract tx-sender)))
    (map-set synthetic-assets synth-id { underlying: underlying, collateral: collateral-amount, debt: u0, liquidation-ratio: u150 })
    (var-set next-synth-id (+ synth-id u1))
    (ok synth-id)
  )
)

(define-public (burn-synthetic (synth-id uint) (amount uint))
  (let ((synth (unwrap! (map-get? synthetic-assets synth-id) (err u100))))
    (map-set synthetic-assets synth-id (merge synth { debt: (- (get debt synth) amount) }))
    (ok true)
  )
)