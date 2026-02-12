---
title: "Trait username-registry-v5"
draft: true
---
```
;; Username Registry Contract
;; A simple on-chain username registration system

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ALREADY_REGISTERED (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_NOT_OWNER (err u103))
(define-constant ERR_INVALID_USERNAME (err u104))

;; Data Maps
;; Maps usernames to their owners
(define-map usernames 
    { name: (string-ascii 64) } 
    { owner: principal }
)

;; Maps principals to their registered usernames
(define-map user-names 
    { owner: principal } 
    { name: (string-ascii 64) }
)

;; Registration counter for stats
(define-data-var total-registrations uint u0)

;; Read-only functions

;; Get the owner of a username
(define-read-only (get-owner (name (string-ascii 64)))
    (ok (get owner (map-get? usernames { name: name })))
)

;; Get the username for an address
(define-read-only (get-name (owner principal))
    (ok (get name (map-get? user-names { owner: owner })))
)

;; Check if a username is available
(define-read-only (is-available (name (string-ascii 64)))
    (ok (is-none (map-get? usernames { name: name })))
)

;; Get total registrations
(define-read-only (get-total-registrations)
    (ok (var-get total-registrations))
)

;; Private functions

;; Validate username (alphanumeric and underscores only, 3-64 chars)
(define-private (is-valid-username (name (string-ascii 64)))
    (let ((name-length (len name)))
        (and (>= name-length u3) (<= name-length u64))
    )
)

;; Public functions

;; Register a new username
(define-public (register (name (string-ascii 64)))
    (begin
        ;; Check if username is valid
        (asserts! (is-valid-username name) ERR_INVALID_USERNAME)
        
        ;; Check if username is available
        (asserts! (is-none (map-get? usernames { name: name })) ERR_ALREADY_REGISTERED)
        
        ;; Check if user already has a username
        (asserts! (is-none (map-get? user-names { owner: tx-sender })) ERR_ALREADY_REGISTERED)
        
        ;; Register the username
        (map-set usernames { name: name } { owner: tx-sender })
        (map-set user-names { owner: tx-sender } { name: name })
        
        ;; Increment counter
        (var-set total-registrations (+ (var-get total-registrations) u1))
        
        (ok true)
    )
)

;; Release your username
(define-public (release (name (string-ascii 64)))
    (let ((current-owner (map-get? usernames { name: name })))
        ;; Check if username exists
        (asserts! (is-some current-owner) ERR_NOT_FOUND)
        
        ;; Check if caller owns this username
        (asserts! (is-eq tx-sender (get owner (unwrap-panic current-owner))) ERR_NOT_OWNER)
        
        ;; Remove the username
        (map-delete usernames { name: name })
        (map-delete user-names { owner: tx-sender })
        
        (ok true)
    )
)

;; Transfer username to another address
(define-public (transfer (name (string-ascii 64)) (new-owner principal))
    (let ((current-owner (map-get? usernames { name: name })))
        ;; Check if username exists
        (asserts! (is-some current-owner) ERR_NOT_FOUND)
        
        ;; Check if caller owns this username
        (asserts! (is-eq tx-sender (get owner (unwrap-panic current-owner))) ERR_NOT_OWNER)
        
        ;; Check if new owner doesn't already have a username
        (asserts! (is-none (map-get? user-names { owner: new-owner })) ERR_ALREADY_REGISTERED)
        
        ;; Transfer the username
        (map-set usernames { name: name } { owner: new-owner })
        (map-delete user-names { owner: tx-sender })
        (map-set user-names { owner: new-owner } { name: name })
        
        (ok true)
    )
)

```
