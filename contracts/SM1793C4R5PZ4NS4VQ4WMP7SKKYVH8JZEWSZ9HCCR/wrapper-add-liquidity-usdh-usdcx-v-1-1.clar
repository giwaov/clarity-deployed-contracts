
;; wrapper-add-liquidity-usdh-usdcx-v-1-1

(define-public (add-liquidity
    (x-amount uint) (y-amount uint) (min-dlp uint)
  )
  (let (
    (unfreeze-pool-result (try! (as-contract (contract-call? .stableswap-core-v-1-4 set-pool-status
                                             .stableswap-pool-usdh-usdcx-v-1-1 true))))
    (add-liquidity-result (try! (contract-call? .stableswap-core-v-1-4 add-liquidity
                                .stableswap-pool-usdh-usdcx-v-1-1
                                'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.usdh-token-v1
                                'SP120SBRBQJ00MCWS7TM5R8WJNTTKD5K0HFRC2CNE.usdcx
                                x-amount y-amount min-dlp)))
    (freeze-pool-result (try! (as-contract (contract-call? .stableswap-core-v-1-4 set-pool-status
                                           .stableswap-pool-usdh-usdcx-v-1-1 false))))
  )
    (ok {
      unfreeze-pool-result: unfreeze-pool-result,
      add-liquidity-result: add-liquidity-result,
      freeze-pool-result: freeze-pool-result
    })
  )
)