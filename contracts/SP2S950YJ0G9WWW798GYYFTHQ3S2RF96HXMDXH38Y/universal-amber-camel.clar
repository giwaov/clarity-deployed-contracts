(use-trait ft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)

(define-constant ERR_MIN_PROFIT (err u6001))
(define-constant ERR_SWAP1      (err u6002))
(define-constant ERR_SWAP2      (err u6003))

(define-private (assert-min-profit (amount-in uint) (amount-out uint) (min-profit uint))
  (if (>= amount-out (+ amount-in min-profit)) (ok true) ERR_MIN_PROFIT)
)

(define-private (make-result (route (string-ascii 64)) (amount-in uint) (out1 uint) (out2 uint))
  {
    out1: out1,
    out2: out2,
    profit: (to-int (- out2 amount-in)),
    route: route,
    start: tx-sender,
  }
)

;; ---------------------------------------------------------------------
;; STX/aeUSDC: Bitflow XYK <-> Velar V1 AMM (poolId=6)
;; ---------------------------------------------------------------------

(define-constant BITFLOW_XYK_POOL_STX_AEUSDC 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-aeusdc-v-1-2)
(define-constant BITFLOW_TOKEN_STX 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2)
(define-constant TOKEN_AEUSDC 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc)

(define-constant VELAR_V1_POOL_ID u6)
(define-constant VELAR_WSTX 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx)
(define-constant VELAR_SHARE_FEE_TO 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to)

(define-public (exec-stx-aeusdc__bitflow_to_velar_v1
    (start-is-stx bool)
    (amount-in uint)
    (min-out-bitflow uint)
    (velar-amt-out uint)
    (min-profit uint))
  (let (
    (out1 (unwrap! (if start-is-stx
                      (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2 swap-x-for-y BITFLOW_XYK_POOL_STX_AEUSDC BITFLOW_TOKEN_STX TOKEN_AEUSDC amount-in min-out-bitflow)
                      (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2 swap-y-for-x BITFLOW_XYK_POOL_STX_AEUSDC BITFLOW_TOKEN_STX TOKEN_AEUSDC amount-in min-out-bitflow))
                  ERR_SWAP1))
    (e2 (unwrap! (if start-is-stx
                    (contract-call? 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-core swap VELAR_V1_POOL_ID TOKEN_AEUSDC VELAR_WSTX VELAR_SHARE_FEE_TO out1 velar-amt-out)
                    (contract-call? 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-core swap VELAR_V1_POOL_ID VELAR_WSTX TOKEN_AEUSDC VELAR_SHARE_FEE_TO out1 velar-amt-out))
                ERR_SWAP2))
    (out2 (get amt-out e2))
  )
    (try! (assert-min-profit amount-in out2 min-profit))
    (print { op: "amm-exec", route: "STX/aeUSDC:bitflow->velar-v1", in: amount-in, out1: out1, out2: out2 })
    (ok (make-result "STX/aeUSDC:bitflow->velar-v1" amount-in out1 out2))
  )
)

(define-public (exec-stx-aeusdc__velar_v1_to_bitflow
    (start-is-stx bool)
    (amount-in uint)
    (velar-amt-out uint)
    (min-out-bitflow uint)
    (min-profit uint))
  (let (
    (e1 (unwrap! (if start-is-stx
                    (contract-call? 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-core swap VELAR_V1_POOL_ID VELAR_WSTX TOKEN_AEUSDC VELAR_SHARE_FEE_TO amount-in velar-amt-out)
                    (contract-call? 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-core swap VELAR_V1_POOL_ID TOKEN_AEUSDC VELAR_WSTX VELAR_SHARE_FEE_TO amount-in velar-amt-out))
                ERR_SWAP1))
    (out1 (get amt-out e1))
    (out2 (unwrap! (if start-is-stx
                      (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2 swap-y-for-x BITFLOW_XYK_POOL_STX_AEUSDC BITFLOW_TOKEN_STX TOKEN_AEUSDC out1 min-out-bitflow)
                      (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2 swap-x-for-y BITFLOW_XYK_POOL_STX_AEUSDC BITFLOW_TOKEN_STX TOKEN_AEUSDC out1 min-out-bitflow))
                  ERR_SWAP2))
  )
    (try! (assert-min-profit amount-in out2 min-profit))
    (print { op: "amm-exec", route: "STX/aeUSDC:velar-v1->bitflow", in: amount-in, out1: out1, out2: out2 })
    (ok (make-result "STX/aeUSDC:velar-v1->bitflow" amount-in out1 out2))
  )
)

;; ---------------------------------------------------------------------
;; sBTC/STX: Bitflow XYK <-> Velar Univ2 pool
;; ---------------------------------------------------------------------

(define-constant BITFLOW_XYK_POOL_SBTC_STX 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-stx-v-1-1)
(define-constant TOKEN_SBTC 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token)

(define-constant VELAR_UNIV2_POOL_SBTC_STX 'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0070)
(define-constant VELAR_UNIV2_FEES_SBTC_STX 'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-fees-v1_0_0-0070)

(define-public (exec-sbtc-stx__bitflow_to_velar_univ2
    (start-is-sbtc bool)
    (amount-in uint)
    (min-out-bitflow uint)
    (min-out-velar uint)
    (min-profit uint))
  (let (
    (out1 (unwrap! (if start-is-sbtc
                      (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2 swap-x-for-y BITFLOW_XYK_POOL_SBTC_STX TOKEN_SBTC BITFLOW_TOKEN_STX amount-in min-out-bitflow)
                      (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2 swap-y-for-x BITFLOW_XYK_POOL_SBTC_STX TOKEN_SBTC BITFLOW_TOKEN_STX amount-in min-out-bitflow))
                  ERR_SWAP1))
    (e2 (unwrap! (if start-is-sbtc
                    (contract-call? 'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0070 swap VELAR_WSTX TOKEN_SBTC VELAR_UNIV2_FEES_SBTC_STX out1 min-out-velar)
                    (contract-call? 'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0070 swap TOKEN_SBTC VELAR_WSTX VELAR_UNIV2_FEES_SBTC_STX out1 min-out-velar))
                ERR_SWAP2))
    (out2 (get amt-out e2))
  )
    (try! (assert-min-profit amount-in out2 min-profit))
    (print { op: "amm-exec", route: "sBTC/STX:bitflow->velar-univ2", in: amount-in, out1: out1, out2: out2 })
    (ok (make-result "sBTC/STX:bitflow->velar-univ2" amount-in out1 out2))
  )
)

(define-public (exec-sbtc-stx__velar_univ2_to_bitflow
    (start-is-sbtc bool)
    (amount-in uint)
    (min-out-velar uint)
    (min-out-bitflow uint)
    (min-profit uint))
  (let (
    (e1 (unwrap! (if start-is-sbtc
                    (contract-call? 'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0070 swap TOKEN_SBTC VELAR_WSTX VELAR_UNIV2_FEES_SBTC_STX amount-in min-out-velar)
                    (contract-call? 'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0070 swap VELAR_WSTX TOKEN_SBTC VELAR_UNIV2_FEES_SBTC_STX amount-in min-out-velar))
                ERR_SWAP1))
    (out1 (get amt-out e1))
    (out2 (unwrap! (if start-is-sbtc
                      (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2 swap-y-for-x BITFLOW_XYK_POOL_SBTC_STX TOKEN_SBTC BITFLOW_TOKEN_STX out1 min-out-bitflow)
                      (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2 swap-x-for-y BITFLOW_XYK_POOL_SBTC_STX TOKEN_SBTC BITFLOW_TOKEN_STX out1 min-out-bitflow))
                  ERR_SWAP2))
  )
    (try! (assert-min-profit amount-in out2 min-profit))
    (print { op: "amm-exec", route: "sBTC/STX:velar-univ2->bitflow", in: amount-in, out1: out1, out2: out2 })
    (ok (make-result "sBTC/STX:velar-univ2->bitflow" amount-in out1 out2))
  )
)

;; ---------------------------------------------------------------------
;; USDh/aeUSDC: Bitflow StableSwap <-> Velar Curve pool
;; ---------------------------------------------------------------------

(define-constant BITFLOW_STABLESWAP_POOL_AEUSDC_USDH 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-aeusdc-usdh-v-1-2)
(define-constant TOKEN_USDH 'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.usdh-token-v1)

(define-constant VELAR_CURVE_POOL_USDH_AEUSDC 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.curve-pool-v1_1_0-0001)
(define-constant VELAR_CURVE_FEES_USDH_AEUSDC 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.curve-fees-v1_1_0-0001)

(define-public (exec-usdh-aeusdc__bitflow_to_velar_curve
    (start-is-usdh bool)
    (amount-in uint)
    (min-out-bitflow uint)
    (min-out-velar uint)
    (min-profit uint))
  (let (
    (out1 (unwrap! (if start-is-usdh
                      (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-core-v-1-2 swap-y-for-x BITFLOW_STABLESWAP_POOL_AEUSDC_USDH TOKEN_AEUSDC TOKEN_USDH amount-in min-out-bitflow)
                      (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-core-v-1-2 swap-x-for-y BITFLOW_STABLESWAP_POOL_AEUSDC_USDH TOKEN_AEUSDC TOKEN_USDH amount-in min-out-bitflow))
                  ERR_SWAP1))
    (e2 (unwrap! (if start-is-usdh
                    (contract-call? 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.curve-pool-v1_1_0-0001 swap TOKEN_AEUSDC TOKEN_USDH VELAR_CURVE_FEES_USDH_AEUSDC out1 min-out-velar)
                    (contract-call? 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.curve-pool-v1_1_0-0001 swap TOKEN_USDH TOKEN_AEUSDC VELAR_CURVE_FEES_USDH_AEUSDC out1 min-out-velar))
                ERR_SWAP2))
    (out2 (get amt-out e2))
  )
    (try! (assert-min-profit amount-in out2 min-profit))
    (print { op: "amm-exec", route: "USDh/aeUSDC:bitflow->velar-curve", in: amount-in, out1: out1, out2: out2 })
    (ok (make-result "USDh/aeUSDC:bitflow->velar-curve" amount-in out1 out2))
  )
)

(define-public (exec-usdh-aeusdc__velar_curve_to_bitflow
    (start-is-usdh bool)
    (amount-in uint)
    (min-out-velar uint)
    (min-out-bitflow uint)
    (min-profit uint))
  (let (
    (e1 (unwrap! (if start-is-usdh
                    (contract-call? 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.curve-pool-v1_1_0-0001 swap TOKEN_USDH TOKEN_AEUSDC VELAR_CURVE_FEES_USDH_AEUSDC amount-in min-out-velar)
                    (contract-call? 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.curve-pool-v1_1_0-0001 swap TOKEN_AEUSDC TOKEN_USDH VELAR_CURVE_FEES_USDH_AEUSDC amount-in min-out-velar))
                ERR_SWAP1))
    (out1 (get amt-out e1))
    (out2 (unwrap! (if start-is-usdh
                      (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-core-v-1-2 swap-x-for-y BITFLOW_STABLESWAP_POOL_AEUSDC_USDH TOKEN_AEUSDC TOKEN_USDH out1 min-out-bitflow)
                      (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-core-v-1-2 swap-y-for-x BITFLOW_STABLESWAP_POOL_AEUSDC_USDH TOKEN_AEUSDC TOKEN_USDH out1 min-out-bitflow))
                  ERR_SWAP2))
  )
    (try! (assert-min-profit amount-in out2 min-profit))
    (print { op: "amm-exec", route: "USDh/aeUSDC:velar-curve->bitflow", in: amount-in, out1: out1, out2: out2 })
    (ok (make-result "USDh/aeUSDC:velar-curve->bitflow" amount-in out1 out2))
  )
)
