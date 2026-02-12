(define-non-fungible-token real-estate-nft uint)

(define-data-var token-id-nonce uint u0)

(define-map token-property uint 
  {legal-description: (string-ascii 256), 
   address: (string-ascii 256), 
   geo-json: (string-ascii 512), 
   parcel-id: (string-ascii 64),
   legal-owner: principal,
   operating-agreement-hash: (buff 32),
   manager: principal})

(define-map token-debt uint {debt-token: principal, debt-amount: uint, foreclosed: bool})

(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-not-manager (err u101))
(define-constant err-already-foreclosed (err u102))

(define-read-only (get-last-token-id)
  (ok (var-get token-id-nonce)))

(define-read-only (get-owner (token-id uint))
  (ok (unwrap! (nft-get-owner? real-estate-nft token-id) err-not-owner)))

(define-read-only (get-property-info (token-id uint))
  (ok (unwrap! (map-get? token-property token-id) err-not-owner)))

(define-read-only (get-debt-info (token-id uint))
  (ok (unwrap! (map-get? token-debt token-id) err-not-owner)))

(define-public (mint 
  (recipient principal)
  (legal-description (string-ascii 256))
  (address (string-ascii 256))
  (geo-json (string-ascii 512))
  (parcel-id (string-ascii 64))
  (legal-owner principal)
  (operating-agreement-hash (buff 32))
  (manager principal))
  (let ((new-id (+ (var-get token-id-nonce) u1)))
    (try! (nft-mint? real-estate-nft new-id recipient))
    (map-set token-property new-id 
      {legal-description: legal-description, address: address, geo-json: geo-json, 
       parcel-id: parcel-id, legal-owner: legal-owner, 
       operating-agreement-hash: operating-agreement-hash, manager: manager})
    (map-set token-debt new-id {debt-token: contract-owner, debt-amount: u0, foreclosed: false})
    (var-set token-id-nonce new-id)
    (ok new-id)))

(define-public (set-debt (token-id uint) (debt-token principal) (debt-amount uint))
  (let ((property (unwrap! (map-get? token-property token-id) err-not-owner)))
    (asserts! (is-eq tx-sender (get manager property)) err-not-manager)
    (map-set token-debt token-id {debt-token: debt-token, debt-amount: debt-amount, foreclosed: false})
    (ok true)))

(define-public (foreclose (token-id uint))
  (let ((property (unwrap! (map-get? token-property token-id) err-not-owner))
        (debt (unwrap! (map-get? token-debt token-id) err-not-owner)))
    (asserts! (is-eq tx-sender (get manager property)) err-not-manager)
    (asserts! (not (get foreclosed debt)) err-already-foreclosed)
    (map-set token-debt token-id (merge debt {foreclosed: true}))
    (ok true)))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) err-not-owner)
    (try! (nft-transfer? real-estate-nft token-id sender recipient))
    (ok true)))

(define-read-only (get-contract-hash)
  (contract-hash? .real-estate-nft))

(define-read-only (get-block-time)
  stacks-block-time)
