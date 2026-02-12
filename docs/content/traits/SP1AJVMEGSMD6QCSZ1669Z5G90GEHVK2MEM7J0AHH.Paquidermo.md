---
title: "Trait Paquidermo"
draft: true
---
```
;; =====================================================
;; SANDBOX-WORKING CONTRACT Paquidermo (Explorer-style)
;; =====================================================

;; constants
(define-constant sender tx-sender)

;; tokens
(define-fungible-token sandbox-token)
(define-non-fungible-token sandbox-nft uint)

;; mint & transfer AT DEPLOY (Explorer allows this)
(ft-mint? sandbox-token u10 sender)
(nft-mint? sandbox-nft u1 sender)

;; event
(define-public (emit-event)
  (begin
    (print "Sandbox deploy event")
    (ok u1)
  )
)

(begin (emit-event))

;; storage
(define-map store
  { key: (buff 32) }
  { value: (buff 32) }
)

(define-public (set-value (key (buff 32)) (value (buff 32)))
  (begin
    (map-set store { key: key } { value: value })
    (ok u1)
  )
)

(define-public (get-value (key (buff 32)))
  (match (map-get? store { key: key })
    entry (ok (get value entry))
    (err u0)
  )
)
```
