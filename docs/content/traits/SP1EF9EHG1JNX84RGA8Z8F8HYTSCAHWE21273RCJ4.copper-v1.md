---
title: "Trait copper-v1"
draft: true
---
```
;; Play at https://ata-game.space

(impl-trait 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-resource-trait-v0.ata-resource-trait-v0)
(impl-trait .ata-standard-resource-trait-v0.ata-standard-resource-trait-v0)

(define-data-var initial-mint uint u2048)

;; ERRORS
(define-constant ERR_NOT_REGISTERED (err u4211))
(define-constant ERR_INVALID_FACTORY_INDEX (err u4212))
(define-constant ERR_MAX_NB_OF_FACTORIES_REACHED (err u4213))
(define-constant ERR_CANT_EXCEED_ATA_MINER_LEVEL (err u4214))
(define-constant ERR_ATA_MINER_LEVEL_TOO_LOW (err u4215))

;; COSTS HANDLING
(define-data-var ata-costs uint u40)
(define-data-var cost-data-0 { base: uint, from: uint, pow: uint }
  { base: u100, from: u1, pow: u10 }
)
(define-data-var cost-data-1 { base: uint, from: uint, pow: uint }
  { base: u100, from: u1, pow: u11 }
)
(define-data-var cost-data-2 { base: uint, from: uint, pow: uint }
  { base: u100, from: u1, pow: u12 }
)
(define-data-var cost-data-3 { base: uint, from: uint, pow: uint }
  { base: u110, from: u5, pow: u13 }
)
(define-data-var cost-data-4 { base: uint, from: uint, pow: uint }
  { base: u110, from: u13, pow: u14 }
)
(define-data-var cost-data-5 { base: uint, from: uint, pow: uint }
  { base: u110, from: u21, pow: u15 }
)
(define-data-var cost-data-6 { base: uint, from: uint, pow: uint }
  { base: u120, from: u35, pow: u16 }
)
(define-data-var cost-data-7 { base: uint, from: uint, pow: uint }
  { base: u120, from: u47, pow: u18 }
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
      'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.sand-ft-v0
      (var-get cost-data-0)
      lvl
    ))
    (try! (contract-call?
      'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-spend-v0
      spend-resource
      'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.wood-ft-v0
      (var-get cost-data-1)
      lvl
    ))
    (try! (contract-call?
      'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-spend-v0
      spend-resource
      'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.coal-ft-v0
      (var-get cost-data-2)
      lvl
    ))
    (try! (contract-call?
      'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-spend-v0
      spend-resource
      .aluminium-ft-v0
      (var-get cost-data-3)
      lvl
    ))
    (try! (contract-call?
      'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-spend-v0
      spend-resource
      'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.stone-ft-v0
      (var-get cost-data-4)
      lvl
    ))
    (try! (contract-call?
      'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-spend-v0
      spend-resource
      'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.gravel-ft-v0
      (var-get cost-data-5)
      lvl
    ))
    (try! (contract-call?
      'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-spend-v0
      spend-resource
      'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.clay-ft-v0
      (var-get cost-data-6)
      lvl
    ))
    (try! (contract-call?
      'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-spend-v0
      spend-resource
      .iron-ft-v0
      (var-get cost-data-7)
      lvl
    ))
    (ok true)
  )
)

;; COLLECT HANDLING
(define-data-var base-production uint u6)

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
    (player (unwrap! (contract-call?
      .copper-store-v0
      get-player
      tx-sender
    ) ERR_NOT_REGISTERED))
    (to-mint (/ (get result (fold inner-collect (get factories player) {
      elapsed: (min (- (get-current-time) (get lma player)) u432000), ;; 5 days
      result: u0,
    })) u60))
  )
    (asserts! (> to-mint u0) (ok u0))
    (try! (contract-call?
      .copper-ft-v0
      mint
      to-mint
    ))
    (contract-call?
      .copper-store-v0
      save-lma
    )
  )
)

(define-public (set-base-production (new-base uint))
  (begin
    (try! (contract-call? 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-admin-v0 is-admin))
    (ok (var-set base-production new-base))
  )
)

;; BUILDING AND UPGRADING FACTORIES
;;; register to build the first factory
(define-public (register)
  (begin
    (try! (spend-upgrade-resources u1))

    (try! (contract-call?
      .copper-ft-v0
      mint
      (var-get initial-mint)
    ))
    (ok (try! (contract-call?
      .copper-store-v0
      register-first-factory
      tx-sender
    )))
  )
)

;;; add a factory to the list
(define-public (add-factory)
  (let (
    (factories (unwrap! (contract-call?
      .copper-store-v0
      get-factories
      tx-sender
    ) ERR_NOT_REGISTERED))
    (ata-lvl (try! (contract-call? 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-store-v0 get-ata-lvl tx-sender)))
    (nb-factories (len factories))
  )
    (asserts! (< nb-factories u16) ERR_MAX_NB_OF_FACTORIES_REACHED)
    (asserts! (<= (pow (+ u1 nb-factories) u2) ata-lvl) ERR_ATA_MINER_LEVEL_TOO_LOW)

    (try! (collect))
    (try! (spend-upgrade-resources u1))
    (contract-call?
      .copper-store-v0
      save-factories
      tx-sender
      (unwrap-panic (as-max-len? (append factories u1) u16))
    )
  )
)

;;; upgrade a factory level given its index
(define-public (upgrade-factory (index uint))
  (let (
    (factories (unwrap! (contract-call?
      .copper-store-v0
      get-factories
      tx-sender
    ) ERR_NOT_REGISTERED))
    (lvl (+ u1 (unwrap! (element-at? factories index) ERR_INVALID_FACTORY_INDEX)))
    (ata-lvl (try! (contract-call? 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-store-v0 get-ata-lvl tx-sender)))
  )
    ;; make sure the next factory level is lower than the ATA miner level
    (asserts! (<= lvl ata-lvl) ERR_CANT_EXCEED_ATA_MINER_LEVEL)

    (try! (collect))
    (try! (spend-upgrade-resources lvl))
    (contract-call?
      .copper-store-v0
      save-factories
      tx-sender
      (unwrap-panic (replace-at? factories index lvl))
    )
  )
)

;; ADMIN
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
  (c6 { base: uint, from: uint, pow: uint })
  (c7 { base: uint, from: uint, pow: uint })
)
  (begin
    (try! (contract-call? 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-admin-v0 is-admin))

    (var-set cost-data-0 c0)
    (var-set cost-data-1 c1)
    (var-set cost-data-2 c2)
    (var-set cost-data-3 c3)
    (var-set cost-data-4 c4)
    (var-set cost-data-5 c5)
    (var-set cost-data-6 c6)
    (var-set cost-data-7 c7)

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
