;; ============================================
;; COMPATIBILITY - Wallet Relationship Checker
;; Clarity 4 Smart Contract
;; ============================================

(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_BLOCK (err u400))

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

(define-private (get-traits-for-block (bh uint))
  (let
    (
      (block-info (unwrap! (get-burn-block-info? header-hash bh) ERR_NOT_FOUND))
      (slice1 (unwrap! (slice? block-info u0 u16) ERR_NOT_FOUND))
      (slice2 (unwrap! (slice? block-info u4 u20) ERR_NOT_FOUND))
      (slice3 (unwrap! (slice? block-info u8 u24) ERR_NOT_FOUND))
      (hash-slice-1 (buff-to-uint-be (unwrap! (as-max-len? slice1 u16) ERR_NOT_FOUND)))
      (hash-slice-2 (buff-to-uint-be (unwrap! (as-max-len? slice2 u16) ERR_NOT_FOUND)))
      (hash-slice-3 (buff-to-uint-be (unwrap! (as-max-len? slice3 u16) ERR_NOT_FOUND)))
    )
    (ok {
      bitsign: (unwrap! (element-at? BITSIGNS (mod hash-slice-1 u12)) ERR_NOT_FOUND),
      element: (unwrap! (element-at? ELEMENTS (mod hash-slice-2 u5)) ERR_NOT_FOUND),
      energy: (unwrap! (element-at? ENERGIES (mod hash-slice-3 u3)) ERR_NOT_FOUND),
      power-number: (+ u1 (mod hash-slice-1 u9))
    })
  )
)

(define-public (check-compatibility (block-a uint) (block-b uint))
  (begin
    (asserts! (<= block-a burn-block-height) ERR_INVALID_BLOCK)
    (asserts! (<= block-b burn-block-height) ERR_INVALID_BLOCK)
    (let
      (
        (traits-a (unwrap! (get-traits-for-block block-a) ERR_NOT_FOUND))
        (traits-b (unwrap! (get-traits-for-block block-b) ERR_NOT_FOUND))
        (element-a (get element traits-a))
        (element-b (get element traits-b))
        (base-score (get-element-compatibility-score element-a element-b))
        (energy-bonus (if (is-eq (get energy traits-a) (get energy traits-b)) u10 u0))
        (power-synergy (if (is-eq (mod (get power-number traits-a) u3)
                                  (mod (get power-number traits-b) u3)) u5 u0))
      )
      (ok {
        score: (+ base-score energy-bonus power-synergy),
        element-match: (is-eq element-a element-b),
        energy-match: (is-eq (get energy traits-a) (get energy traits-b)),
        special-bond: (is-eq (get bitsign traits-a) (get bitsign traits-b)),
        relationship-type: (get-relationship-type (+ base-score energy-bonus power-synergy))
      })
    )
  )
)

(define-read-only (get-relationship-type (score uint))
  (if (>= score u90) "Cosmic Twins"
    (if (>= score u75) "Strong Allies"
      (if (>= score u60) "Compatible"
        (if (>= score u45) "Neutral"
          (if (>= score u30) "Challenging"
            "Opposing Forces"
          )
        )
      )
    )
  )
)

(define-read-only (get-compatibility-score (element-a (string-ascii 10)) (element-b (string-ascii 10)))
  (ok (get-element-compatibility-score element-a element-b))
)

(define-read-only (get-element-compatibility-score (element-a (string-ascii 10)) (element-b (string-ascii 10)))
  (if (is-eq element-a "Fire")
    (if (is-eq element-b "Fire") u75
      (if (is-eq element-b "Air") u90
        (if (is-eq element-b "Water") u30
          (if (is-eq element-b "Earth") u50
            u85)))) ;; Ether
    (if (is-eq element-a "Water")
      (if (is-eq element-b "Fire") u30
        (if (is-eq element-b "Water") u75
          (if (is-eq element-b "Earth") u85
            (if (is-eq element-b "Air") u50
              u70)))) ;; Ether
      (if (is-eq element-a "Earth")
        (if (is-eq element-b "Earth") u75
          (if (is-eq element-b "Water") u85
            (if (is-eq element-b "Fire") u50
              (if (is-eq element-b "Air") u60
                u80)))) ;; Ether
        (if (is-eq element-a "Air")
          (if (is-eq element-b "Air") u75
            (if (is-eq element-b "Fire") u90
              (if (is-eq element-b "Water") u50
                (if (is-eq element-b "Earth") u60
                  u85)))) ;; Ether
          ;; Ether
          (if (is-eq element-b "Ether") u100 u80) ;; Ether with anything else
        )
      )
    )
  )
)

(define-read-only (get-initial-compatibility)
  (ok {
    fire-air: u90,
    fire-fire: u75,
    fire-water: u30,
    fire-earth: u50,
    fire-ether: u85,
    water-earth: u85,
    ether-ether: u100
  })
)
