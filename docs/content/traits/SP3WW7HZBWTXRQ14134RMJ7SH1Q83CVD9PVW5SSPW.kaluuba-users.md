---
title: "Trait kaluuba-users"
draft: true
---
```
;; title: kaluuba-users
;; version: 1.0.0
;; summary: User management contract for Kaluuba
;; description: Handles username registration, mapping usernames to wallet addresses

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-username-taken (err u101))
(define-constant err-username-not-found (err u102))
(define-constant err-invalid-username (err u103))
(define-constant err-unauthorized (err u104))
(define-constant err-user-inactive (err u105))

(define-constant min-username-length u3)
(define-constant max-username-length u20)

;; Data Variables
(define-data-var total-users uint u0)

;; Data Maps
(define-map users
  { username: (string-ascii 20) }
  {
    address: principal,
    registered-at: uint,
    is-active: bool,
    verified: bool
  }
)

(define-map user-addresses
  { address: principal }
  { username: (string-ascii 20) }
)

;; Private Functions
(define-private (is-valid-username (username (string-ascii 20)))
  (let ((len (len username)))
    (and 
      (>= len min-username-length)
      (<= len max-username-length)
    )
  )
)

;; Read-only Functions
(define-read-only (get-user-by-username (username (string-ascii 20)))
  (map-get? users { username: username })
)

(define-read-only (get-username-by-address (address principal))
  (map-get? user-addresses { address: address })
)

(define-read-only (is-username-available (username (string-ascii 20)))
  (is-none (map-get? users { username: username }))
)

(define-read-only (get-total-users)
  (ok (var-get total-users))
)

(define-read-only (get-user-address (username (string-ascii 20)))
  (match (map-get? users { username: username })
    user-data (ok (get address user-data))
    err-username-not-found
  )
)

;; Public Functions
(define-public (register-username (username (string-ascii 20)))
  (let
    (
      (caller tx-sender)
      (existing-username (map-get? user-addresses { address: caller }))
    )
    ;; Validate username format
    (asserts! (is-valid-username username) err-invalid-username)
    
    ;; Check if username is available
    (asserts! (is-username-available username) err-username-taken)
    
    ;; Check if user already has a username
    (asserts! (is-none existing-username) err-username-taken)
    
    ;; Register the username
    (map-set users
      { username: username }
      {
        address: caller,
        registered-at: stacks-block-height,
        is-active: true,
        verified: false
      }
    )
    
    ;; Map address to username
    (map-set user-addresses
      { address: caller }
      { username: username }
    )
    
    ;; Increment total users
    (var-set total-users (+ (var-get total-users) u1))
    
    (ok username)
  )
)

(define-public (deactivate-user (username (string-ascii 20)))
  (let
    (
      (user-data (unwrap! (map-get? users { username: username }) err-username-not-found))
      (user-address (get address user-data))
    )
    ;; Only the user or contract owner can deactivate
    (asserts! (or (is-eq tx-sender user-address) (is-eq tx-sender contract-owner)) err-unauthorized)
    
    ;; Update user status
    (map-set users
      { username: username }
      (merge user-data { is-active: false })
    )
    
    (ok true)
  )
)

(define-public (reactivate-user (username (string-ascii 20)))
  (let
    (
      (user-data (unwrap! (map-get? users { username: username }) err-username-not-found))
      (user-address (get address user-data))
    )
    ;; Only the user can reactivate
    (asserts! (is-eq tx-sender user-address) err-unauthorized)
    
    ;; Update user status
    (map-set users
      { username: username }
      (merge user-data { is-active: true })
    )
    
    (ok true)
  )
)

(define-public (verify-user (username (string-ascii 20)))
  (let
    (
      (user-data (unwrap! (map-get? users { username: username }) err-username-not-found))
    )
    ;; Only contract owner can verify users
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    ;; Update verification status
    (map-set users
      { username: username }
      (merge user-data { verified: true })
    )
    
    (ok true)
  )
)

```
