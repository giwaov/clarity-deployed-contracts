---
title: "Trait copper-ft-v0"
draft: true
---
```
;; Play at https://ata-game.space

(impl-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)
(impl-trait 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-ft-trait-v0.ata-ft-trait-v0)

;; ERRORS
(define-constant ERR_UNAUTHORIZED (err u4011))
(define-constant ERR_ADMIN_ONLY (err u4012))
(define-constant ERR_NOT_TOKEN_OWNER (err u4013))

(define-fungible-token ata-copper)

(define-data-var token-uri (optional (string-utf8 256)) (some u"https://ata-game.space/v0/token-metadata/copper"))

(define-map authorized-to-mint-contracts principal bool)
(map-insert authorized-to-mint-contracts .copper-v1 true)

(define-private (is-authorized-to-mint)
  (if (is-eq (map-get? authorized-to-mint-contracts contract-caller) (some true))
    (ok true)
    ERR_UNAUTHORIZED
  )
)

(define-public (mint (amount uint))
  (begin
    (try! (is-authorized-to-mint))
    (ft-mint? ata-copper amount tx-sender)
  )
)

(define-public (burn (amount uint))
  (ft-burn? ata-copper amount tx-sender)
)

(define-public (transfer
  (amount uint)
  (sender principal)
  (recipient principal)
  (memo (optional (buff 34)))
)
  (begin
    (asserts! (is-eq tx-sender sender) ERR_NOT_TOKEN_OWNER)
    (try! (ft-transfer? ata-copper amount tx-sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)

(define-read-only (get-name) (ok "ATA Copper"))

(define-read-only (get-symbol) (ok "aCOP"))

(define-read-only (get-decimals) (ok u0))

(define-read-only (get-balance (who principal)) (ok (ft-get-balance ata-copper who)))

(define-read-only (get-total-supply) (ok (ft-get-supply ata-copper)))

(define-read-only (get-token-uri) (ok (var-get token-uri)))

;; ADMIN
(define-public (add-authorized-to-mint-contract (contract principal))
  (begin
    (try! (contract-call? 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-admin-v0 is-admin))
    (ok (map-insert authorized-to-mint-contracts contract true))
  )
)

(define-public (remove-authorized-to-mint-contract (contract principal))
  (begin
    (try! (contract-call? 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-admin-v0 is-admin))
    (ok (map-delete authorized-to-mint-contracts contract))
  )
)

(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
  (begin
    (try! (contract-call? 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-admin-v0 is-admin))
    (ok (var-set token-uri new-uri))
  )
)

```
