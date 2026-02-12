;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; protocol-data - read-only utility contract
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Provides optimized read-only functions to query protocol state
;; Batches related data to minimize cross-contract call overhead

;; ============================================================================
;; CONSTANTS
;; ============================================================================

;; -- Vault routing IDs
(define-constant STX u0)
(define-constant sBTC u1)
(define-constant stSTX u2)
(define-constant USDC u3)
(define-constant USDH u4)

;; -- ZToken asset IDs (for collateral)
(define-constant zSTX u5)
(define-constant zsBTC u6)
(define-constant zstSTX u7)
(define-constant zUSDC u8)
(define-constant zUSDH u9)

;; -- Precision
(define-constant BPS u10000)
(define-constant INDEX-PRECISION u1000000000000)

;; -- Iteration helpers
(define-constant VAULT-IDS (list u0 u1 u2 u3 u4))
(define-constant ITER-UINT-128 (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20 u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34 u35 u36 u37 u38 u39 u40 u41 u42 u43 u44 u45 u46 u47 u48 u49 u50 u51 u52 u53 u54 u55 u56 u57 u58 u59 u60 u61 u62 u63 u64 u65 u66 u67 u68 u69 u70 u71 u72 u73 u74 u75 u76 u77 u78 u79 u80 u81 u82 u83 u84 u85 u86 u87 u88 u89 u90 u91 u92 u93 u94 u95 u96 u97 u98 u99 u100 u101 u102 u103 u104 u105 u106 u107 u108 u109 u110 u111 u112 u113 u114 u115 u116 u117 u118 u119 u120 u121 u122 u123 u124 u125 u126 u127))

;; -- Underlying contract addresses
(define-constant UNDERLYING-STX  .staging-wstx-v0)
(define-constant UNDERLYING-SBTC 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token)
(define-constant UNDERLYING-STSTX 'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststx-token)
(define-constant UNDERLYING-USDC 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc)
(define-constant UNDERLYING-USDH 'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.usdh-token-v1)
(define-constant UNDERLYING-STSTXBTC 'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststxbtc-token)

;; ============================================================================
;; ERRORS
;; ============================================================================
(define-constant ERR-UNKNOWN-VAULT (err u900001))
(define-constant ERR-UNKNOWN-UNDERLYING (err u900002))
(define-constant ERR-NO-POSITION (err u900003))

;; ============================================================================
;; PRIVATE FUNCTIONS
;; ============================================================================

;; -- Math utilities ---------------------------------------------------------

(define-private (mul-div-down (x uint) (y uint) (z uint))
  (/ (* x y) z))

(define-private (mul-bps-down (x uint) (y uint))
  (/ (* x y) BPS))

;; -- Vault routing: get interest rate --------------------------------------

(define-private (get-vault-interest-rate (vid uint))
  (if (is-eq vid STX) (unwrap-panic (contract-call? .staging-vault-stx-v0 get-interest-rate))
  (if (is-eq vid sBTC) (unwrap-panic (contract-call? .staging-vault-sbtc-v0 get-interest-rate))
  (if (is-eq vid stSTX) (unwrap-panic (contract-call? .staging-vault-ststx-v0 get-interest-rate))
  (if (is-eq vid USDC) (unwrap-panic (contract-call? .staging-vault-usdc-v0 get-interest-rate))
  (if (is-eq vid USDH) (unwrap-panic (contract-call? .staging-vault-usdh-v0 get-interest-rate))
  u0))))))

;; -- Vault routing: get utilization -----------------------------------------

(define-private (get-vault-utilization (vid uint))
  (if (is-eq vid STX) (unwrap-panic (contract-call? .staging-vault-stx-v0 get-utilization))
  (if (is-eq vid sBTC) (unwrap-panic (contract-call? .staging-vault-sbtc-v0 get-utilization))
  (if (is-eq vid stSTX) (unwrap-panic (contract-call? .staging-vault-ststx-v0 get-utilization))
  (if (is-eq vid USDC) (unwrap-panic (contract-call? .staging-vault-usdc-v0 get-utilization))
  (if (is-eq vid USDH) (unwrap-panic (contract-call? .staging-vault-usdh-v0 get-utilization))
  u0))))))

;; -- Vault routing: get fee reserve -----------------------------------------

(define-private (get-vault-fee-reserve (vid uint))
  (if (is-eq vid STX) (unwrap-panic (contract-call? .staging-vault-stx-v0 get-fee-reserve))
  (if (is-eq vid sBTC) (unwrap-panic (contract-call? .staging-vault-sbtc-v0 get-fee-reserve))
  (if (is-eq vid stSTX) (unwrap-panic (contract-call? .staging-vault-ststx-v0 get-fee-reserve))
  (if (is-eq vid USDC) (unwrap-panic (contract-call? .staging-vault-usdc-v0 get-fee-reserve))
  (if (is-eq vid USDH) (unwrap-panic (contract-call? .staging-vault-usdh-v0 get-fee-reserve))
  u0))))))

;; -- Vault routing: get total assets ----------------------------------------

(define-private (get-vault-total-assets (vid uint))
  (if (is-eq vid STX) (unwrap-panic (contract-call? .staging-vault-stx-v0 get-total-assets))
  (if (is-eq vid sBTC) (unwrap-panic (contract-call? .staging-vault-sbtc-v0 get-total-assets))
  (if (is-eq vid stSTX) (unwrap-panic (contract-call? .staging-vault-ststx-v0 get-total-assets))
  (if (is-eq vid USDC) (unwrap-panic (contract-call? .staging-vault-usdc-v0 get-total-assets))
  (if (is-eq vid USDH) (unwrap-panic (contract-call? .staging-vault-usdh-v0 get-total-assets))
  u0))))))

;; -- Vault routing: get debt ------------------------------------------------

(define-private (get-vault-debt (vid uint))
  (if (is-eq vid STX) (unwrap-panic (contract-call? .staging-vault-stx-v0 get-debt))
  (if (is-eq vid sBTC) (unwrap-panic (contract-call? .staging-vault-sbtc-v0 get-debt))
  (if (is-eq vid stSTX) (unwrap-panic (contract-call? .staging-vault-ststx-v0 get-debt))
  (if (is-eq vid USDC) (unwrap-panic (contract-call? .staging-vault-usdc-v0 get-debt))
  (if (is-eq vid USDH) (unwrap-panic (contract-call? .staging-vault-usdh-v0 get-debt))
  u0))))))

;; -- Vault routing: get total supply ----------------------------------------

(define-private (get-vault-total-supply (vid uint))
  (if (is-eq vid STX) (unwrap-panic (contract-call? .staging-vault-stx-v0 get-total-supply))
  (if (is-eq vid sBTC) (unwrap-panic (contract-call? .staging-vault-sbtc-v0 get-total-supply))
  (if (is-eq vid stSTX) (unwrap-panic (contract-call? .staging-vault-ststx-v0 get-total-supply))
  (if (is-eq vid USDC) (unwrap-panic (contract-call? .staging-vault-usdc-v0 get-total-supply))
  (if (is-eq vid USDH) (unwrap-panic (contract-call? .staging-vault-usdh-v0 get-total-supply))
  u0))))))

;; -- Vault routing: get borrow index ----------------------------------------

(define-private (get-vault-borrow-index (vid uint))
  (if (is-eq vid STX) (unwrap-panic (contract-call? .staging-vault-stx-v0 get-index))
  (if (is-eq vid sBTC) (unwrap-panic (contract-call? .staging-vault-sbtc-v0 get-index))
  (if (is-eq vid stSTX) (unwrap-panic (contract-call? .staging-vault-ststx-v0 get-index))
  (if (is-eq vid USDC) (unwrap-panic (contract-call? .staging-vault-usdc-v0 get-index))
  (if (is-eq vid USDH) (unwrap-panic (contract-call? .staging-vault-usdh-v0 get-index))
  INDEX-PRECISION))))))

;; -- Vault routing: get liquidity index -------------------------------------

(define-private (get-vault-liquidity-index (vid uint))
  (if (is-eq vid STX) (unwrap-panic (contract-call? .staging-vault-stx-v0 get-liquidity-index))
  (if (is-eq vid sBTC) (unwrap-panic (contract-call? .staging-vault-sbtc-v0 get-liquidity-index))
  (if (is-eq vid stSTX) (unwrap-panic (contract-call? .staging-vault-ststx-v0 get-liquidity-index))
  (if (is-eq vid USDC) (unwrap-panic (contract-call? .staging-vault-usdc-v0 get-liquidity-index))
  (if (is-eq vid USDH) (unwrap-panic (contract-call? .staging-vault-usdh-v0 get-liquidity-index))
  INDEX-PRECISION))))))

;; -- Vault routing: get cap supply ------------------------------------------

(define-private (get-vault-cap-supply (vid uint))
  (if (is-eq vid STX) (unwrap-panic (contract-call? .staging-vault-stx-v0 get-cap-supply))
  (if (is-eq vid sBTC) (unwrap-panic (contract-call? .staging-vault-sbtc-v0 get-cap-supply))
  (if (is-eq vid stSTX) (unwrap-panic (contract-call? .staging-vault-ststx-v0 get-cap-supply))
  (if (is-eq vid USDC) (unwrap-panic (contract-call? .staging-vault-usdc-v0 get-cap-supply))
  (if (is-eq vid USDH) (unwrap-panic (contract-call? .staging-vault-usdh-v0 get-cap-supply))
  u0))))))

;; -- Vault routing: get cap debt --------------------------------------------

(define-private (get-vault-cap-debt (vid uint))
  (if (is-eq vid STX) (unwrap-panic (contract-call? .staging-vault-stx-v0 get-cap-debt))
  (if (is-eq vid sBTC) (unwrap-panic (contract-call? .staging-vault-sbtc-v0 get-cap-debt))
  (if (is-eq vid stSTX) (unwrap-panic (contract-call? .staging-vault-ststx-v0 get-cap-debt))
  (if (is-eq vid USDC) (unwrap-panic (contract-call? .staging-vault-usdc-v0 get-cap-debt))
  (if (is-eq vid USDH) (unwrap-panic (contract-call? .staging-vault-usdh-v0 get-cap-debt))
  u0))))))

;; -- Vault routing: get last update -----------------------------------------

(define-private (get-vault-last-update (vid uint))
  (if (is-eq vid STX) (unwrap-panic (contract-call? .staging-vault-stx-v0 get-last-update))
  (if (is-eq vid sBTC) (unwrap-panic (contract-call? .staging-vault-sbtc-v0 get-last-update))
  (if (is-eq vid stSTX) (unwrap-panic (contract-call? .staging-vault-ststx-v0 get-last-update))
  (if (is-eq vid USDC) (unwrap-panic (contract-call? .staging-vault-usdc-v0 get-last-update))
  (if (is-eq vid USDH) (unwrap-panic (contract-call? .staging-vault-usdh-v0 get-last-update))
  u0))))))

;; -- Vault routing: get points util -----------------------------------------

(define-private (get-vault-points-util (vid uint))
  (if (is-eq vid STX) (unwrap-panic (contract-call? .staging-vault-stx-v0 get-points-util))
  (if (is-eq vid sBTC) (unwrap-panic (contract-call? .staging-vault-sbtc-v0 get-points-util))
  (if (is-eq vid stSTX) (unwrap-panic (contract-call? .staging-vault-ststx-v0 get-points-util))
  (if (is-eq vid USDC) (unwrap-panic (contract-call? .staging-vault-usdc-v0 get-points-util))
  (if (is-eq vid USDH) (unwrap-panic (contract-call? .staging-vault-usdh-v0 get-points-util))
  (list u0 u0 u0 u0 u0 u0 u0 u0)))))))

;; -- Vault routing: get points rate -----------------------------------------

(define-private (get-vault-points-rate (vid uint))
  (if (is-eq vid STX) (unwrap-panic (contract-call? .staging-vault-stx-v0 get-points-rate))
  (if (is-eq vid sBTC) (unwrap-panic (contract-call? .staging-vault-sbtc-v0 get-points-rate))
  (if (is-eq vid stSTX) (unwrap-panic (contract-call? .staging-vault-ststx-v0 get-points-rate))
  (if (is-eq vid USDC) (unwrap-panic (contract-call? .staging-vault-usdc-v0 get-points-rate))
  (if (is-eq vid USDH) (unwrap-panic (contract-call? .staging-vault-usdh-v0 get-points-rate))
  (list u0 u0 u0 u0 u0 u0 u0 u0)))))))

;; -- Vault routing: convert shares to underlying assets ---------------------

(define-private (get-vault-underlying-balance (vid uint) (account principal))
  (if (is-eq vid STX)
      (let ((shares (unwrap-panic (contract-call? .staging-vault-stx-v0 get-balance account))))
        (unwrap-panic (contract-call? .staging-vault-stx-v0 convert-to-assets shares)))
  (if (is-eq vid sBTC)
      (let ((shares (unwrap-panic (contract-call? .staging-vault-sbtc-v0 get-balance account))))
        (unwrap-panic (contract-call? .staging-vault-sbtc-v0 convert-to-assets shares)))
  (if (is-eq vid stSTX)
      (let ((shares (unwrap-panic (contract-call? .staging-vault-ststx-v0 get-balance account))))
        (unwrap-panic (contract-call? .staging-vault-ststx-v0 convert-to-assets shares)))
  (if (is-eq vid USDC)
      (let ((shares (unwrap-panic (contract-call? .staging-vault-usdc-v0 get-balance account))))
        (unwrap-panic (contract-call? .staging-vault-usdc-v0 convert-to-assets shares)))
  (if (is-eq vid USDH)
      (let ((shares (unwrap-panic (contract-call? .staging-vault-usdh-v0 get-balance account))))
        (unwrap-panic (contract-call? .staging-vault-usdh-v0 convert-to-assets shares)))
  u0))))))

;; -- Vault routing: get underlying address ----------------------------------

(define-private (get-vault-underlying (vid uint))
  (if (is-eq vid STX) UNDERLYING-STX
  (if (is-eq vid sBTC) UNDERLYING-SBTC
  (if (is-eq vid stSTX) UNDERLYING-STSTX
  (if (is-eq vid USDC) UNDERLYING-USDC
  (if (is-eq vid USDH) UNDERLYING-USDH
  UNDERLYING-STX))))))

;; -- APY calculation --------------------------------------------------------

;; Supply APY = borrow_rate x utilization x (1 - reserve_fee / BPS)
(define-private (calc-supply-apy (borrow-rate uint) (utilization uint) (reserve-fee uint))
  (let ((util-applied (mul-bps-down borrow-rate utilization))
        (fee-factor (- BPS reserve-fee)))
    (mul-bps-down util-applied fee-factor)))

;; -- Underlying to vault ID mapping -----------------------------------------

(define-private (underlying-to-vault-id (underlying principal))
  (if (is-eq underlying UNDERLYING-STX) (ok STX)
  (if (is-eq underlying UNDERLYING-SBTC) (ok sBTC)
  (if (is-eq underlying UNDERLYING-STSTX) (ok stSTX)
  (if (is-eq underlying UNDERLYING-USDC) (ok USDC)
  (if (is-eq underlying UNDERLYING-USDH) (ok USDH)
  ERR-UNKNOWN-UNDERLYING))))))

;; -- Build single reserve data ----------------------------------------------

(define-private (build-reserve-data (vid uint))
  (let ((borrow-apy (get-vault-interest-rate vid))
        (utilization (get-vault-utilization vid))
        (fee-reserve (get-vault-fee-reserve vid))
        (supply-apy (calc-supply-apy borrow-apy utilization fee-reserve)))
    {
      vault-id: vid,
      underlying: (get-vault-underlying vid),
      total-assets: (get-vault-total-assets vid),
      total-borrowed: (get-vault-debt vid),
      total-supply: (get-vault-total-supply vid),
      utilization: utilization,
      borrow-index: (get-vault-borrow-index vid),
      liquidity-index: (get-vault-liquidity-index vid),
      cap-supply: (get-vault-cap-supply vid),
      cap-debt: (get-vault-cap-debt vid),
      fee-reserve: fee-reserve,
      last-update: (get-vault-last-update vid),
      borrow-apy: borrow-apy,
      supply-apy: supply-apy
    }))

;; -- Build single interest curve data ---------------------------------------

(define-private (build-interest-curve (vid uint))
  {
    vault-id: vid,
    underlying: (get-vault-underlying vid),
    points-util: (get-vault-points-util vid),
    points-rate: (get-vault-points-rate vid),
    current-rate: (get-vault-interest-rate vid)
  })

;; -- Asset iteration --------------------------------------------------------

(define-private (iter-build-asset (id uint) (acc { max-id: uint, result: (list 128 {
    id: uint,
    addr: principal,
    decimals: uint,
    collateral: bool,
    debt: bool,
    oracle-type: (buff 1),
    oracle-ident: (buff 32),
    oracle-callcode: (optional (buff 1)),
    max-staleness: uint
  }) }))
  (let ((max-id (get max-id acc)))
    (if (>= id max-id)
        acc
        (let ((asset-status (contract-call?  .staging-assets-v0 get-status id))
              (entry {
                id: id,
                addr: (get addr asset-status),
                decimals: (get decimals asset-status),
                collateral: (get collateral asset-status),
                debt: (get debt asset-status),
                oracle-type: (get type (get oracle asset-status)),
                oracle-ident: (get ident (get oracle asset-status)),
                oracle-callcode: (get callcode (get oracle asset-status)),
                max-staleness: (get max-staleness (get oracle asset-status))
              })
              (new-result (unwrap-panic (as-max-len? (append (get result acc) entry) u128))))
          { max-id: max-id, result: new-result }))))

;; -- Egroup iteration -------------------------------------------------------

(define-private (iter-build-egroup (id uint) (acc { max-id: uint, result: (list 128 {
    id: uint,
    mask: uint,
    ltv-borrow: uint,
    ltv-liq-partial: uint,
    ltv-liq-full: uint,
    liq-curve-exp: uint,
    liq-penalty-min: uint,
    liq-penalty-max: uint
  }) }))
  (let ((max-id (get max-id acc)))
    (if (>= id max-id)
        acc
        (let ((egroup-data (contract-call?  .staging-egroup-v0 lookup id))
              (entry {
                id: id,
                mask: (get MASK egroup-data),
                ltv-borrow: (buff-to-uint-be (get LTV-BORROW egroup-data)),
                ltv-liq-partial: (buff-to-uint-be (get LTV-LIQ-PARTIAL egroup-data)),
                ltv-liq-full: (buff-to-uint-be (get LTV-LIQ-FULL egroup-data)),
                liq-curve-exp: (buff-to-uint-be (get LIQ-CURVE-EXP egroup-data)),
                liq-penalty-min: (buff-to-uint-be (get LIQ-PENALTY-MIN egroup-data)),
                liq-penalty-max: (buff-to-uint-be (get LIQ-PENALTY-MAX egroup-data))
              })
              (new-result (unwrap-panic (as-max-len? (append (get result acc) entry) u128))))
          { max-id: max-id, result: new-result }))))

;; ============================================================================
;; READ-ONLY FUNCTIONS
;; ============================================================================

;; ---------------------------------------------------------------------------
;; get-user-position
;; ---------------------------------------------------------------------------
;; Returns complete user position with health data
;; Batches all position data into single response
(define-read-only (get-user-position (account principal))
  (let ((enabled-mask (contract-call?  .staging-assets-v0 get-bitmap)))
    (match (contract-call?  .staging-market-vault-v0 get-position account enabled-mask)
      position
        (let ((mask (get mask position))
              (collateral-list (get collateral position))
              (debt-list (get debt position))
              ;; Calculate notional values
              (coll-usd (fold sum-collateral-usd collateral-list u0))
              (debt-usd (fold sum-debt-usd debt-list u0))
              ;; Calculate LTV
              (current-ltv (if (is-eq coll-usd u0)
                              (if (is-eq debt-usd u0) u0 BPS)
                              (mul-div-down debt-usd BPS coll-usd)))
              ;; Get egroup for health calculation
              (egroup-result (contract-call?  .staging-egroup-v0 resolve mask)))
          (match egroup-result
            egroup
              (let ((ltv-borrow (buff-to-uint-be (get LTV-BORROW egroup)))
                    (ltv-liq-partial (buff-to-uint-be (get LTV-LIQ-PARTIAL egroup)))
                    ;; Health factor: (coll x ltv-borrow) / debt, scaled to BPS
                    ;; >10000 = healthy, <10000 = unhealthy
                    (health-factor (if (is-eq debt-usd u0)
                                      u100000000  ;; Infinite health if no debt
                                      (mul-div-down (mul-bps-down coll-usd ltv-borrow) BPS debt-usd))))
                (ok {
                  account: account,
                  mask: mask,
                  collateral: collateral-list,
                  debt: debt-list,
                  total-collateral-usd: coll-usd,
                  total-debt-usd: debt-usd,
                  current-ltv: current-ltv,
                  ltv-borrow: ltv-borrow,
                  ltv-liq-partial: ltv-liq-partial,
                  health-factor: health-factor,
                  is-liquidatable: (>= current-ltv ltv-liq-partial)
                }))
            egroup-err (ok {
              account: account,
              mask: mask,
              collateral: collateral-list,
              debt: debt-list,
              total-collateral-usd: coll-usd,
              total-debt-usd: debt-usd,
              current-ltv: current-ltv,
              ltv-borrow: u0,
              ltv-liq-partial: u0,
              health-factor: u100000000,
              is-liquidatable: false
            })))
      err-code ERR-NO-POSITION)))

;; Helper: Build enriched debt entry with actual balance
(define-private (build-debt-entry (debt-entry { aid: uint, scaled: uint }))
  (let ((aid (get aid debt-entry))
        (scaled (get scaled debt-entry))
        (asset-status (contract-call?  .staging-assets-v0 get-status aid))
        (borrow-index (get-vault-borrow-index aid))
        ;; Calculate actual debt with compound interest
        (actual (mul-div-down scaled borrow-index INDEX-PRECISION))
        ;; Interest accrued = actual - scaled (simplified, assumes initial index ~= PRECISION)
        (interest (if (> actual scaled) (- actual scaled) u0)))
    {
      asset-id: aid,
      asset-addr: (get addr asset-status),
      underlying: (get addr asset-status),
      scaled-debt: scaled,
      borrow-index: borrow-index,
      actual-debt: actual,
      interest-accrued: interest
    }))

;; Helper: Sum collateral USD values
(define-private (sum-collateral-usd (entry { aid: uint, amount: uint }) (acc uint))
  (let ((aid (get aid entry))
        (amount (get amount entry))
        (asset-data (contract-call?  .staging-assets-v0 get-status aid))
        (decimals (get decimals asset-data))
        (price (get-asset-price aid)))
    (+ acc (/ (* amount price) (pow u10 decimals)))))

;; Helper: Sum debt USD values
(define-private (sum-debt-usd (entry { aid: uint, scaled: uint }) (acc uint))
  (let ((aid (get aid entry))
        (scaled (get scaled entry))
        (asset-data (contract-call?  .staging-assets-v0 get-status aid))
        (decimals (get decimals asset-data))
        (borrow-index (get-vault-borrow-index aid))
        (actual (mul-div-down scaled borrow-index INDEX-PRECISION))
        (price (get-asset-price aid)))
    (+ acc (/ (* actual price) (pow u10 decimals)))))

;; Helper: Get asset price (simplified - returns cached/mock price)
(define-private (get-asset-price (aid uint))
  ;; Note: In production, this would call the oracle
  ;; For now, returns a placeholder that should be updated with actual oracle integration
  u100000000)  ;; $1 in 8 decimal precision

;; ---------------------------------------------------------------------------
;; get-all-assets
;; ---------------------------------------------------------------------------
;; Returns all registered assets with their status (dynamic - scales to nonce)
(define-read-only (get-all-assets)
  (let ((nonce (unwrap-panic (contract-call?  .staging-assets-v0 get-nonce)))
        (init { max-id: nonce, result: (list) })
        (result (fold iter-build-asset ITER-UINT-128 init)))
    (ok {
      count: nonce,
      assets: (get result result)
    })))

;; ---------------------------------------------------------------------------
;; get-all-reserves
;; ---------------------------------------------------------------------------
;; Returns all vault reserve data including APYs
(define-read-only (get-all-reserves)
  (ok {
    stx: (build-reserve-data STX),
    sbtc: (build-reserve-data sBTC),
    ststx: (build-reserve-data stSTX),
    usdc: (build-reserve-data USDC),
    usdh: (build-reserve-data USDH)
  }))

;; ---------------------------------------------------------------------------
;; get-reserve
;; ---------------------------------------------------------------------------
;; Returns single vault reserve data
(define-read-only (get-reserve (vid uint))
  (if (> vid USDH)
      ERR-UNKNOWN-VAULT
      (ok (build-reserve-data vid))))

;; ---------------------------------------------------------------------------
;; get-all-egroups
;; ---------------------------------------------------------------------------
;; Returns all efficiency groups
(define-read-only (get-all-egroups)
  (let ((nonce (unwrap-panic (contract-call?  .staging-egroup-v0 get-nonce)))
        (init { max-id: nonce, result: (list) })
        (result (fold iter-build-egroup ITER-UINT-128 init)))
    (ok {
      count: nonce,
      egroups: (get result result)
    })))

;; ---------------------------------------------------------------------------
;; get-egroup
;; ---------------------------------------------------------------------------
;; Returns single egroup by ID
(define-read-only (get-egroup (id uint))
  (let ((egroup-data (contract-call?  .staging-egroup-v0 lookup id)))
    (ok {
      id: id,
      mask: (get MASK egroup-data),
      ltv-borrow: (buff-to-uint-be (get LTV-BORROW egroup-data)),
      ltv-liq-partial: (buff-to-uint-be (get LTV-LIQ-PARTIAL egroup-data)),
      ltv-liq-full: (buff-to-uint-be (get LTV-LIQ-FULL egroup-data)),
      liq-curve-exp: (buff-to-uint-be (get LIQ-CURVE-EXP egroup-data)),
      liq-penalty-min: (buff-to-uint-be (get LIQ-PENALTY-MIN egroup-data)),
      liq-penalty-max: (buff-to-uint-be (get LIQ-PENALTY-MAX egroup-data))
    })))

;; ---------------------------------------------------------------------------
;; get-all-interest-curves
;; ---------------------------------------------------------------------------
;; Returns interest rate curves for all vaults
(define-read-only (get-all-interest-curves)
  (ok {
    stx: (build-interest-curve STX),
    sbtc: (build-interest-curve sBTC),
    ststx: (build-interest-curve stSTX),
    usdc: (build-interest-curve USDC),
    usdh: (build-interest-curve USDH)
  }))

;; ---------------------------------------------------------------------------
;; get-interest-curve
;; ---------------------------------------------------------------------------
;; Returns interest rate curve for single vault
(define-read-only (get-interest-curve (vid uint))
  (if (> vid USDH)
      ERR-UNKNOWN-VAULT
      (ok (build-interest-curve vid))))

;; ---------------------------------------------------------------------------
;; get-asset-apys
;; ---------------------------------------------------------------------------
;; Maps underlying asset to vault and returns APY data
;; Convenience function for quick APY lookup
(define-read-only (get-asset-apys (underlying principal))
  (match (underlying-to-vault-id underlying)
    vid
      (let ((borrow-apy (get-vault-interest-rate vid))
            (utilization (get-vault-utilization vid))
            (fee-reserve (get-vault-fee-reserve vid))
            (supply-apy (calc-supply-apy borrow-apy utilization fee-reserve)))
        (ok {
          underlying: underlying,
          vault-id: vid,
          borrow-apy: borrow-apy,
          supply-apy: supply-apy,
          utilization: utilization,
          fee-reserve: fee-reserve
        }))
    err-val (err err-val)))

;; ---------------------------------------------------------------------------
;; get-protocol-summary
;; ---------------------------------------------------------------------------
;; Returns high-level protocol summary
(define-read-only (get-protocol-summary)
  (let ((stx-data (build-reserve-data STX))
        (sbtc-data (build-reserve-data sBTC))
        (ststx-data (build-reserve-data stSTX))
        (usdc-data (build-reserve-data USDC))
        (usdh-data (build-reserve-data USDH)))
    (ok {
      total-supplied: (+ (+ (+ (+ 
        (get total-assets stx-data)
        (get total-assets sbtc-data))
        (get total-assets ststx-data))
        (get total-assets usdc-data))
        (get total-assets usdh-data)),
      total-borrowed: (+ (+ (+ (+
        (get total-borrowed stx-data)
        (get total-borrowed sbtc-data))
        (get total-borrowed ststx-data))
        (get total-borrowed usdc-data))
        (get total-borrowed usdh-data)),
      asset-count: (unwrap-panic (contract-call?  .staging-assets-v0 get-nonce)),
      egroup-count: (unwrap-panic (contract-call?  .staging-egroup-v0 get-nonce))
    })))

;; ---------------------------------------------------------------------------
;; get-supplies-user
;; ---------------------------------------------------------------------------
;; Returns all supplies for a user:
;; - Vault underlying balances (converted from zTokens - what user can redeem)
;; - Vault share balances (zTokens held in wallet - for reference)
;; - Market-vault collateral (any collateral-enabled tokens deposited)
(define-read-only (get-supplies-user (account principal))
  (let ((enabled-mask (contract-call?  .staging-assets-v0 get-bitmap))
        ;; Get underlying balances (convert zTokens to underlying - USEFUL)
        (stx-underlying (get-vault-underlying-balance STX account))
        (sbtc-underlying (get-vault-underlying-balance sBTC account))
        (ststx-underlying (get-vault-underlying-balance stSTX account))
        (usdc-underlying (get-vault-underlying-balance USDC account))
        (usdh-underlying (get-vault-underlying-balance USDH account))
        ;; Also get share balances for reference
        (vault-stx-shares (unwrap-panic (contract-call? .staging-vault-stx-v0 get-balance account)))
        (vault-sbtc-shares (unwrap-panic (contract-call? .staging-vault-sbtc-v0 get-balance account)))
        (vault-ststx-shares (unwrap-panic (contract-call? .staging-vault-ststx-v0 get-balance account)))
        (vault-usdc-shares (unwrap-panic (contract-call? .staging-vault-usdc-v0 get-balance account)))
        (vault-usdh-shares (unwrap-panic (contract-call? .staging-vault-usdh-v0 get-balance account))))
    ;; Try to get market-vault position (may not exist)
    (match (contract-call?  .staging-market-vault-v0 get-position account enabled-mask)
      position
        (ok {
          account: account,
          ;; Primary data: Underlying token values (what user can actually redeem)
          vault-underlying: {
            stx: stx-underlying,
            sbtc: sbtc-underlying,
            ststx: ststx-underlying,
            usdc: usdc-underlying,
            usdh: usdh-underlying
          },
          ;; Reference data: zToken share balances
          vault-shares: {
            stx: vault-stx-shares,
            sbtc: vault-sbtc-shares,
            ststx: vault-ststx-shares,
            usdc: vault-usdc-shares,
            usdh: vault-usdh-shares
          },
          ;; Market-vault collateral (any collateral-enabled tokens)
          market-collateral: (get collateral position)
        })
      err-code
        ;; No market-vault position exists - return vault data only
        (ok {
          account: account,
          vault-underlying: {
            stx: stx-underlying,
            sbtc: sbtc-underlying,
            ststx: ststx-underlying,
            usdc: usdc-underlying,
            usdh: usdh-underlying
          },
          vault-shares: {
            stx: vault-stx-shares,
            sbtc: vault-sbtc-shares,
            ststx: vault-ststx-shares,
            usdc: vault-usdc-shares,
            usdh: vault-usdh-shares
          },
          market-collateral: (list)
        }))))

;; ---------------------------------------------------------------------------
;; get-user-borrows
;; ---------------------------------------------------------------------------
;; Returns all borrows for a user with detailed debt information:
;; - Scaled debt (principal stored when borrowed)
;; - Current borrow index (includes compound interest growth)
;; - Actual debt (scaled x index - what user actually owes)
;; - Interest accrued (compound interest accumulated)
(define-read-only (get-user-borrows (account principal))
  (let ((enabled-mask (contract-call?  .staging-assets-v0 get-bitmap)))
    (match (contract-call?  .staging-market-vault-v0 get-position account enabled-mask)
      position
        (let ((debt-list (get debt position))
              ;; Map each debt entry to enriched format with actual balances
              (enriched-debts (map build-debt-entry debt-list)))
          (ok {
            account: account,
            borrows: enriched-debts
          }))
      err-code
        ;; No position exists
        (ok {
          account: account,
          borrows: (list)
        }))))
