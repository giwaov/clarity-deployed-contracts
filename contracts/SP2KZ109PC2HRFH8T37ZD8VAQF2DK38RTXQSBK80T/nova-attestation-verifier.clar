
;; nova-attestation-verifier.clar
;; Verify off-chain data
;; CLARITY VERSION: 2

(define-map attestations
    (buff 32) ;; data-hash
    bool ;; verified
)

(define-public (verify-data (data-hash (buff 32)) (signature (buff 65)))
    (begin
        ;; Sig check omitted
        (map-set attestations data-hash true)
        (ok true)
    )
)

(define-read-only (is-verified (data-hash (buff 32)))
    (default-to false (map-get? attestations data-hash))
)
