;; Mainnet Proposal: Initialize All Assets
;; This proposal registers all underlying tokens and their ztoken equivalents
;; with production oracle configurations and enables them for collateral/debt

(impl-trait .staging-dao-traits-v0.proposal-script)

;; Oracle type constants
(define-constant TYPE-PYTH 0x00)
(define-constant TYPE-DIA 0x01)

;; Callcode constants for price transformations
(define-constant CALLCODE-STSTX 0x00)   ;; stSTX ratio adjustment
(define-constant CALLCODE-ZSTX 0x01)    ;; zSTX vault share conversion
(define-constant CALLCODE-ZSBTC 0x02)   ;; zsBTC vault share conversion
(define-constant CALLCODE-ZSTSTX 0x03)  ;; zstSTX vault share conversion
(define-constant CALLCODE-ZUSDC 0x04)   ;; zUSDC vault share conversion
(define-constant CALLCODE-ZUSDH 0x05)   ;; zUSDh vault share conversion

;; Mainnet Pyth price feed IDs
(define-constant STX-FEED-ID 0xec7a775f46379b5e943c3526b1c8d54cd49749176b0b98e02dde68d1bd335c17)
(define-constant BTC-FEED-ID 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43)
(define-constant USDC-FEED-ID 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a)
(define-constant STSTXBTC-FEED-ID 0xec7a775f46379b5e943c3526b1c8d54cd49749176b0b98e02dde68d1bd335c17)

;; USDh uses DIA oracle - key as consensus buffer
(define-constant USDH-DIA-KEY "USDh/USD")

;; Production staleness threshold: 120 seconds (2 minutes)
(define-constant MAX-STALENESS u120)

;; Mainnet token contract references
(define-constant SBTC-TOKEN 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token)
(define-constant STSTX-TOKEN 'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststx-token)
(define-constant USDC-TOKEN 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc)
(define-constant USDH-TOKEN 'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.usdh-token-v1)
(define-constant STSTXBTC-TOKEN 'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststxbtc-token)

(define-public (execute)
  (begin
    ;; =========================================================================
    ;; UNDERLYING TOKEN REGISTRATION
    ;; IMPORTANT: Registration order MUST match vault routing constants in market.clar
    ;; market.clar constants: STX=0, SBTC=1, STSTX=2, USDC=3, USDH=4
    ;; =========================================================================
    
    ;; Asset ID 0: wSTX (wrapped STX)
    (try! (contract-call? .staging-assets-v0 insert 
      .staging-wstx-v0
      {
        type: TYPE-PYTH,
        ident: STX-FEED-ID,
        callcode: none,
        max-staleness: MAX-STALENESS
      }))
    
    ;; Asset ID 1: sBTC (Bitcoin on Stacks)
    (try! (contract-call? .staging-assets-v0 insert 
      SBTC-TOKEN
      {
        type: TYPE-PYTH,
        ident: BTC-FEED-ID,
        callcode: none,
        max-staleness: MAX-STALENESS
      }))
    
    ;; Asset ID 2: stSTX (Lido stacked STX)
    ;; Uses STX price feed with callcode for ratio adjustment
    (try! (contract-call? .staging-assets-v0 insert 
      STSTX-TOKEN
      {
        type: TYPE-PYTH,
        ident: STX-FEED-ID,
        callcode: (some CALLCODE-STSTX),
        max-staleness: MAX-STALENESS
      }))
    
    ;; Asset ID 3: USDC (bridged USDC - aeUSDC)
    (try! (contract-call? .staging-assets-v0 insert 
      USDC-TOKEN
      {
        type: TYPE-PYTH,
        ident: USDC-FEED-ID,
        callcode: none,
        max-staleness: MAX-STALENESS
      }))
    
    ;; Asset ID 4: USDh (Hermetica stablecoin)
    ;; Uses DIA oracle instead of Pyth
    (try! (contract-call? .staging-assets-v0 insert 
      USDH-TOKEN
      {
        type: TYPE-DIA,
        ident: (unwrap-panic (to-consensus-buff? USDH-DIA-KEY)),
        callcode: none,
        max-staleness: MAX-STALENESS
      }))
    
    ;; =========================================================================
    ;; ZTOKEN (VAULT SHARE) REGISTRATION
    ;; Asset IDs 5-9: Vault shares for each underlying
    ;; These use callcodes to convert share prices to underlying value
    ;; =========================================================================
    
    ;; Asset ID 5: zSTX (vault-stx shares)
    (try! (contract-call? .staging-assets-v0 insert 
      .staging-vault-stx-v0
      {
        type: TYPE-PYTH,
        ident: STX-FEED-ID,
        callcode: (some CALLCODE-ZSTX),
        max-staleness: MAX-STALENESS
      }))
    
    ;; Asset ID 6: zsBTC (vault-sbtc shares)
    (try! (contract-call? .staging-assets-v0 insert 
      .staging-vault-sbtc-v0
      {
        type: TYPE-PYTH,
        ident: BTC-FEED-ID,
        callcode: (some CALLCODE-ZSBTC),
        max-staleness: MAX-STALENESS
      }))
    
    ;; Asset ID 7: zstSTX (vault-ststx shares)
    ;; Uses STX feed with stSTX ratio and vault share conversion
    (try! (contract-call? .staging-assets-v0 insert 
      .staging-vault-ststx-v0
      {
        type: TYPE-PYTH,
        ident: STX-FEED-ID,
        callcode: (some CALLCODE-ZSTSTX),
        max-staleness: MAX-STALENESS
      }))
    
    ;; Asset ID 8: zUSDC (vault-usdc shares)
    (try! (contract-call? .staging-assets-v0 insert 
      .staging-vault-usdc-v0
      {
        type: TYPE-PYTH,
        ident: USDC-FEED-ID,
        callcode: (some CALLCODE-ZUSDC),
        max-staleness: MAX-STALENESS
      }))
    
    ;; Asset ID 9: zUSDh (vault-usdh shares)
    ;; Uses DIA oracle with vault share conversion
    (try! (contract-call? .staging-assets-v0 insert 
      .staging-vault-usdh-v0
      {
        type: TYPE-DIA,
        ident: (unwrap-panic (to-consensus-buff? USDH-DIA-KEY)),
        callcode: (some CALLCODE-ZUSDH),
        max-staleness: MAX-STALENESS
      }))
    
    ;; =========================================================================
    ;; ADDITIONAL COLLATERAL TOKENS
    ;; Asset ID 10+: Special collateral-only tokens
    ;; =========================================================================
    
    ;; Asset ID 10: stSTXbtc (Stacked STX BTC)
    ;; Uses STX price feed, collateral only
    (try! (contract-call? .staging-assets-v0 insert 
      STSTXBTC-TOKEN
      {
        type: TYPE-PYTH,
        ident: STSTXBTC-FEED-ID,
        callcode: none,
        max-staleness: MAX-STALENESS
      }))
    
    ;; =========================================================================
    ;; ENABLE ASSETS FOR COLLATERAL AND DEBT
    ;; =========================================================================
    
    ;; Enable underlying tokens for both collateral (true) and debt (false)
    (try! (contract-call? .staging-assets-v0 enable .staging-wstx-v0 true))
    (try! (contract-call? .staging-assets-v0 enable .staging-wstx-v0 false))
    (try! (contract-call? .staging-assets-v0 enable SBTC-TOKEN true))
    (try! (contract-call? .staging-assets-v0 enable SBTC-TOKEN false))
    (try! (contract-call? .staging-assets-v0 enable STSTX-TOKEN true))
    (try! (contract-call? .staging-assets-v0 enable STSTX-TOKEN false))
    (try! (contract-call? .staging-assets-v0 enable USDC-TOKEN true))
    (try! (contract-call? .staging-assets-v0 enable USDC-TOKEN false))
    (try! (contract-call? .staging-assets-v0 enable USDH-TOKEN true))
    (try! (contract-call? .staging-assets-v0 enable USDH-TOKEN false))
    
    ;; Enable ztokens for collateral only (no debt positions with vault shares)
    (try! (contract-call? .staging-assets-v0 enable .staging-vault-stx-v0 true))
    (try! (contract-call? .staging-assets-v0 enable .staging-vault-sbtc-v0 true))
    (try! (contract-call? .staging-assets-v0 enable .staging-vault-ststx-v0 true))
    (try! (contract-call? .staging-assets-v0 enable .staging-vault-usdc-v0 true))
    (try! (contract-call? .staging-assets-v0 enable .staging-vault-usdh-v0 true))
    
    ;; Enable stSTXbtc for collateral only
    (try! (contract-call? .staging-assets-v0 enable STSTXBTC-TOKEN true))
    
    (ok true)))
