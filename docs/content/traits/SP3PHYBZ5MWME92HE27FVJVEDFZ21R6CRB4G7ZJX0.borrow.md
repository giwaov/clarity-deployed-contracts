---
title: "Trait borrow"
draft: true
---
```
;; Contract: Lending System
;; Description: Handles checking out books.

(define-public (borrow-book (book-id uint))
    (let
        (
            (book (unwrap! (contract-call? .books get-book book-id) (err u404)))
        )
        ;; Check if available
        (asserts! (get is-available book) (err u403))
        
        ;; Mark as unavailable in catalog
        (as-contract (contract-call? .books set-availability book-id false))
    )
)

(define-public (return-book (book-id uint))
    (begin
        ;; Mark as available again
        (as-contract (contract-call? .books set-availability book-id true))
    )
)
```
