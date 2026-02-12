---
title: "Trait registry"
draft: true
---
```
;; registry.clar
;; Global name and metadata registry

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-VERIFIER (err u101))
(define-constant ERR-NAME-TAKEN (err u102))
(define-constant ERR-NAME-NOT-FOUND (err u103))
(define-constant ERR-NOT-NAME-OWNER (err u104))
(define-constant ERR-EMPTY-NAME (err u105))
(define-constant ERR-NAME-SUSPENDED (err u106))

;; Status
(define-constant STATUS-PENDING u0)
(define-constant STATUS-VERIFIED u1)
(define-constant STATUS-SUSPENDED u2)

;; Data Variables
(define-data-var total-registrations uint u0)

;; Maps
(define-map registry (string-ascii 64)
  {
    owner: principal,
    metadata: (string-ascii 256),
    category: uint,
    status: uint,
    registered-at: uint,
    last-updated: uint,
    verified-by: (optional principal)
  }
)

(define-map verifiers principal bool)

;; Public Functions
(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (not (is-eq verifier tx-sender)) (err u110))
    (ok (map-set verifiers verifier true))
  )
)

(define-public (register (name (string-ascii 64)) (metadata (string-ascii 256)) (category uint))
  (begin
    (asserts! (> (len name) u0) ERR-EMPTY-NAME)
    (asserts! (> (len metadata) u0) (err u108))
    (asserts! (<= category u10) (err u109))
    (asserts! (is-none (map-get? registry name)) ERR-NAME-TAKEN)
    
    (map-set registry name {
      owner: tx-sender,
      metadata: metadata,
      category: category,
      status: STATUS-PENDING,
      registered-at: stacks-block-time,
      last-updated: stacks-block-time,
      verified-by: none
    })
    
    (var-set total-registrations (+ (var-get total-registrations) u1))
    (ok true)
  )
)

(define-public (update-metadata (name (string-ascii 64)) (metadata (string-ascii 256)))
  (let ((reg (unwrap! (map-get? registry name) ERR-NAME-NOT-FOUND)))
    (begin
      (asserts! (is-eq (get owner reg) tx-sender) ERR-NOT-NAME-OWNER)
      (asserts! (not (is-eq (get status reg) STATUS-SUSPENDED)) ERR-NAME-SUSPENDED)
      
      (map-set registry name (merge reg { 
        metadata: metadata,
        last-updated: stacks-block-time
      }))
      (ok true)
    )
  )
)

(define-public (transfer (name (string-ascii 64)) (new-owner principal))
  (let ((reg (unwrap! (map-get? registry name) ERR-NAME-NOT-FOUND)))
    (begin
      (asserts! (is-eq (get owner reg) tx-sender) ERR-NOT-NAME-OWNER)
      (asserts! (not (is-eq (get status reg) STATUS-SUSPENDED)) ERR-NAME-SUSPENDED)
      
      (map-set registry name (merge reg { 
        owner: new-owner,
        last-updated: stacks-block-time
      }))
      (ok true)
    )
  )
)

(define-public (verify (name (string-ascii 64)))
  (let ((reg (unwrap! (map-get? registry name) ERR-NAME-NOT-FOUND)))
    (begin
      (asserts! (> (len name) u0) (err u111))
      (map-set registry name (merge reg { 
        status: STATUS-VERIFIED,
        verified-by: (some tx-sender),
        last-updated: stacks-block-time
      }))
      (ok true)
    )
  )
)

;; Read-only
(define-read-only (get-registration (name (string-ascii 64)))
  (map-get? registry name)
)

```
