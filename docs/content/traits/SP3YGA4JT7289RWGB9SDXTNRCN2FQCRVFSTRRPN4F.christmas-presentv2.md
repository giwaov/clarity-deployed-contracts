---
title: "Trait christmas-presentv2"
draft: true
---
```
;; title: christmas-present
;; version: 1.0.0
;; summary: A smart contract for creating and claiming Christmas presents
;; description: This contract allows users to create presents with STX amounts, titles, and claim passwords. Others can claim presents using the password.

;; constants
;;

;; data vars
;; Present ID counter
(define-data-var present-id-counter uint u0)

;; data maps
;; Present information: present-id -> (creator, title, amount, password-hash, claimed, claimer, created-at)
(define-map presents
  { present-id: uint }
  {
    creator: principal,
    title: (string-ascii 200),
    amount: uint,
    password-hash: (buff 20),
    claimed: bool,
    claimer: principal,
    created-at: uint
  }
)

;; public functions

;; Create a present with STX amount, title, and claim password
;; User must transfer STX to contract address BEFORE calling this function
(define-public (create-present
  (title (string-ascii 200))
  (amount uint)
  (password (string-ascii 100))
)
  (let (
    (caller tx-sender)
    (present-id (+ (var-get present-id-counter) u1))
  )
    (asserts! (> amount u0) (err u1001))
    (asserts! (> (len password) u0) (err u1003))
    (let (
      (password-buff (unwrap-panic (to-consensus-buff? password)))
      (password-hash (hash160 password-buff))
    )
      (map-set presents
        { present-id: present-id }
        {
          creator: caller,
          title: title,
          amount: amount,
          password-hash: password-hash,
          claimed: false,
          claimer: caller,
          created-at: u0
        }
      )
      (var-set present-id-counter present-id)
      (ok present-id)
    )
  )
)

;; Claim a present using the password
;; This marks the present as claimed and allows the claimer to withdraw STX
(define-public (claim-present
  (present-id uint)
  (password (string-ascii 100))
)
  (let (
    (caller tx-sender)
    (present-info (map-get? presents { present-id: present-id }))
  )
    (asserts! (is-some present-info) (err u2001))
    (let (
      (present (unwrap-panic present-info))
      (password-buff (unwrap-panic (to-consensus-buff? password)))
      (password-hash (hash160 password-buff))
    )
      (asserts! (not (get claimed present)) (err u2002))
      (asserts! (is-eq password-hash (get password-hash present)) (err u2003))
      (let (
        (updated-present {
          creator: (get creator present),
          title: (get title present),
          amount: (get amount present),
          password-hash: (get password-hash present),
          claimed: true,
          claimer: caller,
          created-at: (get created-at present)
        })
      )
        (map-set presents { present-id: present-id } updated-present)
        (ok true)
      )
    )
  )
)

;; Withdraw STX for a claimed present
;; The claimer can call this after claiming to receive the STX
(define-public (withdraw-present
  (present-id uint)
)
  (let (
    (caller tx-sender)
    (present-info (map-get? presents { present-id: present-id }))
  )
    (asserts! (is-some present-info) (err u2004))
    (let (
      (present (unwrap-panic present-info))
    )
      (asserts! (get claimed present) (err u2005))
      (asserts! (is-eq caller (get claimer present)) (err u2006))
      (try! (stx-transfer? (get amount present) tx-sender caller))
      (ok true)
    )
  )
)

;; read only functions

;; Get present by ID
(define-read-only (get-present-by-id
  (present-id uint)
)
  (map-get? presents { present-id: present-id })
)

;; Get all presents (returns up to 10 most recent presents)
;; Pass 0 to get latest, or pass a starting ID
(define-read-only (get-all-presents
  (start-from uint)
)
  (let (
    (total-presents (var-get present-id-counter))
    (start-id (if (is-eq start-from u0) 
      (if (>= total-presents u10) (- total-presents u9) u1)
      start-from))
  )
    (if (and (>= start-id u1) (<= start-id total-presents))
      (ok (list
        (map-get? presents { present-id: start-id })
        (if (>= total-presents (+ start-id u1)) (map-get? presents { present-id: (+ start-id u1) }) none)
        (if (>= total-presents (+ start-id u2)) (map-get? presents { present-id: (+ start-id u2) }) none)
        (if (>= total-presents (+ start-id u3)) (map-get? presents { present-id: (+ start-id u3) }) none)
        (if (>= total-presents (+ start-id u4)) (map-get? presents { present-id: (+ start-id u4) }) none)
        (if (>= total-presents (+ start-id u5)) (map-get? presents { present-id: (+ start-id u5) }) none)
        (if (>= total-presents (+ start-id u6)) (map-get? presents { present-id: (+ start-id u6) }) none)
        (if (>= total-presents (+ start-id u7)) (map-get? presents { present-id: (+ start-id u7) }) none)
        (if (>= total-presents (+ start-id u8)) (map-get? presents { present-id: (+ start-id u8) }) none)
        (if (>= total-presents (+ start-id u9)) (map-get? presents { present-id: (+ start-id u9) }) none)
      ))
      (err u3001)
    )
  )
)

;; Get presents created by a specific creator (returns up to 10)
(define-read-only (get-presents-by-creator
  (creator principal)
  (start-from uint)
)
  (let (
    (total-presents (var-get present-id-counter))
    (start-id (if (is-eq start-from u0) 
      (if (>= total-presents u10) (- total-presents u9) u1)
      start-from))
  )
    (if (and (>= start-id u1) (<= start-id total-presents))
      (ok (list
        (let ((p1 (map-get? presents { present-id: start-id })))
          (if (and (is-some p1) (is-eq (get creator (unwrap-panic p1)) creator)) p1 none))
        (if (>= total-presents (+ start-id u1))
          (let ((p2 (map-get? presents { present-id: (+ start-id u1) })))
            (if (and (is-some p2) (is-eq (get creator (unwrap-panic p2)) creator)) p2 none))
          none)
        (if (>= total-presents (+ start-id u2))
          (let ((p3 (map-get? presents { present-id: (+ start-id u2) })))
            (if (and (is-some p3) (is-eq (get creator (unwrap-panic p3)) creator)) p3 none))
          none)
        (if (>= total-presents (+ start-id u3))
          (let ((p4 (map-get? presents { present-id: (+ start-id u3) })))
            (if (and (is-some p4) (is-eq (get creator (unwrap-panic p4)) creator)) p4 none))
          none)
        (if (>= total-presents (+ start-id u4))
          (let ((p5 (map-get? presents { present-id: (+ start-id u4) })))
            (if (and (is-some p5) (is-eq (get creator (unwrap-panic p5)) creator)) p5 none))
          none)
        (if (>= total-presents (+ start-id u5))
          (let ((p6 (map-get? presents { present-id: (+ start-id u5) })))
            (if (and (is-some p6) (is-eq (get creator (unwrap-panic p6)) creator)) p6 none))
          none)
        (if (>= total-presents (+ start-id u6))
          (let ((p7 (map-get? presents { present-id: (+ start-id u6) })))
            (if (and (is-some p7) (is-eq (get creator (unwrap-panic p7)) creator)) p7 none))
          none)
        (if (>= total-presents (+ start-id u7))
          (let ((p8 (map-get? presents { present-id: (+ start-id u7) })))
            (if (and (is-some p8) (is-eq (get creator (unwrap-panic p8)) creator)) p8 none))
          none)
        (if (>= total-presents (+ start-id u8))
          (let ((p9 (map-get? presents { present-id: (+ start-id u8) })))
            (if (and (is-some p9) (is-eq (get creator (unwrap-panic p9)) creator)) p9 none))
          none)
        (if (>= total-presents (+ start-id u9))
          (let ((p10 (map-get? presents { present-id: (+ start-id u9) })))
            (if (and (is-some p10) (is-eq (get creator (unwrap-panic p10)) creator)) p10 none))
          none)
      ))
      (err u3002)
    )
  )
)

;; Get all claimed presents (returns up to 10)
(define-read-only (get-all-claimed-presents
  (start-from uint)
)
  (let (
    (total-presents (var-get present-id-counter))
    (start-id (if (is-eq start-from u0) 
      (if (>= total-presents u10) (- total-presents u9) u1)
      start-from))
  )
    (if (and (>= start-id u1) (<= start-id total-presents))
      (ok (list
        (let ((p1 (map-get? presents { present-id: start-id })))
          (if (and (is-some p1) (get claimed (unwrap-panic p1))) p1 none))
        (if (>= total-presents (+ start-id u1))
          (let ((p2 (map-get? presents { present-id: (+ start-id u1) })))
            (if (and (is-some p2) (get claimed (unwrap-panic p2))) p2 none))
          none)
        (if (>= total-presents (+ start-id u2))
          (let ((p3 (map-get? presents { present-id: (+ start-id u2) })))
            (if (and (is-some p3) (get claimed (unwrap-panic p3))) p3 none))
          none)
        (if (>= total-presents (+ start-id u3))
          (let ((p4 (map-get? presents { present-id: (+ start-id u3) })))
            (if (and (is-some p4) (get claimed (unwrap-panic p4))) p4 none))
          none)
        (if (>= total-presents (+ start-id u4))
          (let ((p5 (map-get? presents { present-id: (+ start-id u4) })))
            (if (and (is-some p5) (get claimed (unwrap-panic p5))) p5 none))
          none)
        (if (>= total-presents (+ start-id u5))
          (let ((p6 (map-get? presents { present-id: (+ start-id u5) })))
            (if (and (is-some p6) (get claimed (unwrap-panic p6))) p6 none))
          none)
        (if (>= total-presents (+ start-id u6))
          (let ((p7 (map-get? presents { present-id: (+ start-id u6) })))
            (if (and (is-some p7) (get claimed (unwrap-panic p7))) p7 none))
          none)
        (if (>= total-presents (+ start-id u7))
          (let ((p8 (map-get? presents { present-id: (+ start-id u7) })))
            (if (and (is-some p8) (get claimed (unwrap-panic p8))) p8 none))
          none)
        (if (>= total-presents (+ start-id u8))
          (let ((p9 (map-get? presents { present-id: (+ start-id u8) })))
            (if (and (is-some p9) (get claimed (unwrap-panic p9))) p9 none))
          none)
        (if (>= total-presents (+ start-id u9))
          (let ((p10 (map-get? presents { present-id: (+ start-id u9) })))
            (if (and (is-some p10) (get claimed (unwrap-panic p10))) p10 none))
          none)
      ))
      (err u3003)
    )
  )
)

;; Get statistics about presents
(define-read-only (get-stats)
  (ok {
    total-presents: (var-get present-id-counter)
  })
)

```
