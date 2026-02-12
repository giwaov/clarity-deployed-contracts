(define-map endorsements (buff 32) 
  {endorser: principal, signature: (buff 64), 
   function-hash: (buff 32), valid-since: uint, 
   valid-by: uint, nonce: uint})

(define-map used-nonces (buff 32) bool)

(define-constant contract-owner tx-sender)
(define-constant err-invalid-endorsement (err u100))
(define-constant err-expired (err u101))
(define-constant err-nonce-used (err u102))
(define-constant err-not-valid-yet (err u103))

(define-read-only (get-endorsement (endorsement-hash (buff 32)))
  (ok (map-get? endorsements endorsement-hash)))

(define-read-only (is-nonce-used (nonce (buff 32)))
  (default-to false (map-get? used-nonces nonce)))

(define-public (submit-endorsement 
  (endorsement-hash (buff 32))
  (endorser principal)
  (signature (buff 64))
  (function-hash (buff 32))
  (valid-since uint)
  (valid-by uint)
  (nonce uint))
  (let ((nonce-hash (sha256 (unwrap-panic (to-consensus-buff? nonce)))))
    (asserts! (not (is-nonce-used nonce-hash)) err-nonce-used)
    (asserts! (>= stacks-block-time valid-since) err-not-valid-yet)
    (asserts! (<= stacks-block-time valid-by) err-expired)
    (map-set endorsements endorsement-hash 
      {endorser: endorser, signature: signature, function-hash: function-hash, 
       valid-since: valid-since, valid-by: valid-by, nonce: nonce})
    (map-set used-nonces nonce-hash true)
    (ok true)))

(define-public (verify-endorsement (endorsement-hash (buff 32)))
  (let ((endorsement (unwrap! (map-get? endorsements endorsement-hash) err-invalid-endorsement)))
    (asserts! (>= stacks-block-time (get valid-since endorsement)) err-not-valid-yet)
    (asserts! (<= stacks-block-time (get valid-by endorsement)) err-expired)
    (ok true)))

(define-read-only (get-contract-hash)
  (contract-hash? .endorsement))

(define-read-only (get-block-time)
  stacks-block-time)
