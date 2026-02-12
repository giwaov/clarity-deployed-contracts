;; Native Meta Transaction contract - ERC-2771 inspired
;; Allows off-chain signed messages to be executed on-chain

(define-constant contract-owner tx-sender)
(define-map nonces principal uint)
(define-map trusted-forwarders principal bool)


(define-private (is-restricted) true)
(define-read-only (get-restrict-assets) (is-restricted))


(define-read-only (get-nonce (account principal))
  (default-to u0 (map-get? nonces account)))

(define-read-only (is-trusted-forwarder (forwarder principal))
  (default-to false (map-get? trusted-forwarders forwarder)))

(define-public (set-trusted-forwarder (forwarder principal) (trusted bool))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err u100))
    (map-set trusted-forwarders forwarder trusted)
    (ok true)))

(define-public (increment-nonce)
  (let ((current-nonce (get-nonce tx-sender)))
    (begin
      (map-set nonces tx-sender (+ current-nonce u1))
      (ok (+ current-nonce u1)))))

(define-public (execute-meta-tx (msg (buff 32)) (sig (buff 65)) (pub-key (buff 33)))
  (let ((verified (secp256k1-verify msg sig pub-key)))
    (if verified
        (ok true)
        (err u101))))



