---
title: "Trait publishing"
draft: true
---
```
;; Decentralized Publishing Contract
;; Publish and monetize content on-chain

(define-constant err-not-author (err u100))
(define-constant err-post-not-found (err u101))
(define-constant err-insufficient-payment (err u102))

(define-data-var post-nonce uint u0)

(define-map posts
    uint
    {
        author: principal,
        title: (string-utf8 200),
        content-hash: (buff 32),
        timestamp: uint,
        paywall-amount: uint,
        earnings: uint,
        likes: uint
    }
)

(define-map post-access {post-id: uint, reader: principal} bool)
(define-map author-followers {author: principal, follower: principal} bool)

(define-public (publish-post
    (title (string-utf8 200))
    (content-hash (buff 32))
    (paywall-amount uint))
    (let ((post-id (var-get post-nonce)))
        (map-set posts post-id {
            author: tx-sender,
            title: title,
            content-hash: content-hash,
            timestamp: block-height,
            paywall-amount: paywall-amount,
            earnings: u0,
            likes: u0
        })
        (var-set post-nonce (+ post-id u1))
        (ok post-id)
    )
)

(define-public (purchase-access (post-id uint))
    (let
        (
            (post (unwrap! (map-get? posts post-id) err-post-not-found))
            (access-key {post-id: post-id, reader: tx-sender})
        )
        (asserts! (> (get paywall-amount post) u0) err-insufficient-payment)
        
        (try! (stx-transfer? (get paywall-amount post) tx-sender (get author post)))
        
        (map-set posts post-id (merge post {
            earnings: (+ (get earnings post) (get paywall-amount post))
        }))
        (map-set post-access access-key true)
        (ok true)
    )
)

(define-public (like-post (post-id uint))
    (let ((post (unwrap! (map-get? posts post-id) err-post-not-found)))
        (map-set posts post-id (merge post {
            likes: (+ (get likes post) u1)
        }))
        (ok true)
    )
)

(define-public (follow-author (author principal))
    (begin
        (map-set author-followers {author: author, follower: tx-sender} true)
        (ok true)
    )
)

(define-public (update-post-paywall (post-id uint) (new-amount uint))
    (let ((post (unwrap! (map-get? posts post-id) err-post-not-found)))
        (asserts! (is-eq tx-sender (get author post)) err-not-author)
        (map-set posts post-id (merge post {
            paywall-amount: new-amount
        }))
        (ok true)
    )
)

(define-read-only (get-post (post-id uint))
    (map-get? posts post-id)
)

(define-read-only (has-access (post-id uint) (reader principal))
    (match (map-get? posts post-id)
        post (or 
                (is-eq reader (get author post))
                (is-eq (get paywall-amount post) u0)
                (default-to false (map-get? post-access {post-id: post-id, reader: reader})))
        false
    )
)

(define-read-only (is-following (author principal) (follower principal))
    (default-to false (map-get? author-followers {author: author, follower: follower}))
)

```
