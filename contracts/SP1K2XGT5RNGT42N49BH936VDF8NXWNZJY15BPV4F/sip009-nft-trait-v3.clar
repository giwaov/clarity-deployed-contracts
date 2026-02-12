;; title: sip009-nft-trait
;; version: 1.0.0
;; summary: SIP-009 NFT trait definition.
;; clarity: 4

(define-trait sip009-nft-trait
  (
    (get-last-token-id () (response uint uint))
    (get-token-uri (uint) (response (optional (string-utf8 256)) uint))
    (get-owner (uint) (response (optional principal) uint))
    (transfer (uint principal principal) (response bool uint))
  )
)
