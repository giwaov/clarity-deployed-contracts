(define-non-fungible-token shareable-rights-nft uint)

(define-data-var token-id-nonce uint u0)

(define-map token-privileges 
  {token-id: uint, privilege-id: uint, user: principal} 
  {expires: uint, active: bool})

(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-privilege-expired (err u101))
(define-constant err-no-privilege (err u102))

(define-read-only (get-last-token-id)
  (ok (var-get token-id-nonce)))

(define-read-only (get-owner (token-id uint))
  (ok (unwrap! (nft-get-owner? shareable-rights-nft token-id) err-not-owner)))

(define-read-only (has-privilege (token-id uint) (privilege-id uint) (user principal))
  (match (map-get? token-privileges {token-id: token-id, privilege-id: privilege-id, user: user})
    priv (and (get active priv) (>= (get expires priv) stacks-block-time))
    false))

(define-read-only (get-privilege-expires (token-id uint) (privilege-id uint) (user principal))
  (ok (get expires (unwrap! (map-get? token-privileges {token-id: token-id, privilege-id: privilege-id, user: user}) err-no-privilege))))

(define-public (mint (recipient principal))
  (let ((new-id (+ (var-get token-id-nonce) u1)))
    (try! (nft-mint? shareable-rights-nft new-id recipient))
    (var-set token-id-nonce new-id)
    (ok new-id)))

(define-public (set-privilege 
  (token-id uint) 
  (privilege-id uint) 
  (user principal) 
  (expires uint))
  (let ((owner (unwrap! (nft-get-owner? shareable-rights-nft token-id) err-not-owner)))
    (asserts! (is-eq tx-sender owner) err-not-owner)
    (map-set token-privileges {token-id: token-id, privilege-id: privilege-id, user: user} 
      {expires: expires, active: true})
    (ok true)))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) err-not-owner)
    (try! (nft-transfer? shareable-rights-nft token-id sender recipient))
    (ok true)))

(define-read-only (get-contract-hash)
  (contract-hash? .shareable-rights-nft))

(define-read-only (get-block-time)
  stacks-block-time)
