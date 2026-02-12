---
title: "Trait commission-ft"
draft: true
---
```
;; This contract use the SIP-010 community-standard Fungible Token trait
(use-trait sip-010-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait) ;; 

;; SIP-010 transfer implementation
(define-private (transfer-ft (token-contract <sip-010-trait>) (amount uint) (sender principal) (recipient principal))
  (contract-call? token-contract transfer amount sender recipient none)
)
;; define the contract owner
(define-data-var CONTRACT_OWNER (optional principal) (some tx-sender))
(define-data-var TREASURY principal .vault)
(define-data-var COMMISSION uint u200)

(define-constant ERR_OWNER_ONLY (err u1000))
(define-constant ERR_OUT_OF_RANGE (err u1001))

;; helper to check the contract caller is the owner
(define-private (is-admin)
  (let (
    (owner (var-get CONTRACT_OWNER))
  )
  (if (is-some owner)
    (is-eq contract-caller (unwrap-panic owner))
    false
  )
  )
)

;; Admin function to change the owner address
(define-public (admin-change-owner (address principal)) 
  (begin 
    ;; Only the contract owner can start the mint.
    (asserts! (is-admin) ERR_OWNER_ONLY)
    (var-set CONTRACT_OWNER (some address))
    (print {
        topic: "new owner",
        owner: address,
    })
    (ok true)
  )
)

;; Admin function to renounce the ownership
(define-public (admin-renounce-ownership) 
  (begin 
    ;; Only the contract owner can start the mint.
    (asserts! (is-admin) ERR_OWNER_ONLY)
    (var-set CONTRACT_OWNER none)
    (print {
        topic: "ownership renounced",
        owner: none,
    })
    (ok true)
  )
)

;; Admin function to change the commission fee
(define-public (admin-change-commission (fee uint)) 
  (begin 
    ;; Only the contract owner can start the mint.
    (asserts! (is-admin) ERR_OWNER_ONLY)
    (asserts! (and (>= fee u100) (<= fee u1000)) ERR_OUT_OF_RANGE) ;; min 1% max 10%
    (var-set COMMISSION fee)
    (print {
        topic: "new commission",
        fee: fee,
    })
    (ok true)
  )
)

;; commission pay function
(define-public (pay (id uint) (price uint) (token <sip-010-trait>))
  (begin
    (try! (transfer-ft token (/ (* price (var-get COMMISSION)) u10000) tx-sender (var-get TREASURY)))
    (ok true)))

;; read-only to view current commission
(define-read-only (get-commission)
    (var-get COMMISSION)
)

;;read-onlt to view current treasury address
(define-read-only (get-treasury)
    (var-get TREASURY)
)
```
