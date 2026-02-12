(define-non-fungible-token role-nft uint)

(define-map token-roles
    { token-id: uint, role: (string-ascii 32) }
    { 
        account: principal,
        expires-at: uint,
        revocable: bool,
        data: (buff 256)
    }
)

(define-map role-approvals
    { token-id: uint, grantor: principal, role: (string-ascii 32) }
    principal
)

(define-map token-owner uint principal)

(define-data-var last-token-id uint u0)

(define-constant err-not-owner (err u100))
(define-constant err-not-found (err u101))
(define-constant err-role-expired (err u102))
(define-constant err-not-revocable (err u103))
(define-constant err-not-approved (err u104))

(define-read-only (get-role-data (token-id uint) (role (string-ascii 32)))
    (ok (map-get? token-roles { token-id: token-id, role: role }))
)

(define-read-only (has-role (token-id uint) (role (string-ascii 32)) (account principal))
    (match (map-get? token-roles { token-id: token-id, role: role })
        role-data 
            (ok (and 
                (is-eq (get account role-data) account)
                (> (get expires-at role-data) stacks-block-time)
            ))
        (ok false)
    )
)

(define-read-only (get-role-expiration (token-id uint) (role (string-ascii 32)))
    (match (map-get? token-roles { token-id: token-id, role: role })
        role-data (ok (get expires-at role-data))
        err-not-found
    )
)

(define-public (mint (recipient principal))
    (let
        (
            (token-id (+ (var-get last-token-id) u1))
        )
        (try! (nft-mint? role-nft token-id recipient))
        (map-set token-owner token-id recipient)
        (var-set last-token-id token-id)
        (ok token-id)
    )
)

(define-public (grant-role 
    (token-id uint)
    (role (string-ascii 32))
    (account principal)
    (expires-at uint)
    (revocable bool)
    (data (buff 256))
)
    (let
        (
            (owner (unwrap! (map-get? token-owner token-id) err-not-found))
        )
        (asserts! (is-eq tx-sender owner) err-not-owner)
        (map-set token-roles { token-id: token-id, role: role }
            {
                account: account,
                expires-at: expires-at,
                revocable: revocable,
                data: data
            }
        )
        (ok true)
    )
)

(define-public (revoke-role (token-id uint) (role (string-ascii 32)))
    (let
        (
            (owner (unwrap! (map-get? token-owner token-id) err-not-found))
            (role-data (unwrap! (map-get? token-roles { token-id: token-id, role: role }) err-not-found))
        )
        (asserts! (is-eq tx-sender owner) err-not-owner)
        (asserts! (get revocable role-data) err-not-revocable)
        (map-delete token-roles { token-id: token-id, role: role })
        (ok true)
    )
)

(define-public (approve-role (token-id uint) (role (string-ascii 32)) (operator principal))
    (let
        (
            (owner (unwrap! (map-get? token-owner token-id) err-not-found))
        )
        (asserts! (is-eq tx-sender owner) err-not-owner)
        (map-set role-approvals { token-id: token-id, grantor: tx-sender, role: role } operator)
        (ok true)
    )
)
