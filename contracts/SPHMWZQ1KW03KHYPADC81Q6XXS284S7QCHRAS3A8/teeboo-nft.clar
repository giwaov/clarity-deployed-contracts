;; contracts/teeboo-nft.clar

(define-non-fungible-token dolphin-streak-nft uint)
(define-data-var last-token-id uint u0)

(define-constant BLOCKS_PER_DAY u144)
(define-constant ERR_ALREADY_MINTED_TODAY u106)

(define-map last-mint-map principal uint)

(define-read-only (get-day-index)
  (/ burn-block-height BLOCKS_PER_DAY)
)

(define-public (mint)
  (let (
    (user tx-sender)
    (today (get-day-index))
    (next-id (+ (var-get last-token-id) u1))
    (user-last-mint (default-to u999999 (map-get? last-mint-map user)))
  )
   
    (asserts! (or (is-eq user-last-mint u999999) (< user-last-mint today)) (err ERR_ALREADY_MINTED_TODAY))

  
    (try! (nft-mint? dolphin-streak-nft next-id user))
    (map-set last-mint-map user today)
    (var-set last-token-id next-id)
    
    (ok next-id)
  )
)


(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
  (ok (some u"https://stackstreak.vercel.app/assets/dolphin.json"))
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? dolphin-streak-nft token-id))
)


(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) (err u403))
  
    (nft-transfer? dolphin-streak-nft token-id sender recipient)
  )
)