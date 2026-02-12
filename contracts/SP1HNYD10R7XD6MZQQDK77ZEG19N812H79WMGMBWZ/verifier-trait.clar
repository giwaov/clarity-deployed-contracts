;; Verifier Trait Definition
;; Used for verifying zero-knowledge proofs or other commitment schemes
(define-trait verifier-trait
  (
    ;; Verify a proof
    ;; Args: proof, public-inputs, root
    (verify-proof ((buff 32) (buff 32) (buff 32)) (response bool uint))
  )
)
