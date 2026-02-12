---
title: "Trait tipjar"
draft: true
---
```
;; STX Tip Jar - Clarity contract
;; - Immutable creator address
;; - Minimum tip enforced on-chain
;; - Tracks total STX tipped and last 5 tippers
;; - Emits event on each tip

(define-constant CREATOR 'SP13J1C3K69H3EDG2SVJ21SQ6GXD6A6F860HWK3ZJ)
(define-constant MIN_TIP u100000) ;; 0.1 STX in microSTX

;; Errors
(define-constant ERR_TIP_TOO_SMALL (err u100))
(define-constant ERR_TRANSFER_FAILED (err u101))

(define-data-var total-tips uint u0)
(define-data-var tip-counter uint u0)

(define-map recent-tips { index: uint } { tipper: principal, amount: uint, counter: uint })

(define-read-only (get-total-tips)
  (var-get total-tips)
)

(define-read-only (get-tip-count)
  (var-get tip-counter)
)

(define-read-only (get-recent-tip (index uint))
  (map-get? recent-tips { index: index })
)

(define-public (tip (amount uint))
  (begin
    (asserts! (>= amount MIN_TIP) ERR_TIP_TOO_SMALL)
    (try! (stx-transfer? amount tx-sender CREATOR))

    (var-set total-tips (+ (var-get total-tips) amount))

     (let (
          (new-counter (+ (var-get tip-counter) u1))
          (slot (mod (var-get tip-counter) u5))
        )
      (var-set tip-counter new-counter)

      ;; Store recent tip
      (map-set recent-tips
        { index: slot }
        {
          tipper: tx-sender,
          amount: amount,
          counter: new-counter
        }
      )
    

    (print {
        event: "tip",
        tipper: tx-sender,
        amount: amount,
        total_tips: (var-get total-tips),
        tip_number: new-counter,
        recent_slot: slot
    })

    (ok true)
  )
)
)
```
