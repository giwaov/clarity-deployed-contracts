---
title: "Trait counterContract41"
draft: true
---
```
;; Counter Smart Contract
;; Clarity Version: 4
;; Epoch: 3.0

;; -------------------------
;; ERROR CODES
;; -------------------------
(define-constant ERR_UNAUTHORIZED (err u100))

;; -------------------------
;; STORAGE
;; -------------------------
(define-data-var counter int 0)
(define-data-var owner principal tx-sender)

;; -------------------------
;; PRIVATE HELPERS
;; -------------------------
(define-private (assert-is-owner)
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (ok true)
  )
)

;; -------------------------
;; PUBLIC FUNCTIONS
;; -------------------------

;; Increment the counter
(define-public (increment)
  (let ((authorized (try! (assert-is-owner))))
    (var-set counter (+ (var-get counter) 1))
    (ok (var-get counter))
  )
)

;; Decrement the counter
(define-public (decrement)
  (let ((authorized (try! (assert-is-owner))))
    (var-set counter (- (var-get counter) 1))
    (ok (var-get counter))
  )
)

;; Reset counter to 0
(define-public (reset)
  (let ((authorized (try! (assert-is-owner))))
    (var-set counter 0)
    (ok 0)
  )
)

;; Set counter to a specific value
(define-public (set-counter (value int))
  (let ((authorized (try! (assert-is-owner))))
    (var-set counter value)
    (ok value)
  )
)

;; Transfer ownership
(define-public (transfer-ownership (new-owner principal))
  (let ((authorized (try! (assert-is-owner))))
    (var-set owner new-owner)
    (ok new-owner)
  )
)

;; -------------------------
;; READ-ONLY FUNCTIONS
;; -------------------------

(define-read-only (get-counter)
  (var-get counter)
)

(define-read-only (get-owner)
  (var-get owner)
)

```
