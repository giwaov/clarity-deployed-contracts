;; ============================================
;; TRAIT ENGINE - Bitcoin Block Personality Generator
;; Clarity 4 Smart Contract
;; ============================================

(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_BLOCK (err u400))
(define-constant ERR_ALREADY_REGISTERED (err u409))

(define-constant BITSIGNS (list
  "The Miner"
  "The Holder"
  "The Whale"
  "The Degen"
  "The Builder"
  "The Oracle"
  "The Pioneer"
  "The Guardian"
  "The Rebel"
  "The Sage"
  "The Phoenix"
  "The Cipher"
))

(define-constant ELEMENTS (list "Fire" "Water" "Earth" "Air" "Ether"))

(define-constant ENERGIES (list "Yang" "Yin" "Neutral"))

(define-map user-birth-blocks principal uint)

(define-read-only (get-bitsign-for-block (bh uint))
  (let
    (
      (block-info (unwrap! (get-burn-block-info? header-hash bh) ERR_NOT_FOUND))
      (sliced (unwrap! (slice? block-info u0 u16) ERR_NOT_FOUND))
      (hash-as-uint (buff-to-uint-be (unwrap! (as-max-len? sliced u16) ERR_NOT_FOUND)))
      (sign-index (mod hash-as-uint u12))
    )
    (ok (unwrap! (element-at? BITSIGNS sign-index) ERR_NOT_FOUND))
  )
)

(define-read-only (get-element-for-block (bh uint))
  (let
    (
      (block-info (unwrap! (get-burn-block-info? header-hash bh) ERR_NOT_FOUND))
      (sliced (unwrap! (slice? block-info u16 u32) ERR_NOT_FOUND))
      (hash-as-uint (buff-to-uint-be (unwrap! (as-max-len? sliced u16) ERR_NOT_FOUND)))
      (element-index (mod hash-as-uint u5))
    )
    (ok (unwrap! (element-at? ELEMENTS element-index) ERR_NOT_FOUND))
  )
)

(define-read-only (get-energy-for-block (bh uint))
  (let
    (
      (block-info (unwrap! (get-burn-block-info? header-hash bh) ERR_NOT_FOUND))
      (sliced (unwrap! (slice? block-info u0 u16) ERR_NOT_FOUND))
      (hash-as-uint (buff-to-uint-be (unwrap! (as-max-len? sliced u16) ERR_NOT_FOUND)))
      (energy-index (mod hash-as-uint u3))
    )
    (ok (unwrap! (element-at? ENERGIES energy-index) ERR_NOT_FOUND))
  )
)

(define-read-only (get-full-traits (bh uint))
  (let
    (
      (block-info (unwrap! (get-burn-block-info? header-hash bh) ERR_NOT_FOUND))
      (slice1 (unwrap! (slice? block-info u0 u16) ERR_NOT_FOUND))
      (slice2 (unwrap! (slice? block-info u16 u32) ERR_NOT_FOUND))
      (hash-val-1 (buff-to-uint-be (unwrap! (as-max-len? slice1 u16) ERR_NOT_FOUND)))
      (hash-val-2 (buff-to-uint-be (unwrap! (as-max-len? slice2 u16) ERR_NOT_FOUND)))
    )
    (ok {
      bitsign: (unwrap! (element-at? BITSIGNS (mod hash-val-1 u12)) ERR_NOT_FOUND),
      element: (unwrap! (element-at? ELEMENTS (mod hash-val-2 u5)) ERR_NOT_FOUND),
      energy: (unwrap! (element-at? ENERGIES (mod hash-val-1 u3)) ERR_NOT_FOUND),
      power-number: (+ u1 (mod hash-val-2 u9)),
      lucky-sat: (mod hash-val-1 u100000000),
      trait-hash: block-info
    })
  )
)

(define-public (register-birth-block (bh uint))
  (begin
    (asserts! (<= bh burn-block-height) ERR_INVALID_BLOCK)
    (asserts! (is-none (map-get? user-birth-blocks tx-sender)) ERR_ALREADY_REGISTERED)
    (map-set user-birth-blocks tx-sender bh)
    (ok bh)
  )
)

(define-read-only (get-user-birth-block (user principal))
  (map-get? user-birth-blocks user)
)

(define-read-only (get-user-traits (user principal))
  (let ((bh (unwrap! (map-get? user-birth-blocks user) ERR_NOT_FOUND)))
    (get-full-traits bh)
  )
)

(define-read-only (get-ai-prompt-data (bh uint))
  (let
    (
      (traits (unwrap! (get-full-traits bh) ERR_NOT_FOUND))
    )
    (ok {
      style: (get element traits),
      archetype: (get bitsign traits),
      mood: (get energy traits),
      seed: (get lucky-sat traits),
      colors: (get-colors-for-element (get element traits))
    })
  )
)

(define-read-only (get-colors-for-element (element (string-ascii 10)))
  (if (is-eq element "Fire") "crimson, orange, gold"
    (if (is-eq element "Water") "deep blue, teal, silver"
      (if (is-eq element "Earth") "forest green, brown, amber"
        (if (is-eq element "Air") "sky blue, white, lavender"
          "purple, black, starlight"
        )
      )
    )
  )
)

(define-read-only (get-all-bitsigns)
  (ok BITSIGNS)
)

(define-read-only (get-all-elements)
  (ok ELEMENTS)
)

(define-read-only (get-all-energies)
  (ok ENERGIES)
)
