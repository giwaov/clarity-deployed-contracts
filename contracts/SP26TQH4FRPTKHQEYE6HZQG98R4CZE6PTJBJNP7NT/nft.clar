;; nft.clar

(define-non-fungible-token example-nft uint)

(define-data-var last-token-id uint u0)

(define-public (mint (recipient principal))
  (let ((token-id (+ (var-get last-token-id) u1)))
    (begin
      (try! (nft-mint? example-nft token-id recipient))
      (var-set last-token-id token-id)
      (ok token-id)
    )
  )
)

(define-read-only (get-owner (token-id uint))
  (nft-get-owner? example-nft token-id)
)
