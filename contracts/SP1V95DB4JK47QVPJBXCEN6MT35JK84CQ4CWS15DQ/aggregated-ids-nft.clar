(define-constant ERR_NOT_AUTHORIZED (err u500))
(define-constant ERR_NOT_FOUND (err u501))
(define-constant ERR_INVALID_SIGNATURE (err u502))

(define-non-fungible-token aggregated-ids-nft uint)

(define-data-var token-id-nonce uint u0)

(define-map identities-root 
  uint 
  (buff 32)
)

(define-map token-owners uint principal)

(define-read-only (get-last-token-id)
  (ok (var-get token-id-nonce))
)

(define-read-only (get-token-uri (id uint))
  (ok none)
)

(define-read-only (get-owner (id uint))
  (ok (nft-get-owner? aggregated-ids-nft id))
)

(define-public (transfer (id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_NOT_AUTHORIZED)
    (nft-transfer? aggregated-ids-nft id sender recipient)
  )
)

(define-public (mint (recipient principal))
  (let (
    (id (+ (var-get token-id-nonce) u1))
  )
    (try! (nft-mint? aggregated-ids-nft id recipient))
    (var-set token-id-nonce id)
    (ok id)
  )
)

(define-public (set-identities-root (id uint) (root (buff 32)))
  (let (
    (owner (unwrap! (nft-get-owner? aggregated-ids-nft id) ERR_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender owner) ERR_NOT_AUTHORIZED)
    (map-set identities-root id root)
    (print {event: "set-identities-root", id: id, root: root})
    (ok true)
  )
)

(define-read-only (get-identities-root (id uint))
  (ok (map-get? identities-root id))
)

(define-public (verify-identities-binding 
  (id uint) 
  (owner-address principal) 
  (user-ids (list 10 (string-utf8 128))) 
  (root (buff 32)) 
  (signature (buff 65))
)
  (let (
    (nft-owner (unwrap! (nft-get-owner? aggregated-ids-nft id) ERR_NOT_FOUND))
    (stored-root (unwrap! (map-get? identities-root id) ERR_NOT_FOUND))
    (computed-hash (compute-hash user-ids))
  )
    (asserts! (is-eq nft-owner owner-address) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq stored-root root) ERR_INVALID_SIGNATURE)
    (asserts! (is-eq computed-hash root) ERR_INVALID_SIGNATURE)
    (let (
      (msg-hash (sha256 root))
      (verified (verify-signature msg-hash signature nft-owner))
    )
      (asserts! verified ERR_INVALID_SIGNATURE)
      (ok true)
    )
  )
)

(define-private (compute-hash (user-ids (list 10 (string-utf8 128))))
  (fold hash-item user-ids 0x0000000000000000000000000000000000000000000000000000000000000000)
)

(define-private (hash-item (item (string-utf8 128)) (acc (buff 32)))
  (sha256 (concat acc (sha256 0x00)))
)

(define-private (verify-signature (msg-hash (buff 32)) (signature (buff 65)) (signer principal))
  true
)

(define-private (principal-to-string (p principal))
  (unwrap-panic (principal-destruct? p))
)

(define-private (uint-to-string (value uint))
  (if (is-eq value u0)
    "0"
    (unwrap-panic (to-ascii? value))
  )
)
