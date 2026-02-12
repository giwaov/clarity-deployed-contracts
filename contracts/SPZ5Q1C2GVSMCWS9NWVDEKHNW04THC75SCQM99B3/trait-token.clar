;; ============================================
;; TRAIT TOKEN - Tradeable Personality Traits
;; SIP-013 Semi-Fungible Tokens
;; Clarity 4 Smart Contract
;; ============================================

(impl-trait .sip013-trait.sip013-trait)

(define-constant ERR_NOT_FOUND (err u404))

(define-constant TRAIT-FIRE u1)
(define-constant TRAIT-WATER u2)
(define-constant TRAIT-EARTH u3)
(define-constant TRAIT-AIR u4)
(define-constant TRAIT-ETHER u5)
(define-constant TRAIT-YANG u6)
(define-constant TRAIT-YIN u7)
(define-constant TRAIT-POWER-BOOST u8)

(define-constant ELEMENTS (list "Fire" "Water" "Earth" "Air" "Ether"))
(define-constant ENERGIES (list "Yang" "Yin" "Neutral"))

(define-map balances { owner: principal, token-id: uint } uint)
(define-map token-supplies uint uint)

(define-read-only (get-balance (token-id uint) (owner principal))
  (ok (default-to u0 (map-get? balances { owner: owner, token-id: token-id })))
)

(define-read-only (get-total-supply (token-id uint))
  (ok (default-to u0 (map-get? token-supplies token-id)))
)

(define-read-only (get-decimals (token-id uint))
  (begin
    token-id ;; silence unused warning
    (ok u0)
  )
)

(define-read-only (get-token-uri (token-id uint) )
  (begin
    token-id ;; silence unused warning
    (ok none)
  )
)

(define-public (transfer (token-id uint) (amount uint) (sender principal) (recipient principal))
  (let ((sender-balance (default-to u0 (map-get? balances { owner: sender, token-id: token-id }))))
    (asserts! (is-eq tx-sender sender) (err u401))
    (asserts! (>= sender-balance amount) (err u402))
    (map-set balances { owner: sender, token-id: token-id } (- sender-balance amount))
    (map-set balances { owner: recipient, token-id: token-id }
      (+ (default-to u0 (map-get? balances { owner: recipient, token-id: token-id })) amount))
    (ok true)
  )
)

(define-public (claim-traits (bh uint))
  (let
    (
      (block-info (unwrap! (get-burn-block-info? header-hash bh) ERR_NOT_FOUND))
      (slice1 (unwrap! (slice? block-info u0 u16) ERR_NOT_FOUND))
      (slice2 (unwrap! (slice? block-info u16 u32) ERR_NOT_FOUND))
      (hash-val-1 (buff-to-uint-be (unwrap! (as-max-len? slice1 u16) ERR_NOT_FOUND)))
      (hash-val-2 (buff-to-uint-be (unwrap! (as-max-len? slice2 u16) ERR_NOT_FOUND)))
      (element-index (mod hash-val-1 u5))
      (energy-index (mod hash-val-2 u3))
      (power-number (+ u1 (mod hash-val-1 u9)))
      (element (unwrap! (element-at? ELEMENTS element-index) ERR_NOT_FOUND))
      (energy (unwrap! (element-at? ENERGIES energy-index) ERR_NOT_FOUND))
      (element-token (get-element-token-id element))
      (energy-token (get-energy-token-id energy))
    )
    (unwrap-panic (mint-internal element-token u1 tx-sender))
    (unwrap-panic (mint-internal energy-token u1 tx-sender))
    (if (>= power-number u7)
      (unwrap-panic (mint-internal TRAIT-POWER-BOOST u1 tx-sender))
      true
    )
    (ok true)
  )
)

(define-private (mint-internal (token-id uint) (amount uint) (recipient principal))
  (begin
    (map-set balances { owner: recipient, token-id: token-id }
      (+ (default-to u0 (map-get? balances { owner: recipient, token-id: token-id })) amount))
    (map-set token-supplies token-id
      (+ (default-to u0 (map-get? token-supplies token-id)) amount))
    (ok true)
  )
)

(define-read-only (get-element-token-id (element (string-ascii 10)))
  (if (is-eq element "Fire") TRAIT-FIRE
    (if (is-eq element "Water") TRAIT-WATER
      (if (is-eq element "Earth") TRAIT-EARTH
        (if (is-eq element "Air") TRAIT-AIR
          TRAIT-ETHER
        )
      )
    )
  )
)

(define-read-only (get-energy-token-id (energy (string-ascii 10)))
  (if (is-eq energy "Yang") TRAIT-YANG TRAIT-YIN)
)

(define-read-only (get-trait-name (token-id uint))
  (if (is-eq token-id TRAIT-FIRE) "Fire Element"
    (if (is-eq token-id TRAIT-WATER) "Water Element"
      (if (is-eq token-id TRAIT-EARTH) "Earth Element"
        (if (is-eq token-id TRAIT-AIR) "Air Element"
          (if (is-eq token-id TRAIT-ETHER) "Ether Element"
            (if (is-eq token-id TRAIT-YANG) "Yang Energy"
              (if (is-eq token-id TRAIT-YIN) "Yin Energy"
                (if (is-eq token-id TRAIT-POWER-BOOST) "Power Boost"
                  "Unknown"
                )
              )
            )
          )
        )
      )
    )
  )
)
