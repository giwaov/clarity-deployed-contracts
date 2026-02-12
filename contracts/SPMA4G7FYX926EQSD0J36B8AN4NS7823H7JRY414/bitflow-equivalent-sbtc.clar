(define-read-only (get-user-total-sBTC-balance (user principal)) 
  (+ 
    (unwrap! (contract-call? 'SPQC38PW542EQJ5M11CR25P7BS1CA6QT4TBXGB3M.xyk-sbtc-reader-pool-21-v-1-2 get-user-sbtc-balance user) u0)
    (unwrap! (contract-call? 'SPQC38PW542EQJ5M11CR25P7BS1CA6QT4TBXGB3M.xyk-sbtc-reader-pool-22-v-1-2 get-user-sbtc-balance user) u0)
    (unwrap! (contract-call? 'SPQC38PW542EQJ5M11CR25P7BS1CA6QT4TBXGB3M.xyk-sbtc-reader-pool-23-v-1-2 get-user-sbtc-balance user) u0)
    (unwrap! (contract-call? 'SPQC38PW542EQJ5M11CR25P7BS1CA6QT4TBXGB3M.stableswap-sbtc-reader-pool-2-v-1-2 get-user-sbtc-balance user) u0)
  )
)
