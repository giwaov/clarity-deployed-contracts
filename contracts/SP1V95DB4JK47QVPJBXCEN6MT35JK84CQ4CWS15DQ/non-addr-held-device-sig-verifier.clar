(define-map registered-keys (buff 33) bool)

(define-constant contract-owner tx-sender)
(define-constant err-invalid-signature (err u100))
(define-constant err-key-not-registered (err u101))

(define-read-only (verify (key (buff 33)) (hash (buff 32)) (signature (buff 64)))
  (if (secp256r1-verify hash signature key)
    (ok 0x024ad318)
    err-invalid-signature))

(define-public (register-key (key (buff 33)))
  (begin
    (map-set registered-keys key true)
    (ok true)))

(define-public (unregister-key (key (buff 33)))
  (begin
    (map-delete registered-keys key)
    (ok true)))

(define-read-only (is-key-registered (key (buff 33)))
  (default-to false (map-get? registered-keys key)))

(define-read-only (get-contract-hash)
  (contract-hash? .non-addr-held-device-sig-verifier))

(define-read-only (get-block-time)
  stacks-block-time)
