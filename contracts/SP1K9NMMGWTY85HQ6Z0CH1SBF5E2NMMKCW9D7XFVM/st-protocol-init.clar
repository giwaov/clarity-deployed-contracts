;; Comprehensive Protocol Initialization Proposal
;;
;; This proposal configures the entire Zest Protocol in a single transaction:
;;   1. Initialize assets (register tokens + oracles)
;;   2. Initialize market-vault (set market as implementation)
;;   3. Set vault caps and authorize market
;;   4. Create 25 egroups (collateral/debt combinations)
;;   5. Set interest rate curves for all vaults
;;
;; NOTE: Vault initialization (minting minimum liquidity) is done
;; via script AFTER this proposal executes.

(impl-trait .st-dao-traits.proposal-script)

;; Oracle type constants
(define-constant TYPE-PYTH 0x00)
(define-constant TYPE-DIA 0x01)

;; Callcode constants for price transformations
(define-constant CALLCODE-STSTX 0x00)
(define-constant CALLCODE-ZSTX 0x01)
(define-constant CALLCODE-ZSBTC 0x02)
(define-constant CALLCODE-ZSTSTX 0x03)
(define-constant CALLCODE-ZUSDC 0x04)
(define-constant CALLCODE-ZUSDH 0x05)

;; Mainnet Pyth price feed IDs
(define-constant STX-FEED-ID 0xec7a775f46379b5e943c3526b1c8d54cd49749176b0b98e02dde68d1bd335c17)
(define-constant BTC-FEED-ID 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43)
(define-constant USDC-FEED-ID 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a)

;; USDh uses DIA oracle
(define-constant USDH-DIA-KEY "USDh/USD")

;; Production staleness threshold: 120 seconds (2 minutes)
(define-constant MAX-STALENESS u120)

;; Mainnet token contract references
(define-constant SBTC-TOKEN 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token)
(define-constant STSTX-TOKEN 'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststx-token)
(define-constant USDC-TOKEN 'SP120SBRBQJ00MCWS7TM5R8WJNTTKD5K0HFRC2CNE.usdcx)
(define-constant USDH-TOKEN 'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.usdh-token-v1)
(define-constant STSTXBTC-TOKEN 'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststxbtc-token-v2)

;; Vault caps (conservative initial limits)
(define-constant CAP-STX-SUPPLY u10000000000000)
(define-constant CAP-STX-DEBT u10000000000000)
(define-constant CAP-SBTC-SUPPLY u10000000000)
(define-constant CAP-SBTC-DEBT u10000000000)
(define-constant CAP-STSTX-SUPPLY u10000000000000)
(define-constant CAP-STSTX-DEBT u10000000000000)
(define-constant CAP-USDC-SUPPLY u10000000000000)
(define-constant CAP-USDC-DEBT u10000000000000)
(define-constant CAP-USDH-SUPPLY u1000000000000000)
(define-constant CAP-USDH-DEBT u1000000000000000)

;; Interest rate curves (utilization to APR mapping)
(define-constant UTIL-POINTS (list u0 u2500 u5000 u7000 u7500 u8500 u9000 u10000))
(define-constant RATE-POINTS (list u200 u250 u400 u600 u800 u1800 u2500 u10000))
(define-constant RESERVE-FACTOR u1000)

(define-public (execute)
  (begin
    ;; STEP 1: INITIALIZE ASSETS
    
    ;; Asset ID 0: wSTX
    (try! (contract-call? .st-assets insert .st-wstx
      { type: TYPE-PYTH, ident: STX-FEED-ID, callcode: none, max-staleness: MAX-STALENESS }))
    
    ;; Asset ID 1: sBTC
    (try! (contract-call? .st-assets insert SBTC-TOKEN
      { type: TYPE-PYTH, ident: BTC-FEED-ID, callcode: none, max-staleness: MAX-STALENESS }))
    
    ;; Asset ID 2: stSTX
    (try! (contract-call? .st-assets insert STSTX-TOKEN
      { type: TYPE-PYTH, ident: STX-FEED-ID, callcode: (some CALLCODE-STSTX), max-staleness: MAX-STALENESS }))
    
    ;; Asset ID 3: USDC
    (try! (contract-call? .st-assets insert USDC-TOKEN
      { type: TYPE-PYTH, ident: USDC-FEED-ID, callcode: none, max-staleness: MAX-STALENESS }))
    
    ;; Asset ID 4: USDh
    (try! (contract-call? .st-assets insert USDH-TOKEN
      { type: TYPE-DIA, ident: (unwrap-panic (to-consensus-buff? USDH-DIA-KEY)), callcode: none, max-staleness: MAX-STALENESS }))
    
    ;; Asset ID 5: zSTX
    (try! (contract-call? .st-assets insert .st-vault-stx
      { type: TYPE-PYTH, ident: STX-FEED-ID, callcode: (some CALLCODE-ZSTX), max-staleness: MAX-STALENESS }))
    
    ;; Asset ID 6: zsBTC
    (try! (contract-call? .st-assets insert .st-vault-sbtc
      { type: TYPE-PYTH, ident: BTC-FEED-ID, callcode: (some CALLCODE-ZSBTC), max-staleness: MAX-STALENESS }))
    
    ;; Asset ID 7: zstSTX
    (try! (contract-call? .st-assets insert .st-vault-ststx
      { type: TYPE-PYTH, ident: STX-FEED-ID, callcode: (some CALLCODE-ZSTSTX), max-staleness: MAX-STALENESS }))
    
    ;; Asset ID 8: zUSDC
    (try! (contract-call? .st-assets insert .st-vault-usdc
      { type: TYPE-PYTH, ident: USDC-FEED-ID, callcode: (some CALLCODE-ZUSDC), max-staleness: MAX-STALENESS }))
    
    ;; Asset ID 9: zUSDh
    (try! (contract-call? .st-assets insert .st-vault-usdh
      { type: TYPE-DIA, ident: (unwrap-panic (to-consensus-buff? USDH-DIA-KEY)), callcode: (some CALLCODE-ZUSDH), max-staleness: MAX-STALENESS }))

    ;; Asset ID 10: stSTXbtc
    (try! (contract-call? .st-assets insert STSTXBTC-TOKEN
      { type: TYPE-PYTH, ident: STX-FEED-ID, callcode: none, max-staleness: MAX-STALENESS }))
    
    ;; Enable underlying tokens for collateral and debt
    (try! (contract-call? .st-assets enable .st-wstx true))
    (try! (contract-call? .st-assets enable .st-wstx false))
    (try! (contract-call? .st-assets enable SBTC-TOKEN true))
    (try! (contract-call? .st-assets enable SBTC-TOKEN false))
    (try! (contract-call? .st-assets enable STSTX-TOKEN true))
    (try! (contract-call? .st-assets enable STSTX-TOKEN false))
    (try! (contract-call? .st-assets enable USDC-TOKEN true))
    (try! (contract-call? .st-assets enable USDC-TOKEN false))
    (try! (contract-call? .st-assets enable USDH-TOKEN true))
    (try! (contract-call? .st-assets enable USDH-TOKEN false))
    
    ;; Enable ztokens for collateral only
    (try! (contract-call? .st-assets enable .st-vault-stx true))
    (try! (contract-call? .st-assets enable .st-vault-sbtc true))
    (try! (contract-call? .st-assets enable .st-vault-ststx true))
    (try! (contract-call? .st-assets enable .st-vault-usdc true))
    (try! (contract-call? .st-assets enable .st-vault-usdh true))

    ;; Enable stSTXbtc for collateral only
    (try! (contract-call? .st-assets enable STSTXBTC-TOKEN true))

    ;; STEP 2: INITIALIZE MARKET-VAULT
    (try! (contract-call? .st-market-vault set-impl .st-market))
    
    ;; STEP 3: CONFIGURE VAULTS
    
    ;; Set vault caps
    (try! (contract-call? .st-vault-stx set-cap-supply CAP-STX-SUPPLY))
    (try! (contract-call? .st-vault-stx set-cap-debt CAP-STX-DEBT))
    (try! (contract-call? .st-vault-sbtc set-cap-supply CAP-SBTC-SUPPLY))
    (try! (contract-call? .st-vault-sbtc set-cap-debt CAP-SBTC-DEBT))
    (try! (contract-call? .st-vault-ststx set-cap-supply CAP-STSTX-SUPPLY))
    (try! (contract-call? .st-vault-ststx set-cap-debt CAP-STSTX-DEBT))
    (try! (contract-call? .st-vault-usdc set-cap-supply CAP-USDC-SUPPLY))
    (try! (contract-call? .st-vault-usdc set-cap-debt CAP-USDC-DEBT))
    (try! (contract-call? .st-vault-usdh set-cap-supply CAP-USDH-SUPPLY))
    (try! (contract-call? .st-vault-usdh set-cap-debt CAP-USDH-DEBT))
    
    ;; Authorize market contract in all vaults
    (try! (contract-call? .st-vault-stx set-authorized-contract .st-market true))
    (try! (contract-call? .st-vault-sbtc set-authorized-contract .st-market true))
    (try! (contract-call? .st-vault-ststx set-authorized-contract .st-market true))
    (try! (contract-call? .st-vault-usdc set-authorized-contract .st-market true))
    (try! (contract-call? .st-vault-usdh set-authorized-contract .st-market true))
    
    ;; STEP 4: CREATE EGROUPS
    
    ;; Group 1: sBTC to USDC+USDh (70% LTV)
    (try! (contract-call? .st-egroup insert { BORROW-DISABLED-MASK: u0, MASK: u442721857769029238786, LIQ-CURVE-EXP: u10000, LIQ-PENALTY-MIN: u500, LIQ-PENALTY-MAX: u1000, LTV-BORROW: u7000, LTV-LIQ-PARTIAL: u8500, LTV-LIQ-FULL: u9000 }))
    ;; Group 2: STX to USDC+USDh (40% LTV)
    (try! (contract-call? .st-egroup insert { BORROW-DISABLED-MASK: u0, MASK: u442721857769029238785, LIQ-CURVE-EXP: u10000, LIQ-PENALTY-MIN: u500, LIQ-PENALTY-MAX: u1000, LTV-BORROW: u4000, LTV-LIQ-PARTIAL: u6000, LTV-LIQ-FULL: u7500 }))
    ;; Group 3: stSTX to USDC+USDh (40% LTV)
    (try! (contract-call? .st-egroup insert { BORROW-DISABLED-MASK: u0, MASK: u442721857769029238788, LIQ-CURVE-EXP: u10000, LIQ-PENALTY-MIN: u500, LIQ-PENALTY-MAX: u1000, LTV-BORROW: u4000, LTV-LIQ-PARTIAL: u6000, LTV-LIQ-FULL: u7500 }))
    ;; Group 4: USDC to STX (30% LTV)
    (try! (contract-call? .st-egroup insert { BORROW-DISABLED-MASK: u0, MASK: u18446744073709551624, LIQ-CURVE-EXP: u10000, LIQ-PENALTY-MIN: u500, LIQ-PENALTY-MAX: u1000, LTV-BORROW: u3000, LTV-LIQ-PARTIAL: u5000, LTV-LIQ-FULL: u6500 }))
    ;; Group 5: sBTC to STX+USDC+USDh+stSTX+sBTC (30% LTV)
    (try! (contract-call? .st-egroup insert { BORROW-DISABLED-MASK: u0, MASK: u571849066284996100098, LIQ-CURVE-EXP: u10000, LIQ-PENALTY-MIN: u500, LIQ-PENALTY-MAX: u1000, LTV-BORROW: u3000, LTV-LIQ-PARTIAL: u4000, LTV-LIQ-FULL: u5500 }))
    ;; Group 6: STX to sBTC+USDC+USDh+stSTX+STX (20% LTV)
    (try! (contract-call? .st-egroup insert { BORROW-DISABLED-MASK: u0, MASK: u571849066284996100097, LIQ-CURVE-EXP: u10000, LIQ-PENALTY-MIN: u500, LIQ-PENALTY-MAX: u1000, LTV-BORROW: u2000, LTV-LIQ-PARTIAL: u4000, LTV-LIQ-FULL: u5500 }))
    ;; Group 7: stSTX to sBTC+USDC+USDh+STX+stSTX (20% LTV)
    (try! (contract-call? .st-egroup insert { BORROW-DISABLED-MASK: u0, MASK: u571849066284996100100, LIQ-CURVE-EXP: u10000, LIQ-PENALTY-MIN: u500, LIQ-PENALTY-MAX: u1000, LTV-BORROW: u2000, LTV-LIQ-PARTIAL: u4000, LTV-LIQ-FULL: u5500 }))
    ;; Group 8: STX to stSTX+STX (80% LTV)
    (try! (contract-call? .st-egroup insert { BORROW-DISABLED-MASK: u0, MASK: u92233720368547758081, LIQ-CURVE-EXP: u10000, LIQ-PENALTY-MIN: u500, LIQ-PENALTY-MAX: u1000, LTV-BORROW: u8000, LTV-LIQ-PARTIAL: u9000, LTV-LIQ-FULL: u9500 }))
    ;; Group 9: stSTX to stSTX+STX (80% LTV)
    (try! (contract-call? .st-egroup insert { BORROW-DISABLED-MASK: u0, MASK: u92233720368547758084, LIQ-CURVE-EXP: u10000, LIQ-PENALTY-MIN: u500, LIQ-PENALTY-MAX: u1000, LTV-BORROW: u8000, LTV-LIQ-PARTIAL: u9000, LTV-LIQ-FULL: u9500 }))
    ;; Group 10: sBTC to sBTC (80% LTV)
    (try! (contract-call? .st-egroup insert { BORROW-DISABLED-MASK: u0, MASK: u36893488147419103234, LIQ-CURVE-EXP: u10000, LIQ-PENALTY-MIN: u500, LIQ-PENALTY-MAX: u1000, LTV-BORROW: u8000, LTV-LIQ-PARTIAL: u9000, LTV-LIQ-FULL: u9500 }))
    ;; Group 11: USDC to USDh (50% LTV)
    (try! (contract-call? .st-egroup insert { BORROW-DISABLED-MASK: u0, MASK: u295147905179352825864, LIQ-CURVE-EXP: u10000, LIQ-PENALTY-MIN: u500, LIQ-PENALTY-MAX: u1000, LTV-BORROW: u5000, LTV-LIQ-PARTIAL: u6000, LTV-LIQ-FULL: u7500 }))
    
    ;; Group 12: zsBTC to USDC+USDh (70% LTV)
    (try! (contract-call? .st-egroup insert { BORROW-DISABLED-MASK: u0, MASK: u442721857769029238848, LIQ-CURVE-EXP: u10000, LIQ-PENALTY-MIN: u500, LIQ-PENALTY-MAX: u1000, LTV-BORROW: u7000, LTV-LIQ-PARTIAL: u8500, LTV-LIQ-FULL: u9000 }))
    ;; Group 13: zSTX to USDC+USDh (40% LTV)
    (try! (contract-call? .st-egroup insert { BORROW-DISABLED-MASK: u0, MASK: u442721857769029238816, LIQ-CURVE-EXP: u10000, LIQ-PENALTY-MIN: u500, LIQ-PENALTY-MAX: u1000, LTV-BORROW: u4000, LTV-LIQ-PARTIAL: u6000, LTV-LIQ-FULL: u7500 }))
    ;; Group 14: zstSTX to USDC+USDh (40% LTV)
    (try! (contract-call? .st-egroup insert { BORROW-DISABLED-MASK: u0, MASK: u442721857769029238912, LIQ-CURVE-EXP: u10000, LIQ-PENALTY-MIN: u500, LIQ-PENALTY-MAX: u1000, LTV-BORROW: u4000, LTV-LIQ-PARTIAL: u6000, LTV-LIQ-FULL: u7500 }))
    ;; Group 15: zUSDC to STX (30% LTV)
    (try! (contract-call? .st-egroup insert { BORROW-DISABLED-MASK: u0, MASK: u18446744073709551872, LIQ-CURVE-EXP: u10000, LIQ-PENALTY-MIN: u500, LIQ-PENALTY-MAX: u1000, LTV-BORROW: u3000, LTV-LIQ-PARTIAL: u5000, LTV-LIQ-FULL: u6500 }))
    ;; Group 16: zsBTC to STX+USDC+USDh+stSTX+sBTC (30% LTV)
    (try! (contract-call? .st-egroup insert { BORROW-DISABLED-MASK: u0, MASK: u571849066284996100160, LIQ-CURVE-EXP: u10000, LIQ-PENALTY-MIN: u500, LIQ-PENALTY-MAX: u1000, LTV-BORROW: u3000, LTV-LIQ-PARTIAL: u4000, LTV-LIQ-FULL: u5500 }))
    ;; Group 17: zSTX to sBTC+USDC+USDh+stSTX+STX (20% LTV)
    (try! (contract-call? .st-egroup insert { BORROW-DISABLED-MASK: u0, MASK: u571849066284996100128, LIQ-CURVE-EXP: u10000, LIQ-PENALTY-MIN: u500, LIQ-PENALTY-MAX: u1000, LTV-BORROW: u2000, LTV-LIQ-PARTIAL: u4000, LTV-LIQ-FULL: u5500 }))
    ;; Group 18: zstSTX to sBTC+USDC+USDh+STX+stSTX (20% LTV)
    (try! (contract-call? .st-egroup insert { BORROW-DISABLED-MASK: u0, MASK: u571849066284996100224, LIQ-CURVE-EXP: u10000, LIQ-PENALTY-MIN: u500, LIQ-PENALTY-MAX: u1000, LTV-BORROW: u2000, LTV-LIQ-PARTIAL: u4000, LTV-LIQ-FULL: u5500 }))
    ;; Group 19: zSTX to stSTX+STX (80% LTV)
    (try! (contract-call? .st-egroup insert { BORROW-DISABLED-MASK: u0, MASK: u92233720368547758112, LIQ-CURVE-EXP: u10000, LIQ-PENALTY-MIN: u500, LIQ-PENALTY-MAX: u1000, LTV-BORROW: u8000, LTV-LIQ-PARTIAL: u9000, LTV-LIQ-FULL: u9500 }))
    ;; Group 20: zstSTX to stSTX+STX (80% LTV)
    (try! (contract-call? .st-egroup insert { BORROW-DISABLED-MASK: u0, MASK: u92233720368547758208, LIQ-CURVE-EXP: u10000, LIQ-PENALTY-MIN: u500, LIQ-PENALTY-MAX: u1000, LTV-BORROW: u8000, LTV-LIQ-PARTIAL: u9000, LTV-LIQ-FULL: u9500 }))
    ;; Group 21: zsBTC to sBTC (80% LTV)
    (try! (contract-call? .st-egroup insert { BORROW-DISABLED-MASK: u0, MASK: u36893488147419103296, LIQ-CURVE-EXP: u10000, LIQ-PENALTY-MIN: u500, LIQ-PENALTY-MAX: u1000, LTV-BORROW: u8000, LTV-LIQ-PARTIAL: u9000, LTV-LIQ-FULL: u9500 }))
    ;; Group 22: zUSDC to USDh (50% LTV)
    (try! (contract-call? .st-egroup insert { BORROW-DISABLED-MASK: u0, MASK: u295147905179352826112, LIQ-CURVE-EXP: u10000, LIQ-PENALTY-MIN: u500, LIQ-PENALTY-MAX: u1000, LTV-BORROW: u5000, LTV-LIQ-PARTIAL: u6000, LTV-LIQ-FULL: u7500 }))
    ;; Group 23: stSTXbtc to USDC+USDh (40% LTV)
    (try! (contract-call? .st-egroup insert { BORROW-DISABLED-MASK: u0, MASK: u442721857769029239808, LIQ-CURVE-EXP: u10000, LIQ-PENALTY-MIN: u500, LIQ-PENALTY-MAX: u1000, LTV-BORROW: u4000, LTV-LIQ-PARTIAL: u6000, LTV-LIQ-FULL: u7500 }))
    ;; Group 24: stSTXbtc to sBTC+USDC+USDh+STX+stSTX (20% LTV)
    (try! (contract-call? .st-egroup insert { BORROW-DISABLED-MASK: u0, MASK: u571849066284996101120, LIQ-CURVE-EXP: u10000, LIQ-PENALTY-MIN: u500, LIQ-PENALTY-MAX: u1000, LTV-BORROW: u2000, LTV-LIQ-PARTIAL: u4000, LTV-LIQ-FULL: u5500 }))
    ;; Group 25: stSTXbtc to stSTX+STX (80% LTV)
    (try! (contract-call? .st-egroup insert { BORROW-DISABLED-MASK: u0, MASK: u92233720368547759104, LIQ-CURVE-EXP: u10000, LIQ-PENALTY-MIN: u500, LIQ-PENALTY-MAX: u1000, LTV-BORROW: u8000, LTV-LIQ-PARTIAL: u9000, LTV-LIQ-FULL: u9500 }))

    ;; STEP 5: SET INTEREST RATES
    
    (try! (contract-call? .st-vault-stx set-points-util UTIL-POINTS))
    (try! (contract-call? .st-vault-stx set-points-rate RATE-POINTS))
    (try! (contract-call? .st-vault-stx set-fee-reserve RESERVE-FACTOR))
    (try! (contract-call? .st-vault-sbtc set-points-util UTIL-POINTS))
    (try! (contract-call? .st-vault-sbtc set-points-rate RATE-POINTS))
    (try! (contract-call? .st-vault-sbtc set-fee-reserve RESERVE-FACTOR))
    (try! (contract-call? .st-vault-ststx set-points-util UTIL-POINTS))
    (try! (contract-call? .st-vault-ststx set-points-rate RATE-POINTS))
    (try! (contract-call? .st-vault-ststx set-fee-reserve RESERVE-FACTOR))
    (try! (contract-call? .st-vault-usdc set-points-util UTIL-POINTS))
    (try! (contract-call? .st-vault-usdc set-points-rate RATE-POINTS))
    (try! (contract-call? .st-vault-usdc set-fee-reserve RESERVE-FACTOR))
    (try! (contract-call? .st-vault-usdh set-points-util UTIL-POINTS))
    (try! (contract-call? .st-vault-usdh set-points-rate RATE-POINTS))
    (try! (contract-call? .st-vault-usdh set-fee-reserve RESERVE-FACTOR))
    
    (ok true)))
