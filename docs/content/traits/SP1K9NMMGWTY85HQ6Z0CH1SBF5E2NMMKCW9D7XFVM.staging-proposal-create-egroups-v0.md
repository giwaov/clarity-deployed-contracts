---
title: "Trait staging-proposal-create-egroups-v0"
draft: true
---
```
;; Mainnet Proposal: Create Production Egroups
;; This proposal creates 25 production egroups for Zest Market V2
;; Including support for new stSTXbtc collateral-only asset

(impl-trait .staging-dao-traits-v0.proposal-script)

;; Asset IDs (from proposal-init-assets-mainnet.clar registration order):
;; STX (wstx): 0, sBTC: 1, stSTX: 2, USDC: 3, USDh: 4
;; zSTX: 5, zsBTC: 6, zstSTX: 7, zUSDC: 8, zUSDh: 9
;; stSTXbtc: 10 (NEW - collateral only)
;;
;; MASK encoding:
;; Bits 0-63: Collateral assets (bit position = asset ID)
;; Bits 64-127: Debt assets (bit position = asset ID + 64)
;;
;; Risk Parameters:
;; - LTV values in basis points (7000 = 70%)
;; - Penalty values in basis points (500 = 5%, 1000 = 10%)
;; - Curve exponent 10000 = 1.0 (linear)

(define-public (execute)
  (begin
    ;; =========================================================================
    ;; UNDERLYING ASSET GROUPS (Groups 1-14)
    ;; =========================================================================
    
    ;; -------------------------------------------------------------------------
    ;; Group 1: sBTC -> USDC+USDh (70% LTV)
    ;; High confidence - BTC as premium collateral with stablecoin debt
    ;; MASK = 2^1 + 2^67 + 2^68 = 442721857769029238786
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u442721857769029238786,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u7000,
      LTV-LIQ-PARTIAL: u8500,
      LTV-LIQ-FULL: u9000
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 2: STX -> USDC+USDh (40% LTV)
    ;; Medium confidence - STX as volatile collateral
    ;; MASK = 2^0 + 2^67 + 2^68 = 442721857769029238785
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u442721857769029238785,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u4000,
      LTV-LIQ-PARTIAL: u6000,
      LTV-LIQ-FULL: u7500
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 3: stSTX -> USDC+USDh (40% LTV)
    ;; Medium confidence - stSTX as volatile collateral
    ;; MASK = 2^2 + 2^67 + 2^68 = 442721857769029238788
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u442721857769029238788,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u4000,
      LTV-LIQ-PARTIAL: u6000,
      LTV-LIQ-FULL: u7500
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 4: stSTXbtc -> USDC+USDh (40% LTV)
    ;; Medium confidence - stSTXbtc as volatile collateral (collateral-only asset)
    ;; MASK = 2^10 + 2^67 + 2^68 = 442721857769029239808
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u442721857769029239808,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u4000,
      LTV-LIQ-PARTIAL: u6000,
      LTV-LIQ-FULL: u7500
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 5: USDC -> STX (30% LTV)
    ;; Lower confidence - stablecoin collateral, volatile debt
    ;; MASK = 2^3 + 2^64 = 18446744073709551624
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u18446744073709551624,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u3000,
      LTV-LIQ-PARTIAL: u5000,
      LTV-LIQ-FULL: u6500
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 6: sBTC -> STX+USDC+USDh+stSTX+sBTC (30% LTV)
    ;; Multi-debt BTC collateral - conservative due to debt diversity
    ;; MASK = 2^1 + 2^64 + 2^65 + 2^66 + 2^67 + 2^68 = 571849066284996100098
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u571849066284996100098,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u3000,
      LTV-LIQ-PARTIAL: u4000,
      LTV-LIQ-FULL: u5500
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 7: STX -> sBTC+USDC+USDh+stSTX+STX (20% LTV)
    ;; Multi-debt STX collateral - very conservative
    ;; MASK = 2^0 + 2^64 + 2^65 + 2^66 + 2^67 + 2^68 = 571849066284996100097
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u571849066284996100097,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u2000,
      LTV-LIQ-PARTIAL: u4000,
      LTV-LIQ-FULL: u5500
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 8: stSTX -> sBTC+USDC+USDh+STX+stSTX (20% LTV)
    ;; Multi-debt stSTX collateral - very conservative
    ;; MASK = 2^2 + 2^64 + 2^65 + 2^66 + 2^67 + 2^68 = 571849066284996100100
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u571849066284996100100,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u2000,
      LTV-LIQ-PARTIAL: u4000,
      LTV-LIQ-FULL: u5500
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 9: stSTXbtc -> sBTC+USDC+USDh+STX+stSTX (20% LTV)
    ;; Multi-debt stSTXbtc collateral - very conservative
    ;; MASK = 2^10 + 2^64 + 2^65 + 2^66 + 2^67 + 2^68 = 571849066284996101120
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u571849066284996101120,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u2000,
      LTV-LIQ-PARTIAL: u4000,
      LTV-LIQ-FULL: u5500
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 10: STX -> stSTX+STX (80% LTV)
    ;; High correlation pair - very high LTV
    ;; MASK = 2^0 + 2^64 + 2^66 = 92233720368547758081
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u92233720368547758081,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u8000,
      LTV-LIQ-PARTIAL: u9000,
      LTV-LIQ-FULL: u9500
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 11: stSTX -> stSTX+STX (80% LTV)
    ;; High correlation pair - very high LTV
    ;; MASK = 2^2 + 2^64 + 2^66 = 92233720368547758084
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u92233720368547758084,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u8000,
      LTV-LIQ-PARTIAL: u9000,
      LTV-LIQ-FULL: u9500
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 12: stSTXbtc -> stSTX+STX (80% LTV)
    ;; High correlation pair - stSTXbtc with STX-related debt
    ;; MASK = 2^10 + 2^64 + 2^66 = 92233720368547759104
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u92233720368547759104,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u8000,
      LTV-LIQ-PARTIAL: u9000,
      LTV-LIQ-FULL: u9500
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 13: sBTC -> sBTC (80% LTV)
    ;; Same asset pair - highest LTV for looping strategies
    ;; MASK = 2^1 + 2^65 = 36893488147419103234
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u36893488147419103234,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u8000,
      LTV-LIQ-PARTIAL: u9000,
      LTV-LIQ-FULL: u9500
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 14: USDC -> USDh (50% LTV)
    ;; Stablecoin pair - moderate LTV
    ;; MASK = 2^3 + 2^68 = 295147905179352825864
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u295147905179352825864,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u5000,
      LTV-LIQ-PARTIAL: u6000,
      LTV-LIQ-FULL: u7500
    }))
    
    ;; =========================================================================
    ;; Z-TOKEN GROUPS (Groups 15-25)
    ;; Vault share tokens as collateral
    ;; =========================================================================
    
    ;; -------------------------------------------------------------------------
    ;; Group 15: zsBTC -> USDC+USDh (70% LTV)
    ;; Vault share collateral with stablecoin debt
    ;; MASK = 2^6 + 2^67 + 2^68 = 442721857769029238848
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u442721857769029238848,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u7000,
      LTV-LIQ-PARTIAL: u8500,
      LTV-LIQ-FULL: u9000
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 16: zSTX -> USDC+USDh (40% LTV)
    ;; Vault share collateral with stablecoin debt
    ;; MASK = 2^5 + 2^67 + 2^68 = 442721857769029238816
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u442721857769029238816,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u4000,
      LTV-LIQ-PARTIAL: u6000,
      LTV-LIQ-FULL: u7500
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 17: zstSTX -> USDC+USDh (40% LTV)
    ;; Vault share collateral with stablecoin debt
    ;; MASK = 2^7 + 2^67 + 2^68 = 442721857769029238912
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u442721857769029238912,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u4000,
      LTV-LIQ-PARTIAL: u6000,
      LTV-LIQ-FULL: u7500
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 18: zUSDC -> STX (30% LTV)
    ;; Vault share collateral with volatile debt
    ;; MASK = 2^8 + 2^64 = 18446744073709551872
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u18446744073709551872,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u3000,
      LTV-LIQ-PARTIAL: u5000,
      LTV-LIQ-FULL: u6500
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 19: zsBTC -> STX+USDC+USDh+stSTX+sBTC (30% LTV)
    ;; Multi-debt vault share collateral
    ;; MASK = 2^6 + 2^64 + 2^65 + 2^66 + 2^67 + 2^68 = 571849066284996100160
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u571849066284996100160,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u3000,
      LTV-LIQ-PARTIAL: u4000,
      LTV-LIQ-FULL: u5500
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 20: zSTX -> sBTC+USDC+USDh+stSTX+STX (20% LTV)
    ;; Multi-debt vault share collateral - very conservative
    ;; MASK = 2^5 + 2^64 + 2^65 + 2^66 + 2^67 + 2^68 = 571849066284996100128
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u571849066284996100128,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u2000,
      LTV-LIQ-PARTIAL: u4000,
      LTV-LIQ-FULL: u5500
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 21: zstSTX -> sBTC+USDC+USDh+STX+stSTX (20% LTV)
    ;; Multi-debt vault share collateral - very conservative
    ;; MASK = 2^7 + 2^64 + 2^65 + 2^66 + 2^67 + 2^68 = 571849066284996100224
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u571849066284996100224,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u2000,
      LTV-LIQ-PARTIAL: u4000,
      LTV-LIQ-FULL: u5500
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 22: zSTX -> stSTX+STX (80% LTV)
    ;; High correlation vault share pair
    ;; MASK = 2^5 + 2^64 + 2^66 = 92233720368547758112
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u92233720368547758112,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u8000,
      LTV-LIQ-PARTIAL: u9000,
      LTV-LIQ-FULL: u9500
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 23: zstSTX -> stSTX+STX (80% LTV)
    ;; High correlation vault share pair
    ;; MASK = 2^7 + 2^64 + 2^66 = 92233720368547758208
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u92233720368547758208,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u8000,
      LTV-LIQ-PARTIAL: u9000,
      LTV-LIQ-FULL: u9500
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 24: zsBTC -> sBTC (80% LTV)
    ;; Same underlying asset pair - highest LTV
    ;; MASK = 2^6 + 2^65 = 36893488147419103296
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u36893488147419103296,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u8000,
      LTV-LIQ-PARTIAL: u9000,
      LTV-LIQ-FULL: u9500
    }))
    
    ;; -------------------------------------------------------------------------
    ;; Group 25: zUSDC -> USDh (50% LTV)
    ;; Stablecoin vault share pair
    ;; MASK = 2^8 + 2^68 = 295147905179352826112
    ;; -------------------------------------------------------------------------
    (try! (contract-call? .staging-egroup-v0 insert {
      MASK: u295147905179352826112,
      LIQ-CURVE-EXP: u10000,
      LIQ-PENALTY-MIN: u500,
      LIQ-PENALTY-MAX: u1000,
      LTV-BORROW: u5000,
      LTV-LIQ-PARTIAL: u6000,
      LTV-LIQ-FULL: u7500
    }))
    
    (ok true)))

```
