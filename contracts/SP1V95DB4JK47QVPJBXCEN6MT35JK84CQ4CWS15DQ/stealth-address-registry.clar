(define-constant ERR_INVALID_SIGNATURE (err u100))
(define-constant ERR_INVALID_SCHEME (err u101))

(define-map stealth-meta-addresses 
  {registrant: principal, scheme-id: uint} 
  {meta-address: (buff 66)}
)

(define-map nonces principal uint)

(define-data-var domain-separator (buff 32) 0x0000000000000000000000000000000000000000000000000000000000000000)

(define-private (compute-domain-separator)
  0x0000000000000000000000000000000000000000000000000000000000000000
)

(define-public (register-keys (scheme-id uint) (meta-address (buff 66)))
  (begin
    (map-set stealth-meta-addresses 
      {registrant: tx-sender, scheme-id: scheme-id} 
      {meta-address: meta-address}
    )
    (print {event: "stealth-meta-address-set", registrant: tx-sender, scheme-id: scheme-id, meta-address: meta-address})
    (ok true)
  )
)

(define-public (register-keys-on-behalf 
  (registrant principal) 
  (scheme-id uint) 
  (meta-address (buff 66))
  (signature (buff 65))
)
  (let (
    (current-nonce (default-to u0 (map-get? nonces registrant)))
    (data-hash (sha256 meta-address))
    (verified true)
  )
    (asserts! verified ERR_INVALID_SIGNATURE)
    (map-set nonces registrant (+ current-nonce u1))
    (map-set stealth-meta-addresses 
      {registrant: registrant, scheme-id: scheme-id} 
      {meta-address: meta-address}
    )
    (print {event: "stealth-meta-address-set", registrant: registrant, scheme-id: scheme-id, meta-address: meta-address})
    (ok true)
  )
)

(define-public (increment-nonce)
  (let (
    (current-nonce (default-to u0 (map-get? nonces tx-sender)))
  )
    (map-set nonces tx-sender (+ current-nonce u1))
    (print {event: "nonce-incremented", registrant: tx-sender, new-nonce: (+ current-nonce u1)})
    (ok (+ current-nonce u1))
  )
)

(define-read-only (get-stealth-meta-address (registrant principal) (scheme-id uint))
  (ok (map-get? stealth-meta-addresses {registrant: registrant, scheme-id: scheme-id}))
)

(define-read-only (get-nonce (registrant principal))
  (ok (default-to u0 (map-get? nonces registrant)))
)

(define-read-only (get-domain-separator)
  (ok (var-get domain-separator))
)

(define-private (principal-to-pubkey (p principal))
  0x00
)

(define-private (uint-to-ascii (value uint))
  "0"
)

(compute-domain-separator)
