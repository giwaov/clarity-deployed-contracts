(define-non-fungible-token authorized-nft uint)

(define-data-var token-id-nonce uint u0)
(define-data-var user-limit uint u5)
(define-data-var reset-allowed bool false)

(define-map token-authorizations {token-id: uint, user: principal} {rights: (list 20 (string-ascii 32)), expires: uint})
(define-map token-users uint (list 5 principal))
(define-map contract-rights (string-ascii 32) bool)

(define-constant err-owner-only (err u400))
(define-constant err-invalid-user (err u401))
(define-constant err-authorization-expired (err u402))
(define-constant err-user-limit-reached (err u403))
(define-constant err-reset-not-allowed (err u404))
(define-constant err-invalid-right (err u405))

(define-read-only (get-rights)
  (ok (list "display" "copy" "distribute" "modify" "commercial-use")))

(define-read-only (get-expires (token-id uint) (user principal))
  (ok (get expires (default-to {rights: (list), expires: u0} (map-get? token-authorizations {token-id: token-id, user: user})))))

(define-read-only (get-user-rights (token-id uint) (user principal))
  (ok (get rights (default-to {rights: (list), expires: u0} (map-get? token-authorizations {token-id: token-id, user: user})))))

(define-read-only (check-authorization-availability (token-id uint))
  (let ((users (default-to (list) (map-get? token-users token-id))))
    (ok (< (len users) (var-get user-limit)))))

(define-public (transfer (id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) err-owner-only)
    (nft-transfer? authorized-nft id sender recipient)))

(define-public (mint (recipient principal))
  (let ((token-id (+ (var-get token-id-nonce) u1)))
    (try! (nft-mint? authorized-nft token-id recipient))
    (var-set token-id-nonce token-id)
    (ok token-id)))

(define-public (authorize-user (token-id uint) (user principal) (duration uint))
  (let ((owner (unwrap! (nft-get-owner? authorized-nft token-id) err-owner-only))
        (all-rights (unwrap-panic (get-rights))))
    (asserts! (is-eq tx-sender owner) err-owner-only)
    (authorize-user-with-rights token-id user all-rights duration)))

(define-public (authorize-user-with-rights (token-id uint) (user principal) (rights (list 20 (string-ascii 32))) (duration uint))
  (let ((owner (unwrap! (nft-get-owner? authorized-nft token-id) err-owner-only))
        (expires (+ stacks-block-height duration))
        (users (default-to (list) (map-get? token-users token-id))))
    (asserts! (is-eq tx-sender owner) err-owner-only)
    (asserts! (< (len users) (var-get user-limit)) err-user-limit-reached)
    (map-set token-authorizations {token-id: token-id, user: user} {rights: rights, expires: expires})
    (map-set token-users token-id (unwrap-panic (as-max-len? (append users user) u5)))
    (ok true)))

(define-public (transfer-user-rights (token-id uint) (new-user principal))
  (let ((auth (unwrap! (map-get? token-authorizations {token-id: token-id, user: tx-sender}) err-invalid-user)))
    (asserts! (< stacks-block-height (get expires auth)) err-authorization-expired)
    (map-delete token-authorizations {token-id: token-id, user: tx-sender})
    (map-set token-authorizations {token-id: token-id, user: new-user} auth)
    (ok true)))

(define-public (extend-duration (token-id uint) (user principal) (duration uint))
  (let ((owner (unwrap! (nft-get-owner? authorized-nft token-id) err-owner-only))
        (auth (unwrap! (map-get? token-authorizations {token-id: token-id, user: user}) err-invalid-user)))
    (asserts! (is-eq tx-sender owner) err-owner-only)
    (map-set token-authorizations {token-id: token-id, user: user} 
      {rights: (get rights auth), expires: (+ stacks-block-height duration)})
    (ok true)))

(define-public (update-user-rights (token-id uint) (user principal) (rights (list 20 (string-ascii 32))))
  (let ((owner (unwrap! (nft-get-owner? authorized-nft token-id) err-owner-only))
        (auth (unwrap! (map-get? token-authorizations {token-id: token-id, user: user}) err-invalid-user)))
    (asserts! (is-eq tx-sender owner) err-owner-only)
    (map-set token-authorizations {token-id: token-id, user: user}
      {rights: rights, expires: (get expires auth)})
    (ok true)))

(define-public (update-user-limit (new-limit uint))
  (begin
    (asserts! (is-eq tx-sender contract-caller) err-owner-only)
    (var-set user-limit new-limit)
    (ok true)))

(define-public (update-reset-allowed (allowed bool))
  (begin
    (asserts! (is-eq tx-sender contract-caller) err-owner-only)
    (var-set reset-allowed allowed)
    (ok true)))

(define-public (reset-user (token-id uint) (user principal))
  (let ((owner (unwrap! (nft-get-owner? authorized-nft token-id) err-owner-only)))
    (asserts! (is-eq tx-sender owner) err-owner-only)
    (asserts! (var-get reset-allowed) err-reset-not-allowed)
    (map-delete token-authorizations {token-id: token-id, user: user})
    (ok true)))
