;; Mainnet Proposal: Initialize stSTXbtc-v2 Asset and Create Egroups (v1 - Fixed Parameters)
;; This proposal:
;;   1. Registers stSTXbtc-v2 token (Asset ID 11)
;;   2. Enables it for collateral
;;   3. Creates 3 egroups with different debt configurations
;;
;; V1 Fix: Updated egroup parameters to satisfy strict inequality validation
;;   - All parameters must be strictly increasing (cannot use zeros)

(impl-trait .staging-dao-traits-v0.proposal-script)

;; Oracle configuration
(define-constant STSTXBTC-FEED-ID 0xec7a775f46379b5e943c3526b1c8d54cd49749176b0b98e02dde68d1bd335c17)
(define-constant MAX-STALENESS u120)

;; Token reference
(define-constant STSTXBTC-TOKEN 'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststxbtc-token-v2)

;; Oracle type constant
(define-constant TYPE-PYTH 0x00)

;; Asset IDs (for reference):
;; STX (wstx): 0, sBTC: 1, stSTX: 2, USDC: 3, USDh: 4
;; zSTX: 5, zsBTC: 6, zstSTX: 7, zUSDC: 8, zUSDh: 9
;; stSTXbtc (v1): 10, stSTXbtc-v2: 11 (NEW)
;;
;; MASK encoding:
;; Bits 0-63: Collateral assets (bit position = asset ID)
;; Bits 64-127: Debt assets (bit position = asset ID + 64)

(define-public (execute)
  (begin    
    ;; =========================================================================
    ;; STEP 1: REGISTER ASSET
    ;; Asset ID 11: stSTXbtc-v2 (Stacked STX BTC v2)
    ;; =========================================================================
    
    ;; Register stSTXbtc-v2 with Pyth price feed (uses STX feed)
    (try! (contract-call? .staging-assets-v0 insert 
      STSTXBTC-TOKEN
      {
        type: TYPE-PYTH,
        ident: STSTXBTC-FEED-ID,
        callcode: none,
        max-staleness: MAX-STALENESS
      }))
    
    ;; Enable stSTXbtc-v2 for collateral only
    (try! (contract-call? .staging-assets-v0 enable STSTXBTC-TOKEN true))
    
    ;; =========================================================================
    ;; STEP 2: CREATE EGROUPS FOR ASSET ID 11
    ;; =========================================================================
    
    ;; -------------------------------------------------------------------------
    ;; Group 1: stSTXbtc-v2 -> USDC+USDh (40% LTV)
    ;; Medium confidence - stSTXbtc-v2 as volatile collateral
    ;; MASK = 2^11 + 2^67 + 2^68 = 442721857769029240832
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u442721857769029240832,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u4000,
      LTV-LIQ-PARTIAL: u6000,
      LTV-LIQ-FULL: u7500
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 2: stSTXbtc-v2 -> sBTC+USDC+USDh+STX+stSTX (20% LTV)
    ;; Multi-debt stSTXbtc-v2 collateral - very conservative
    ;; MASK = 2^11 + 2^64 + 2^65 + 2^66 + 2^67 + 2^68 = 571849066284996102144
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u571849066284996102144,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u2000,
      LTV-LIQ-PARTIAL: u4000,
      LTV-LIQ-FULL: u5500
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 3: stSTXbtc-v2 -> stSTX+STX (80% LTV)
    ;; High correlation pair - stSTXbtc-v2 with STX-related debt
    ;; MASK = 2^11 + 2^64 + 2^66 = 92233720368547760128
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u92233720368547760128,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u8000,
      LTV-LIQ-PARTIAL: u9000,
      LTV-LIQ-FULL: u9500
    }))
    
    (ok true)))
