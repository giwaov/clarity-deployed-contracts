;; Proposal to authorize market contract in market-vault
;; Sets market as the implementation contract for market-vault

(impl-trait .st-dao-traits.proposal-script)

(define-constant TYPE-PYTH 0x00)

(define-constant CALLCODE-ZSTSTXBTC 0x06)

(define-constant STX-FEED-ID 0xec7a775f46379b5e943c3526b1c8d54cd49749176b0b98e02dde68d1bd335c17)

(define-constant MAX-STALENESS u120)

(define-constant STSTXBTC-TOKEN 'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststxbtc-token-v2)

(define-constant CAP-STSTXBTC-SUPPLY u10000000000000)
(define-constant CAP-STSTXBTC-DEBT u0)

;; Interest rate curves (utilization to APR mapping)
(define-constant UTIL-POINTS (list u0 u2500 u5000 u7000 u7500 u8500 u9000 u10000))
(define-constant RATE-POINTS (list u200 u250 u400 u600 u800 u1800 u2500 u10000))
(define-constant RESERVE-FACTOR u1000)

(define-public (execute)
  (begin
    ;; Asset ID 11: zstSTXbtc
    (try! (contract-call? .st-assets insert STSTXBTC-TOKEN
      { type: TYPE-PYTH, ident: STX-FEED-ID, callcode: (some CALLCODE-ZSTSTXBTC), max-staleness: MAX-STALENESS }))

    ;; Enable zstSTXbtc for collateral only
    (try! (contract-call? .st-assets enable .st-vault-ststxbtc true))

    ;; Disable stSTXbtc as collateral
    (try! (contract-call? .st-assets disable STSTXBTC-TOKEN true))

    ;; Set stSTXbtc vault caps
    (try! (contract-call? .st-vault-ststxbtc set-cap-supply CAP-STSTXBTC-SUPPLY))
    (try! (contract-call? .st-vault-ststxbtc set-cap-debt CAP-STSTXBTC-DEBT))

    ;; create zstSTXbtc egroups
    ;; -------------------------------------------------------------------------
    ;; Group 1: zstSTXbtc -> USDC+USDh (40% LTV)
    ;; Medium confidence - zstSTXbtc as volatile collateral
    ;; MASK = 2^11 + 2^67 + 2^68 = 442721857769029240832
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .st-egroup insert {
      MASK: u442721857769029240832,
      BORROW-DISABLED-MASK: u0,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u4000,
      LTV-LIQ-PARTIAL: u6000,
      LTV-LIQ-FULL: u7500
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 2: zstSTXbtc -> sBTC+USDC+USDh+STX+stSTX (20% LTV)
    ;; Multi-debt zstSTXbtc collateral - very conservative
    ;; MASK = 2^11 + 2^64 + 2^65 + 2^66 + 2^67 + 2^68 = 571849066284996102144
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .st-egroup insert {
      MASK: u571849066284996102144,
      BORROW-DISABLED-MASK: u0,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u2000,
      LTV-LIQ-PARTIAL: u4000,
      LTV-LIQ-FULL: u5500
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 3: zstSTXbtc -> stSTX+STX (80% LTV)
    ;; High correlation pair - zstSTXbtc with STX-related debt
    ;; MASK = 2^11 + 2^64 + 2^66 = 92233720368547760128
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .st-egroup insert {
      MASK: u92233720368547760128,
      BORROW-DISABLED-MASK: u0,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u8000,
      LTV-LIQ-PARTIAL: u9000,
      LTV-LIQ-FULL: u9500
    }))

    (try! (contract-call? .st-vault-ststxbtc set-points-util UTIL-POINTS))
    (try! (contract-call? .st-vault-ststxbtc set-points-rate RATE-POINTS))
    (try! (contract-call? .st-vault-ststxbtc set-fee-reserve RESERVE-FACTOR))
    
    (ok true)))
