(define-read-only (verify-sig (hash (buff 32)) (sig (buff 65)) (pubkey (buff 33)))
    (ok (secp256k1-verify hash sig pubkey))
)
