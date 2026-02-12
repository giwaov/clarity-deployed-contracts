;; title: counter
;; version: 1.0.0
;; summary: A simple counter contract using Clarity 4 features
;; description: Demonstrates Clarity 4: contract-hash? for contract verification

;; data vars
(define-data-var count uint u0)

;; public functions
(define-public (increment)
  (begin
    (var-set count (+ (var-get count) u1))
    (ok (var-get count))
  )
)

(define-public (decrement)
  (begin
    (let ((current (var-get count)))
      (if (> current u0)
        (begin
          (var-set count (- current u1))
          (ok (var-get count))
        )
        (err u1)
      )
    )
  )
)

;; read only functions
(define-read-only (get-count)
  (ok (var-get count))
)

;; Note: to-ascii? is not yet available on testnet
;; Clarity 4 feature: Get count as ASCII string (disabled for testnet compatibility)
;; (define-read-only (get-count-as-string)
;;   (ok (to-ascii? (var-get count)))
;; )

;; Get current burn block height (alternative to stacks-block-time for testnet compatibility)
(define-read-only (get-current-block-height)
  (ok burn-block-height)
)

;; Clarity 4 feature: Get contract hash (contract-hash?)
;; Returns (response (buff 32) uint) - the hash of the contract's code body
(define-read-only (get-contract-hash (contract-principal principal))
  (contract-hash? contract-principal)
)

;; Clarity 4 feature: Verify contract hash
;; Checks if the contract hash matches the expected hash
(define-read-only (verify-contract-hash (contract-principal principal) (expected-hash (buff 32)))
  (let ((contract-hash-result (contract-hash? contract-principal)))
    (match contract-hash-result
      hash (ok (is-eq hash expected-hash))
      err-code (ok false)
    )
  )
)
