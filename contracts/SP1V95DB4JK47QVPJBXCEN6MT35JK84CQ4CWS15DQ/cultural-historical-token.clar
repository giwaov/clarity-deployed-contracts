(define-non-fungible-token cultural-historical-token uint)

(define-data-var token-id-nonce uint u0)

(define-map token-attributes uint 
  {catalog-level: (string-ascii 64), 
   creation-date: (string-ascii 64), 
   creator-name: (string-ascii 128), 
   asset-type: (string-ascii 64),
   materials: (string-ascii 256), 
   dimensions: (string-ascii 128), 
   provenance: (string-ascii 512), 
   copyright: (string-ascii 256)})

(define-map token-extended uint 
  {full-text: (string-ascii 1024), 
   exhibitions: (string-ascii 512), 
   documents: (string-ascii 512), 
   urls: (string-ascii 256)})

(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))

(define-read-only (get-last-token-id)
  (ok (var-get token-id-nonce)))

(define-read-only (get-owner (token-id uint))
  (ok (unwrap! (nft-get-owner? cultural-historical-token token-id) err-not-owner)))

(define-read-only (get-attributes (token-id uint))
  (ok (unwrap! (map-get? token-attributes token-id) err-not-owner)))

(define-read-only (get-extended (token-id uint))
  (ok (unwrap! (map-get? token-extended token-id) err-not-owner)))

(define-public (mint 
  (recipient principal)
  (catalog-level (string-ascii 64))
  (creation-date (string-ascii 64))
  (creator-name (string-ascii 128))
  (asset-type (string-ascii 64))
  (materials (string-ascii 256))
  (dimensions (string-ascii 128))
  (provenance (string-ascii 512))
  (copyright (string-ascii 256)))
  (let ((new-id (+ (var-get token-id-nonce) u1)))
    (try! (nft-mint? cultural-historical-token new-id recipient))
    (map-set token-attributes new-id 
      {catalog-level: catalog-level, creation-date: creation-date, creator-name: creator-name, 
       asset-type: asset-type, materials: materials, dimensions: dimensions, 
       provenance: provenance, copyright: copyright})
    (var-set token-id-nonce new-id)
    (ok new-id)))

(define-public (set-extended 
  (token-id uint)
  (full-text (string-ascii 1024))
  (exhibitions (string-ascii 512))
  (documents (string-ascii 512))
  (urls (string-ascii 256)))
  (let ((owner (unwrap! (nft-get-owner? cultural-historical-token token-id) err-not-owner)))
    (asserts! (is-eq tx-sender owner) err-not-owner)
    (map-set token-extended token-id 
      {full-text: full-text, exhibitions: exhibitions, documents: documents, urls: urls})
    (ok true)))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) err-not-owner)
    (try! (nft-transfer? cultural-historical-token token-id sender recipient))
    (ok true)))

(define-read-only (get-contract-hash)
  (contract-hash? .cultural-historical-token))

(define-read-only (get-block-time)
  stacks-block-time)
