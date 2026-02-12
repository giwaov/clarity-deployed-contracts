;; Royalty Registry Contract
;; Manages creator royalties for NFT sales

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-royalty (err u101))

(define-map royalties
  uint
  {
    creator: principal,
    royalty-percent: uint
  }
)

(define-read-only (get-royalty (nft-id uint))
  (map-get? royalties nft-id)
)

(define-public (register-royalty (nft-id uint) (royalty-percent uint))
  (begin
    (asserts! (<= royalty-percent u1000) err-invalid-royalty)
    (map-set royalties nft-id {
      creator: tx-sender,
      royalty-percent: royalty-percent
    })
    (ok true)
  )
)

(define-public (calculate-royalty (nft-id uint) (sale-price uint))
  (match (map-get? royalties nft-id)
    royalty-info (ok (/ (* sale-price (get royalty-percent royalty-info)) u10000))
    (ok u0)
  )
)
