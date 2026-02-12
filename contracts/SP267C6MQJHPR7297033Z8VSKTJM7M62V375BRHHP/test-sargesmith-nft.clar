;; using the SIP009 interface

;; mainnet
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; declare a new NFT
(define-non-fungible-token sargesmith-nft uint)

;; store the last issued token ID
(define-data-var last-id uint u0)

;; mint a new NFT
(define-public (mint-nft)
  (mint tx-sender)
)

;; SIP009: Transfer token to a specified principal
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
     (asserts! (is-eq tx-sender sender) (err u403))
     ;; Make sure to replace NFT-FACTORY
     (nft-transfer? sargesmith-nft token-id sender recipient))
)

(define-public (transfer-memo (token-id uint) (sender principal) (recipient principal) (memo (buff 34)))
  (begin 
    (try! (transfer token-id sender recipient))
    (print memo)
    (ok true))
)

;; SIP009: Get the owner of the specified token ID
(define-read-only (get-owner (token-id uint))
  ;; Make sure to replace NFT-NAME
  (ok (nft-get-owner? sargesmith-nft token-id))
)

;; SIP009: Get the last token ID
(define-read-only (get-last-token-id)
  (ok (var-get last-id))
)

;; SIP009: Get the token URI. You can set it to any other URI
(define-read-only (get-token-uri (token-id uint))
  (ok (some "https://ipfs.io/ipfs/bafkreiekadhuwanfpql3hly3hklpkr6ftfz73zwevmtnsx6mk7rfnrgru4"))
)

;; Internal - Mint new NFT
(define-private (mint (new-owner principal))
    (let ((next-id (+ u1 (var-get last-id))))
      (var-set last-id next-id)
      ;; You can replace NFT-FACTORY with another name if you'd like
      (nft-mint? sargesmith-nft next-id new-owner)
    )
)