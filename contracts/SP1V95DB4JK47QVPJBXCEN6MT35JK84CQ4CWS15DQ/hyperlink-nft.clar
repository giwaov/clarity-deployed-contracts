(define-trait hyperlink-nft-trait
  ((mint (principal uint (optional (buff 256))) (response bool uint))
   (set-hyperlink (uint (buff 256)) (response bool uint))
   (get-hyperlink (uint) (response (optional (buff 256)) uint))
   (owner-of (uint) (response (optional principal) uint))))

(define-constant token-name u"HyperlinkNFT")
(define-constant token-symbol u"HLNFT")
(define-constant token-decimals u0)
(define-data-var total-supply-var uint u0)
(define-map owners uint principal)
(define-map hyperlinks uint (buff 256))


(define-private (is-restricted) true)
(define-read-only (get-restrict-assets) (is-restricted))


(define-private (get-owner (token-id uint))
  (map-get? owners token-id))

(define-private (do-mint (recipient principal) (token-id uint) (hyperlink (optional (buff 256))))
  (begin
    (map-set owners token-id recipient)
    (match hyperlink
      h (map-set hyperlinks token-id h)
      true)
    (var-set total-supply-var (+ (var-get total-supply-var) u1))
    true))

(define-public (mint (recipient principal) (token-id uint) (hyperlink (optional (buff 256))))
  (if (is-none (get-owner token-id))
      (begin
        (do-mint recipient token-id hyperlink)
        (ok true))
      (err u101)))

(define-public (set-hyperlink (token-id uint) (hyperlink (buff 256)))
  (if (is-some (map-get? owners token-id))
      (begin
        (map-set hyperlinks token-id hyperlink)
        (ok true))
      (err u102)))


(define-private (get-hyperlink-priv (token-id uint))
  (map-get? hyperlinks token-id))

(define-read-only (get-hyperlink (token-id uint))
  (ok (get-hyperlink-priv token-id)))

(define-read-only (owner-of (token-id uint))
  (ok (get-owner token-id)))



