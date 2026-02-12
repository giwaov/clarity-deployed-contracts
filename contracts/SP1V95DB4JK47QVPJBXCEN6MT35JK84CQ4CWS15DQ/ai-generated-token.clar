(define-constant ERR_NOT_AUTHORIZED (err u400))
(define-constant ERR_NOT_FOUND (err u401))
(define-constant ERR_INVALID_PROOF (err u402))
(define-constant ERR_CHALLENGE_PERIOD (err u403))

(define-non-fungible-token ai-generated-token uint)

(define-data-var token-id-nonce uint u0)
(define-data-var proof-type (string-ascii 20) "zkml")
(define-data-var challenge-period uint u144)

(define-map token-data 
  uint 
  {
    prompt: (buff 256),
    aigc-data: (buff 512),
    proof: (buff 512),
    verified: bool,
    timestamp: uint
  }
)

(define-map token-owners uint principal)

(define-read-only (get-last-token-id)
  (ok (var-get token-id-nonce))
)

(define-read-only (get-token-uri (id uint))
  (ok none)
)

(define-read-only (get-owner (id uint))
  (ok (nft-get-owner? ai-generated-token id))
)

(define-public (transfer (id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_NOT_AUTHORIZED)
    (nft-transfer? ai-generated-token id sender recipient)
  )
)

(define-public (add-aigc-data 
  (token-id uint) 
  (prompt (buff 256)) 
  (aigc-data (buff 512)) 
  (proof (buff 512))
)
  (let (
    (owner (unwrap! (nft-get-owner? ai-generated-token token-id) ERR_NOT_FOUND))
    (is-valid (unwrap! (verify prompt aigc-data proof) ERR_INVALID_PROOF))
  )
    (asserts! (is-eq tx-sender owner) ERR_NOT_AUTHORIZED)
    (if (is-eq (var-get proof-type) "zkml")
      (asserts! is-valid ERR_INVALID_PROOF)
      true
    )
    (map-set token-data token-id {
      prompt: prompt,
      aigc-data: aigc-data,
      proof: proof,
      verified: is-valid,
      timestamp: stacks-block-time
    })
    (print {event: "aigc-data", token-id: token-id, prompt: prompt, aigc-data: aigc-data})
    (ok true)
  )
)

(define-public (update-aigc-data 
  (token-id uint) 
  (prompt (buff 256)) 
  (aigc-data (buff 512))
)
  (let (
    (owner (unwrap! (nft-get-owner? ai-generated-token token-id) ERR_NOT_FOUND))
    (data (unwrap! (map-get? token-data token-id) ERR_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender owner) ERR_NOT_AUTHORIZED)
    (asserts! 
      (>= (- stacks-block-time (get timestamp data)) (var-get challenge-period))
      ERR_CHALLENGE_PERIOD
    )
    (map-set token-data token-id (merge data {
      prompt: prompt,
      aigc-data: aigc-data,
      timestamp: stacks-block-time
    }))
    (print {event: "update", token-id: token-id, prompt: prompt, aigc-data: aigc-data})
    (ok true)
  )
)

(define-public (verify 
  (prompt (buff 256)) 
  (aigc-data (buff 512)) 
  (proof (buff 512))
)
  (let (
    (data-hash (sha256 (concat prompt aigc-data)))
  )
    (if (is-eq (var-get proof-type) "zkml")
      (ok (> (len proof) u0))
      (ok true)
    )
  )
)

(define-public (mint (recipient principal) (prompt (buff 256)))
  (let (
    (id (+ (var-get token-id-nonce) u1))
  )
    (try! (nft-mint? ai-generated-token id recipient))
    (var-set token-id-nonce id)
    (ok id)
  )
)

(define-read-only (get-token-data (token-id uint))
  (ok (map-get? token-data token-id))
)

(define-read-only (get-prompt (token-id uint))
  (ok (get prompt (default-to 
    {prompt: 0x00, aigc-data: 0x00, proof: 0x00, verified: false, timestamp: u0}
    (map-get? token-data token-id)
  )))
)

(define-public (set-proof-type (new-type (string-ascii 20)))
  (begin
    (asserts! (is-eq tx-sender contract-caller) ERR_NOT_AUTHORIZED)
    (var-set proof-type new-type)
    (ok true)
  )
)
