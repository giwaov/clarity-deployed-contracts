---
title: "Trait sBTC-ChainIPProtect"
draft: true
---
```
;; Smart Contract on Intellectual Property Protection

;; Define error codes
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INVALID-HASH-LENGTH (err u1001))
(define-constant ERR-HASH-ALL-ZEROS (err u1002))
(define-constant ERR-HASH-ALREADY-REGISTERED (err u1003))
(define-constant ERR-IP-NOT-FOUND (err u1004))
(define-constant ERR-INVALID-IP-ID (err u1005))
(define-constant ERR-IP-ID-OUT-OF-RANGE (err u1006))
(define-constant ERR-IP-EXPIRED (err u1007))
(define-constant ERR-INVALID-EXPIRATION (err u1008))
(define-constant ERR-NO-EXPIRATION-SET (err u1009))

;; Define the contract
(define-data-var owner principal tx-sender)

;; Define a map to store IP registrations
(define-map ip-registrations
  { ip-id: uint }
  { owner: principal, timestamp: uint, hash: (buff 32), expiration: (optional uint) }
)

;; Define a map to track registered hashes
(define-map registered-hashes
  { hash: (buff 32) }
  { ip-id: uint }
)

;; Define a counter for IP IDs
(define-data-var ip-counter uint u0)

;; Function to register new IP
(define-public (register-ip (ip-hash (buff 32)) (expiration-block (optional uint)))
  (let
    (
      (new-id (+ (var-get ip-counter) u1))
      (current-block stacks-block-height)
    )
    ;; Perform input validation
    ;; Perform input validation
    (asserts! (is-eq (len ip-hash) u32) ERR-INVALID-HASH-LENGTH)
    (asserts! (not (is-eq ip-hash 0x0000000000000000000000000000000000000000000000000000000000000000)) ERR-HASH-ALL-ZEROS)
    (asserts! (is-none (map-get? registered-hashes { hash: ip-hash })) ERR-HASH-ALREADY-REGISTERED)
    ;; Check expiration validity
    (asserts! (match expiration-block
                expiration (> expiration current-block)
                true
              )
              ERR-INVALID-EXPIRATION)
    ;; Register the IP
    (map-set ip-registrations
      { ip-id: new-id }
      { owner: tx-sender, timestamp: current-block, hash: ip-hash, expiration: expiration-block }
    )
    ;; Track the registered hash
    (map-set registered-hashes
      { hash: ip-hash }
      { ip-id: new-id }
    )
    (var-set ip-counter new-id)
    (ok new-id)
  )
)

;; Function to check IP ownership
(define-read-only (check-ip-ownership (ip-id uint))
  (let
    (
      (ip-data (map-get? ip-registrations { ip-id: ip-id }))
    )
    (if (is-some ip-data)
      (ok (get owner (unwrap-panic ip-data)))
      
      ERR-IP-NOT-FOUND
    )
  )
)

;; Function to verify IP hash
(define-read-only (verify-ip-hash (ip-id uint) (hash-to-verify (buff 32)))
  (let
    (
      (ip-data (map-get? ip-registrations { ip-id: ip-id }))
    )
    (if (is-some ip-data)
      (ok (is-eq (get hash (unwrap-panic ip-data)) hash-to-verify))
      ERR-IP-NOT-FOUND
    )
  )
)

;; Function to transfer IP ownership
(define-public (transfer-ip (ip-id uint) (new-owner principal))
  (let
    (
      (current-ip-counter (var-get ip-counter))
    )
    ;; Perform input validation
    (asserts! (<= ip-id current-ip-counter) ERR-IP-ID-OUT-OF-RANGE)
    (asserts! (> ip-id u0) ERR-INVALID-IP-ID)
    
    (let
      (
        (ip-data (map-get? ip-registrations { ip-id: ip-id }))
      )
      (asserts! (is-some ip-data) ERR-IP-NOT-FOUND)
      (let
        (
          (unwrapped-ip-data (unwrap-panic ip-data))
        )
        (asserts! (is-eq tx-sender (get owner unwrapped-ip-data)) ERR-NOT-AUTHORIZED)
        (map-set ip-registrations
          { ip-id: ip-id }
          (merge unwrapped-ip-data { owner: new-owner })
        )
        (ok true)
      )
    )
  )
)



;; Function to check if a hash is already registered
(define-read-only (is-hash-registered (ip-hash (buff 32)))
  (is-some (map-get? registered-hashes { hash: ip-hash }))
)

;; Smart Contract on Intellectual Property Protection with Expiration Date, Corrected Safety Checks, IP Update Functionality, Owner Verification, and Corrected Expiration Extension

;; function to extend IP registration
(define-public (extend-ip-registration (ip-id uint) (new-expiration uint))
  (let
    (
      (current-ip-counter (var-get ip-counter))
      (current-block stacks-block-height)
    )
    ;; Perform input validation
    (asserts! (<= ip-id current-ip-counter) ERR-IP-ID-OUT-OF-RANGE)
    (asserts! (> ip-id u0) ERR-INVALID-IP-ID)
    (asserts! (> new-expiration current-block) ERR-INVALID-EXPIRATION)

    (let
      (
        (ip-data (map-get? ip-registrations { ip-id: ip-id }))
      )
      (asserts! (is-some ip-data) ERR-IP-NOT-FOUND)
      (let
        (
          (unwrapped-ip-data (unwrap-panic ip-data))
        )
        (asserts! (is-eq tx-sender (get owner unwrapped-ip-data)) ERR-NOT-AUTHORIZED)
        (match (get expiration unwrapped-ip-data)
          current-expiration (if (> new-expiration current-expiration)
                                (begin
                                  (map-set ip-registrations
                                    { ip-id: ip-id }
                                    (merge unwrapped-ip-data { expiration: (some new-expiration) })
                                  )
                                  (ok true)
                                )
                                ERR-INVALID-EXPIRATION)
          (begin
            (map-set ip-registrations
              { ip-id: ip-id }
              (merge unwrapped-ip-data { expiration: (some new-expiration) })
            )
            (ok true)
          )
        )
      )
    )
  )
)

;; Function to update IP metadata (hash)
(define-public (update-ip-metadata (ip-id uint) (new-hash (buff 32)))
  (let
    (
      (current-ip-counter (var-get ip-counter))
    )
    ;; Perform input validation
    (asserts! (<= ip-id current-ip-counter) ERR-IP-ID-OUT-OF-RANGE)
    (asserts! (> ip-id u0) ERR-INVALID-IP-ID)
    (asserts! (is-eq (len new-hash) u32) ERR-INVALID-HASH-LENGTH)
    (asserts! (not (is-eq new-hash 0x0000000000000000000000000000000000000000000000000000000000000000)) ERR-HASH-ALL-ZEROS)

    (let
      (
        (ip-data (map-get? ip-registrations { ip-id: ip-id }))
      )
      (asserts! (is-some ip-data) ERR-IP-NOT-FOUND)
      (let
        (
          (unwrapped-ip-data (unwrap-panic ip-data))
          (current-block stacks-block-height)
        )
        ;; Check if the caller is the current owner
        (asserts! (is-eq tx-sender (get owner unwrapped-ip-data)) ERR-NOT-AUTHORIZED)
        ;; Check if the IP has not expired
        (asserts! (or
                    (is-none (get expiration unwrapped-ip-data))
                    (< current-block (unwrap-panic (get expiration unwrapped-ip-data)))
                  )
                  ERR-IP-EXPIRED
        )
        ;; Remove the old hash from registered-hashes
        (map-delete registered-hashes { hash: (get hash unwrapped-ip-data) })
        ;; Update the IP registration with the new hash
        (map-set ip-registrations
          { ip-id: ip-id }
          (merge unwrapped-ip-data { hash: new-hash })
        )
        ;; Add the new hash to registered-hashes
        (map-set registered-hashes
          { hash: new-hash }
          { ip-id: ip-id }
        )
        (ok true)
      )
    )
  )
)

```
