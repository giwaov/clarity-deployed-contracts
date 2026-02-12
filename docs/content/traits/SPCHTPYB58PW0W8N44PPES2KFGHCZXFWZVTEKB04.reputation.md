---
title: "Trait reputation"
draft: true
---
```
;; Reputation System Contract
;; On-chain reputation and reviews

(define-constant contract-owner tx-sender)
(define-constant err-already-reviewed (err u100))
(define-constant err-self-review (err u101))
(define-constant err-invalid-rating (err u102))

(define-map reputation
    principal
    {
        total-score: uint,
        review-count: uint,
        positive-reviews: uint,
        negative-reviews: uint
    }
)

(define-map reviews
    {reviewer: principal, reviewee: principal}
    {
        rating: uint,
        comment: (string-utf8 500),
        timestamp: uint
    }
)

;; Submit a review
(define-public (submit-review (reviewee principal) (rating uint) (comment (string-utf8 500)))
    (let
        (
            (review-key {reviewer: tx-sender, reviewee: reviewee})
            (current-rep (default-to 
                {total-score: u0, review-count: u0, positive-reviews: u0, negative-reviews: u0}
                (map-get? reputation reviewee)))
        )
        (asserts! (not (is-eq tx-sender reviewee)) err-self-review)
        (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-rating)
        (asserts! (is-none (map-get? reviews review-key)) err-already-reviewed)
        
        (map-set reviews review-key {
            rating: rating,
            comment: comment,
            timestamp: block-height
        })
        
        (map-set reputation reviewee {
            total-score: (+ (get total-score current-rep) rating),
            review-count: (+ (get review-count current-rep) u1),
            positive-reviews: (if (>= rating u4) 
                                  (+ (get positive-reviews current-rep) u1)
                                  (get positive-reviews current-rep)),
            negative-reviews: (if (<= rating u2)
                                  (+ (get negative-reviews current-rep) u1)
                                  (get negative-reviews current-rep))
        })
        
        (ok true)
    )
)

;; Update existing review
(define-public (update-review (reviewee principal) (new-rating uint) (new-comment (string-utf8 500)))
    (let
        (
            (review-key {reviewer: tx-sender, reviewee: reviewee})
            (old-review (unwrap! (map-get? reviews review-key) err-already-reviewed))
            (current-rep (unwrap! (map-get? reputation reviewee) err-already-reviewed))
            (old-rating (get rating old-review))
        )
        (asserts! (and (>= new-rating u1) (<= new-rating u5)) err-invalid-rating)
        
        (map-set reviews review-key {
            rating: new-rating,
            comment: new-comment,
            timestamp: block-height
        })
        
        ;; Adjust reputation scores
        (map-set reputation reviewee {
            total-score: (+ (- (get total-score current-rep) old-rating) new-rating),
            review-count: (get review-count current-rep),
            positive-reviews: (+ (- (get positive-reviews current-rep) 
                                   (if (>= old-rating u4) u1 u0))
                                (if (>= new-rating u4) u1 u0)),
            negative-reviews: (+ (- (get negative-reviews current-rep)
                                   (if (<= old-rating u2) u1 u0))
                                (if (<= new-rating u2) u1 u0))
        })
        
        (ok true)
    )
)

;; Get average rating
(define-read-only (get-average-rating (user principal))
    (match (map-get? reputation user)
        rep (if (> (get review-count rep) u0)
                (some (/ (* (get total-score rep) u100) (get review-count rep)))
                none)
        none
    )
)

;; Get reputation
(define-read-only (get-reputation (user principal))
    (map-get? reputation user)
)

;; Get specific review
(define-read-only (get-review (reviewer principal) (reviewee principal))
    (map-get? reviews {reviewer: reviewer, reviewee: reviewee})
)

;; Calculate reputation score (0-100)
(define-read-only (get-reputation-score (user principal))
    (match (map-get? reputation user)
        rep (let
                (
                    (avg-rating (/ (* (get total-score rep) u100) 
                                  (if (> (get review-count rep) u0) 
                                      (get review-count rep) 
                                      u1)))
                    (positive-ratio (if (> (get review-count rep) u0)
                                       (/ (* (get positive-reviews rep) u100) (get review-count rep))
                                       u0))
                )
                (* (/ (+ avg-rating positive-ratio) u2) u2)
            )
        u0
    )
)

```
