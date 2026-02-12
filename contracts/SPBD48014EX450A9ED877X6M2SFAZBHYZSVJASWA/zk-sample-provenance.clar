(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))

(define-data-var contract-owner principal tx-sender)

(define-map zk-proofs
  { proof-id: uint }
  {
    sample-id: uint,
    proof-hash: (buff 32),
    verification-key: (buff 32),
    public-inputs: (buff 64),
    prover: principal,
    verified: bool,
    created-at: uint
  }
)

(define-data-var proof-nonce uint u0)

(define-read-only (get-owner)
  (ok (var-get contract-owner))
)

(define-read-only (get-proof (proof-id uint))
  (ok (map-get? zk-proofs { proof-id: proof-id }))
)

(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))
  )
)

(define-public (submit-proof (sample-id uint) (proof-hash (buff 32)) (verification-key (buff 32)) (public-inputs (buff 64)))
  (let
    (
      (proof-id (var-get proof-nonce))
    )
    (asserts! (is-none (map-get? zk-proofs { proof-id: proof-id })) ERR_ALREADY_EXISTS)
    (map-set zk-proofs
      { proof-id: proof-id }
      {
        sample-id: sample-id,
        proof-hash: proof-hash,
        verification-key: verification-key,
        public-inputs: public-inputs,
        prover: tx-sender,
        verified: false,
        created-at: stacks-block-height
      }
    )
    (var-set proof-nonce (+ proof-id u1))
    (ok proof-id)
  )
)

(define-public (verify-proof (proof-id uint))
  (let
    (
      (proof (unwrap! (map-get? zk-proofs { proof-id: proof-id }) ERR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set zk-proofs
      { proof-id: proof-id }
      (merge proof { verified: true })
    ))
  )
)
