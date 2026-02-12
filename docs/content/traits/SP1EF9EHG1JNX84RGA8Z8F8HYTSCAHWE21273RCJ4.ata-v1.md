---
title: "Trait ata-v1"
draft: true
---
```
;; Play at https://ata-game.space

;; ATA - contract manager
;; The ATA resource is similar to other resources.
;; Except that the player can only have one "factory". Called the ATA miner.
;; So the data structure is a bit different

(impl-trait 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-resource-trait-v0.ata-resource-trait-v0)

(define-data-var initial-mint uint u512)

;; CONSTANTS
(define-constant ERR_OWNER_ONLY (err u2411))
(define-constant ERR_NOT_TOKEN_OWNER (err u2412))

(define-constant ERR_NOT_REGISTERED (err u2413))

;; COSTS HANDLING
(define-data-var ata-costs uint u16)
(define-data-var cost-data-0 { base: uint, from: uint, pow: uint }
  { base: u33, from: u1, pow: u3 }
)
(define-data-var cost-data-1 { base: uint, from: uint, pow: uint }
  { base: u44, from: u3, pow: u3 }
)
(define-data-var cost-data-2 { base: uint, from: uint, pow: uint }
  { base: u55, from: u9, pow: u7 }
)
(define-data-var cost-data-3 { base: uint, from: uint, pow: uint }
  { base: u66, from: u18, pow: u10 }
)
(define-data-var cost-data-4 { base: uint, from: uint, pow: uint }
  { base: u50, from: u24, pow: u13 }
)
(define-data-var cost-data-5 { base: uint, from: uint, pow: uint }
  { base: u60, from: u36, pow: u16 }
)

(define-private (spend-upgrade-resources (lvl uint))
  (begin
    (try! (contract-call?
      'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-spend-v0
      spend-ata
      (var-get ata-costs)
      lvl)
    )

    (try! (contract-call?
      'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-spend-v0
      spend-resource
      'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.wood-ft-v0
      (var-get cost-data-0)
      lvl
    ))
    (try! (contract-call?
      'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-spend-v0
      spend-resource
      'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.coal-ft-v0
      (var-get cost-data-1)
      lvl
    ))
    (try! (contract-call?
      'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-spend-v0
      spend-resource
      'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.sand-ft-v0
      (var-get cost-data-2)
      lvl
    ))
    (try! (contract-call?
      'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-spend-v0
      spend-resource
      'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.clay-ft-v0
      (var-get cost-data-3)
      lvl
    ))
    (try! (contract-call?
      'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-spend-v0
      spend-resource
      .copper-ft-v0
      (var-get cost-data-4)
      lvl
    ))
    (try! (contract-call?
      'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-spend-v0
      spend-resource
      .aluminium-ft-v0
      (var-get cost-data-5)
      lvl
    ))
    (ok true)
  )
)

;; COLLECT
(define-data-var base-production uint u1)
(define-private (inner-collect
    (lvl uint)
    (acc { elapsed: uint, result: uint })
  )
  {
    elapsed: (get elapsed acc),
    result: (+
      (get result acc)
      (*
        (get elapsed acc)
        ;; growth formula is `base-production * (lvl + log2(lvl^2))`
        (* (var-get base-production) (+ lvl (log2 (pow lvl u2))))
      )
    )
  }
)

(define-public (collect)
  (let (
      (player (unwrap! (contract-call? 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-store-v0 get-player tx-sender) ERR_NOT_REGISTERED))
      (to-mint (/ (get result
        (inner-collect (unwrap! (element-at? (get factories player) u0) ERR_NOT_REGISTERED) {
          elapsed: (min (- (get-current-time) (get lma player)) u259200), ;; 3 days
          result: u0,
        })
      ) u60))
    )
    (asserts! (> to-mint u0) (ok u0))
    (try! (contract-call? 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-ft-v0 mint to-mint))
    (contract-call? 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-store-v0 save-lma)
  )
)

;;; register to build the first factory
(define-public (register)
  (begin
    (try! (contract-call? 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-ft-v0 mint (var-get initial-mint)))
    (contract-call? 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-store-v0 register-first-factory tx-sender)
  )
)

(define-public (upgrade-factory)
  (let ((lvl (+ u1 (try! (contract-call? 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-store-v0 get-ata-lvl tx-sender)))))
    (try! (collect))
    (try! (spend-upgrade-resources lvl))
    (contract-call? 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-store-v0 save-factories tx-sender (list lvl))
  )
)

;; ADMIN
(define-public (set-base-production (new-base uint))
  (begin
    (try! (contract-call? 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-admin-v0 is-admin))
    (ok (var-set base-production new-base))
  )
)

(define-public (set-ata-cost (cost uint))
  (begin
    (try! (contract-call? 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-admin-v0 is-admin))
    (ok (var-set ata-costs cost))
  )
)

(define-public (set-costs
  (c0 { base: uint, from: uint, pow: uint })
  (c1 { base: uint, from: uint, pow: uint })
  (c2 { base: uint, from: uint, pow: uint })
  (c3 { base: uint, from: uint, pow: uint })
  (c4 { base: uint, from: uint, pow: uint })
  (c5 { base: uint, from: uint, pow: uint })
)
  (begin
    (try! (contract-call? 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-admin-v0 is-admin))

    (var-set cost-data-0 c0)
    (var-set cost-data-1 c1)
    (var-set cost-data-2 c2)
    (var-set cost-data-3 c3)
    (var-set cost-data-4 c4)
    (var-set cost-data-5 c5)

    (ok true)
  )
)

;; HELPERS
(define-private (min (a uint) (b uint))
  (if (< a b) a b)
)

(define-private (get-current-time)
  (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1)))
)

```
