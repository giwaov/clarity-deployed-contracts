---
title: "Trait whitelist"
draft: true
---
```
;; whitelist.clar
;; User whitelist with tiers and referrals

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-ADMIN (err u101))
(define-constant ERR-ALREADY-WHITELISTED (err u102))
(define-constant ERR-NOT-WHITELISTED (err u103))
(define-constant ERR-INVALID-TIER (err u104))

;; Tiers
(define-constant TIER-NONE u0)
(define-constant TIER-PLATINUM u4)

;; Data Variables
(define-data-var total-whitelisted uint u0)

;; Maps
(define-map admins principal bool)

(define-map whitelist principal 
  {
    tier: uint,
    added-at: uint,
    expiry: uint,
    added-by: principal,
    referrer: (optional principal),
    referral-count: uint,
    active: bool
  }
)

(define-map tier-counts uint uint)

;; Authorization
(define-read-only (is-owner (addr principal))
  (is-eq addr CONTRACT-OWNER)
)

(define-read-only (is-admin (addr principal))
  (default-to (is-owner addr) (map-get? admins addr))
)

;; Public Functions
(define-public (add-admin (new-admin principal))
  (begin
    (asserts! (not (is-eq new-admin tx-sender)) (err u106))
    (ok (map-set admins new-admin true))
  )
)

(define-public (add-user (user principal) (tier uint) (duration-days uint) (referrer (optional principal)))
  (let (
    (expiry (if (> duration-days u0) 
                (+ stacks-block-time (* duration-days u86400)) 
                u0))
    (current-tier-count (default-to u0 (map-get? tier-counts tier)))
  )
    (begin
      (asserts! (not (is-whitelisted-internal user)) ERR-ALREADY-WHITELISTED)
      (asserts! (and (> tier TIER-NONE) (<= tier TIER-PLATINUM)) ERR-INVALID-TIER)
      (asserts! (match referrer ref (not (is-eq ref user)) true) (err u107))
      
      (map-set whitelist user {
        tier: tier,
        added-at: stacks-block-time,
        expiry: expiry,
        added-by: tx-sender,
        referrer: referrer,
        referral-count: u0,
        active: true
      })
      
      (map-set tier-counts tier (+ current-tier-count u1))
      (var-set total-whitelisted (+ (var-get total-whitelisted) u1))
      
      ;; Handle referral
      (match referrer
        ref-addr (if (is-whitelisted-internal ref-addr)
                    (update-referral-count ref-addr)
                    true)
        true
      )
      
      (ok true)
    )
  )
)

(define-public (remove-user (user principal))
  (let ((entry (unwrap! (map-get? whitelist user) ERR-NOT-WHITELISTED)))
    (begin
      (asserts! (get active entry) ERR-NOT-WHITELISTED)
      
      (map-set whitelist user (merge entry { active: false }))
      (map-set tier-counts (get tier entry) (- (default-to u0 (map-get? tier-counts (get tier entry))) u1))
      (var-set total-whitelisted (- (var-get total-whitelisted) u1))
      (ok true)
    )
  )
)

(define-public (upgrade-tier (user principal) (new-tier uint))
  (let ((entry (unwrap! (map-get? whitelist user) ERR-NOT-WHITELISTED)))
    (begin
      (asserts! (get active entry) ERR-NOT-WHITELISTED)
      (asserts! (> new-tier (get tier entry)) ERR-INVALID-TIER)
      (asserts! (<= new-tier TIER-PLATINUM) ERR-INVALID-TIER)
      
      (map-set tier-counts (get tier entry) (- (default-to u0 (map-get? tier-counts (get tier entry))) u1))
      (map-set tier-counts new-tier (+ (default-to u0 (map-get? tier-counts new-tier)) u1))
      (map-set whitelist user (merge entry { tier: new-tier }))
      (ok true)
    )
   )
)


(define-private (update-referral-count (referrer principal))
  (let ((entry (unwrap-panic (map-get? whitelist referrer))))
    (begin
      (map-set whitelist referrer (merge entry { referral-count: (+ (get referral-count entry) u1) }))
      ;; In a real contract, we would add to a list, but Clarity lists have fixed max size
      true
    )
  )
)





;; Read-only
(define-read-only (is-whitelisted (user principal))
  (is-whitelisted-internal user)
)

(define-private (is-whitelisted-internal (user principal))
  (match (map-get? whitelist user)
    entry (and 
            (get active entry) 
            (or (is-eq (get expiry entry) u0) (< stacks-block-time (get expiry entry))))
    false
  )
)

```
