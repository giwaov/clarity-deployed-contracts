;; Achievement Badge System Contract
;; Award and track user achievements

(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-already-earned (err u101))
(define-constant err-badge-not-found (err u102))

(define-data-var badge-nonce uint u0)

(define-map badges
    uint
    {
        name: (string-ascii 50),
        description: (string-utf8 200),
        image-uri: (string-ascii 200),
        creator: principal,
        total-awarded: uint,
        active: bool
    }
)

(define-map user-badges {user: principal, badge-id: uint} uint) ;; timestamp
(define-map user-badge-count principal uint)

(define-public (create-badge
    (name (string-ascii 50))
    (description (string-utf8 200))
    (image-uri (string-ascii 200)))
    (let ((badge-id (var-get badge-nonce)))
        (map-set badges badge-id {
            name: name,
            description: description,
            image-uri: image-uri,
            creator: tx-sender,
            total-awarded: u0,
            active: true
        })
        (var-set badge-nonce (+ badge-id u1))
        (ok badge-id)
    )
)

(define-public (award-badge (user principal) (badge-id uint))
    (let
        (
            (badge (unwrap! (map-get? badges badge-id) err-badge-not-found))
            (badge-key {user: user, badge-id: badge-id})
        )
        (asserts! (is-eq tx-sender (get creator badge)) err-not-authorized)
        (asserts! (get active badge) err-badge-not-found)
        (asserts! (is-none (map-get? user-badges badge-key)) err-already-earned)
        
        (map-set user-badges badge-key block-height)
        (map-set user-badge-count user 
            (+ u1 (default-to u0 (map-get? user-badge-count user))))
        (map-set badges badge-id (merge badge {
            total-awarded: (+ (get total-awarded badge) u1)
        }))
        (ok true)
    )
)

(define-public (revoke-badge (user principal) (badge-id uint))
    (let
        (
            (badge (unwrap! (map-get? badges badge-id) err-badge-not-found))
            (badge-key {user: user, badge-id: badge-id})
        )
        (asserts! (is-eq tx-sender (get creator badge)) err-not-authorized)
        (asserts! (is-some (map-get? user-badges badge-key)) err-badge-not-found)
        
        (map-delete user-badges badge-key)
        (map-set user-badge-count user
            (- (default-to u1 (map-get? user-badge-count user)) u1))
        (ok true)
    )
)

(define-public (deactivate-badge (badge-id uint))
    (let ((badge (unwrap! (map-get? badges badge-id) err-badge-not-found)))
        (asserts! (is-eq tx-sender (get creator badge)) err-not-authorized)
        (map-set badges badge-id (merge badge {active: false}))
        (ok true)
    )
)

(define-read-only (get-badge (badge-id uint))
    (map-get? badges badge-id)
)

(define-read-only (has-badge (user principal) (badge-id uint))
    (is-some (map-get? user-badges {user: user, badge-id: badge-id}))
)

(define-read-only (get-user-badge-count (user principal))
    (default-to u0 (map-get? user-badge-count user))
)

(define-read-only (get-badge-earned-block (user principal) (badge-id uint))
    (map-get? user-badges {user: user, badge-id: badge-id})
)
