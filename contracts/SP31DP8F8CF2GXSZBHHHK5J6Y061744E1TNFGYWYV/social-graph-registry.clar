
;; social-graph-registry.clar
;; Maps relationships (following/trust) between principals.
;; CLARITY VERSION: 4

(define-map follows
    {follower: principal, following: principal}
    bool
)

(define-map follower-count principal uint)
(define-map following-count principal uint)

(define-public (follow (target principal))
    (let (
        (sender tx-sender)
    )
    (asserts! (not (is-eq sender target)) (err u100))
    (asserts! (is-none (map-get? follows {follower: sender, following: target})) (err u101))

    (map-set follows {follower: sender, following: target} true)
    
    (map-set follower-count target (+ (default-to u0 (map-get? follower-count target)) u1))
    (map-set following-count sender (+ (default-to u0 (map-get? following-count sender)) u1))
    
    (ok true))
)

(define-public (unfollow (target principal))
    (let (
        (sender tx-sender)
    )
    (asserts! (is-some (map-get? follows {follower: sender, following: target})) (err u102))

    (map-delete follows {follower: sender, following: target})
    
    (map-set follower-count target (- (default-to u0 (map-get? follower-count target)) u1))
    (map-set following-count sender (- (default-to u0 (map-get? following-count sender)) u1))
    
    (ok true))
)

(define-read-only (is-following (follower principal) (target principal))
    (default-to false (map-get? follows {follower: follower, following: target}))
)

(define-read-only (get-counts (user principal))
    (ok {
        followers: (default-to u0 (map-get? follower-count user)),
        following: (default-to u0 (map-get? following-count user))
    })
)
