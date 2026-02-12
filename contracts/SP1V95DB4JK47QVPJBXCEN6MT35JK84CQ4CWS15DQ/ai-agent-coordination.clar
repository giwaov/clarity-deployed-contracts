(define-map agent-intents (buff 32) 
  {payload-hash: (buff 32), expiry: uint, nonce: uint, 
   agent-id: principal, status: (string-ascii 20), 
   participants: (list 10 principal)})

(define-map attestations {intent-hash: (buff 32), participant: principal} 
  {signature: (buff 64), accepted: bool})

(define-constant contract-owner tx-sender)
(define-constant err-intent-not-found (err u100))
(define-constant err-already-accepted (err u101))
(define-constant err-intent-expired (err u102))
(define-constant err-not-ready (err u103))
(define-constant err-invalid-status (err u104))

(define-read-only (get-intent (intent-hash (buff 32)))
  (ok (map-get? agent-intents intent-hash)))

(define-read-only (get-attestation (intent-hash (buff 32)) (participant principal))
  (ok (map-get? attestations {intent-hash: intent-hash, participant: participant})))

(define-public (propose-coordination 
  (intent-hash (buff 32))
  (payload-hash (buff 32))
  (expiry uint)
  (nonce uint)
  (agent-id principal)
  (participants (list 10 principal)))
  (begin
    (map-set agent-intents intent-hash 
      {payload-hash: payload-hash, expiry: expiry, nonce: nonce, 
       agent-id: agent-id, status: "Proposed", participants: participants})
    (ok true)))

(define-public (accept-coordination 
  (intent-hash (buff 32))
  (signature (buff 64)))
  (let ((intent (unwrap! (map-get? agent-intents intent-hash) err-intent-not-found)))
    (asserts! (< stacks-block-time (get expiry intent)) err-intent-expired)
    (map-set attestations {intent-hash: intent-hash, participant: tx-sender} 
      {signature: signature, accepted: true})
    (ok true)))

(define-public (execute-coordination (intent-hash (buff 32)))
  (let ((intent (unwrap! (map-get? agent-intents intent-hash) err-intent-not-found)))
    (asserts! (is-eq (get status intent) "Proposed") err-invalid-status)
    (map-set agent-intents intent-hash (merge intent {status: "Executed"}))
    (ok true)))

(define-public (cancel-coordination (intent-hash (buff 32)))
  (let ((intent (unwrap! (map-get? agent-intents intent-hash) err-intent-not-found)))
    (map-set agent-intents intent-hash (merge intent {status: "Cancelled"}))
    (ok true)))

(define-read-only (get-contract-hash)
  (contract-hash? .ai-agent-coordination))

(define-read-only (get-block-time)
  stacks-block-time)
