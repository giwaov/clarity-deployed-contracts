;; ============================================
;; FORTUNE ORACLE - Daily Bitcoin Block Fortunes
;; Clarity 4 Smart Contract
;; ============================================

(define-constant ERR_NOT_FOUND (err u404))

(define-constant FORTUNE-TEMPLATES (list
  "The blocks align in your favor. Expect "
  "Satoshi whispers: "
  "The mempool reveals: "
  "Your hash destiny shows: "
  "The difficulty adjusts to bring you: "
  "A whale surfaces with news of: "
  "The next block holds: "
  "Your UTXO karma indicates: "
))

(define-constant FORTUNE-OUTCOMES (list
  "unexpected gains"
  "a pivotal decision"
  "clarity in chaos"
  "patience rewarded"
  "a bold move succeeds"
  "hidden opportunities"
  "connections that matter"
  "transformation ahead"
  "steady accumulation"
  "breaking free from limits"
  "wisdom from silence"
  "the courage to hold"
))

(define-constant MODIFIERS (list
  " today."
  " this week."
  " before the next halving."
  " when you least expect it."
  " if you trust the process."
  " through community."
))

(define-read-only (get-fortune-for-block (bh uint))
  (let
    (
      (block-info (unwrap! (get-burn-block-info? header-hash bh) ERR_NOT_FOUND))
      (slice1 (unwrap! (slice? block-info u0 u16) ERR_NOT_FOUND))
      (slice2 (unwrap! (slice? block-info u16 u32) ERR_NOT_FOUND))
      (hash-val-1 (buff-to-uint-be (unwrap! (as-max-len? slice1 u16) ERR_NOT_FOUND)))
      (hash-val-2 (buff-to-uint-be (unwrap! (as-max-len? slice2 u16) ERR_NOT_FOUND)))
      (template-idx (mod hash-val-1 u8))
      (outcome-idx (mod hash-val-2 u12))
      (modifier-idx (mod hash-val-1 u6))
    )
    (ok {
      template: (unwrap! (element-at? FORTUNE-TEMPLATES template-idx) ERR_NOT_FOUND),
      outcome: (unwrap! (element-at? FORTUNE-OUTCOMES outcome-idx) ERR_NOT_FOUND),
      modifier: (unwrap! (element-at? MODIFIERS modifier-idx) ERR_NOT_FOUND),
      lucky-number: (+ u1 (mod hash-val-1 u21)),
      bh: bh
    })
  )
)

(define-read-only (get-daily-fortune)
  (get-fortune-for-block burn-block-height)
)

(define-read-only (get-personalized-fortune (birth-bh uint))
  (let
    (
      (current-fortune (try! (get-fortune-for-block burn-block-height)))
      (birth-info (unwrap! (get-burn-block-info? header-hash birth-bh) ERR_NOT_FOUND))
      (slice1 (unwrap! (slice? birth-info u0 u16) ERR_NOT_FOUND))
      (birth-hash (buff-to-uint-be (unwrap! (as-max-len? slice1 u16) ERR_NOT_FOUND)))
      (affinity-score (mod (+ birth-hash burn-block-height) u100))
    )
    (ok (merge current-fortune {
      affinity-score: affinity-score,
      is-power-day: (>= affinity-score u80)
    }))
  )
)

(define-read-only (get-fortune-templates)
  (ok FORTUNE-TEMPLATES)
)

(define-read-only (get-fortune-outcomes)
  (ok FORTUNE-OUTCOMES)
)
