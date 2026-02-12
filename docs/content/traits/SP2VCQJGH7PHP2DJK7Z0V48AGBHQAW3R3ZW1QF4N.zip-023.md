---
title: "Trait zip-023"
draft: true
---
```
(define-data-var executed bool false)
(define-constant deployer tx-sender)

(define-constant helper-addr-before 'SP1A27KFY4XERQCCRCARCYD1CC5N7M6688BSYADJ7.v1-transfer)
(define-constant helper-addr-after 'SP1A27KFY4XERQCCRCARCYD1CC5N7M6688BSYADJ7.v0-transfer)


(define-public (execute (sender principal))
  (begin
    (asserts! (not (var-get executed)) (err u10))
    (asserts! (is-eq contract-caller 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zest-governance) (err u11))

    ;; permissions
    (try! (contract-call? 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-borrow-v2-4 set-approved-contract helper-addr-before false))
    (try! (contract-call? 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-borrow-v2-4 set-approved-contract helper-addr-after true))

    (try! (contract-call? 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.incentives-v2-2 set-approved-contract helper-addr-before false))
    (try! (contract-call? 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.incentives-v2-2 set-approved-contract helper-addr-after true))


    (var-set executed true)
    (ok true)
  )
)

(define-public (disable)
  (begin
    (asserts! (is-eq deployer tx-sender) (err u11))
    (ok (var-set executed true))
  )
)

(define-read-only (can-execute)
  (begin
    (asserts! (not (var-get executed)) (err u10))
    (ok (not (var-get executed)))
  )
)

```
