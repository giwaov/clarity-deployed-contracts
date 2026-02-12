

(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

(define-non-fungible-token teeboo-nft uint)

(define-constant DEPLOYER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-TIER (err u101))

(define-constant URL_TIER_1 "https://stacks-streak-assets.vercel.app/metadata/dolphin.json")
(define-constant URL_TIER_2 "https://stacks-streak-assets.vercel.app/metadata/shark.json")

(define-data-var last-token-id uint u0)

(define-map token-tier uint uint)



(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
  (let ((tier (default-to u1 (map-get? token-tier token-id))))
    (if (is-eq tier u2)
        (ok (some URL_TIER_2))
        (ok (some URL_TIER_1))
    )
  )
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? teeboo-nft token-id))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
    (nft-transfer? teeboo-nft token-id sender recipient)
  )
)

(define-public (mint)
  (let ((token-id (+ (var-get last-token-id) u1)))
    (try! (nft-mint? teeboo-nft token-id tx-sender))
    (map-set token-tier token-id u1)
    (var-set last-token-id token-id)
    (ok token-id)
  )
)


(define-private (burn-check (id uint) (owner principal))
  (if (is-eq (some owner) (nft-get-owner? teeboo-nft id))
      (nft-burn? teeboo-nft id owner)
      ERR-NOT-AUTHORIZED
  )
)

(define-public (evolve (id1 uint) (id2 uint) (id3 uint) (id4 uint) (id5 uint))
  (let ((new-id (+ (var-get last-token-id) u1)))

    (try! (burn-check id1 tx-sender))
    (try! (burn-check id2 tx-sender))
    (try! (burn-check id3 tx-sender))
    (try! (burn-check id4 tx-sender))
    (try! (burn-check id5 tx-sender))

    (try! (nft-mint? teeboo-nft new-id tx-sender))
    (map-set token-tier new-id u2) 
    (var-set last-token-id new-id)
    (ok new-id)
  )
)