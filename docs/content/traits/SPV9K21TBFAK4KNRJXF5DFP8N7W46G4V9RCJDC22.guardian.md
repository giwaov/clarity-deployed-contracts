---
title: "Trait guardian"
draft: true
---
```
(define-constant err-unauthorized (err u8001))
(define-constant err-ltv-below-threshold (err u8002))
(define-constant err-exceeds-target (err u8003))
(define-constant err-fetch-failed (err u8004))

(define-constant ONE_8 u100000000)

(define-public (request-unwind-permission
    (max-drawdown-ltv uint)
    (target-ltv uint)
    (sbtc-to-swap uint)
    (sbtc-to-withdraw uint)
    (price-feed-bytes (optional (buff 8192)))
  )
  (let (
    (wallet tx-sender)
    
    (price-update (match price-feed-bytes
      bytes (contract-call? 
        'SP1CGXWEAMG6P6FT04W66NVGJ7PQWMDAC19R7PJ0Y.pyth-oracle-v4
        verify-and-update-price-feeds
        bytes
        {
          pyth-storage-contract: 'SP1CGXWEAMG6P6FT04W66NVGJ7PQWMDAC19R7PJ0Y.pyth-storage-v4,
          pyth-decoder-contract: 'SP1CGXWEAMG6P6FT04W66NVGJ7PQWMDAC19R7PJ0Y.pyth-pnau-decoder-v3,
          wormhole-core-contract: 'SP1CGXWEAMG6P6FT04W66NVGJ7PQWMDAC19R7PJ0Y.wormhole-core-v4
        }
      )
      (ok (list))
    ))
    
    (collateral-sats (unwrap! (contract-call? 
      'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zsbtc-v2-0 
      get-balance 
      wallet) err-fetch-failed))
    
    (borrow-data (unwrap! (contract-call? 
      'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-0-reserve-v2-0 
      get-user-borrow-balance 
      wallet 
      'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc) err-fetch-failed))
    (debt-aeusdc (get compounded-balance borrow-data))
    
    (btc-price (unwrap! (contract-call? 
      'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 
      get-asset-price 
      'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token) err-fetch-failed))
    
    (collateral-usd (/ (* collateral-sats btc-price) ONE_8))
    (current-ltv (if (is-eq collateral-usd u0)
      u0
      (/ (* debt-aeusdc ONE_8 u100) collateral-usd)))
    
    (aeusdc-from-swap (/ (* sbtc-to-swap btc-price) ONE_8 u100))
    
    (new-collateral-sats (if (> (+ sbtc-to-swap sbtc-to-withdraw) collateral-sats)
      u0
      (- collateral-sats (+ sbtc-to-swap sbtc-to-withdraw))))
    (new-debt (if (> debt-aeusdc aeusdc-from-swap)
      (- debt-aeusdc aeusdc-from-swap)
      u0))
    (new-collateral-usd (/ (* new-collateral-sats btc-price) ONE_8))
    (new-ltv (if (is-eq new-collateral-usd u0)
      u0
      (/ (* new-debt ONE_8 u100) new-collateral-usd)))
  )

    (asserts! (>= current-ltv max-drawdown-ltv) err-ltv-below-threshold)
    
    (asserts! (or (is-eq new-debt u0) (>= new-ltv target-ltv)) err-exceeds-target)
    
    (print {
      a: "guardian-unwind-validated",
      wallet: wallet,
      current-ltv: current-ltv,
      new-ltv: new-ltv,
      max-drawdown-ltv: max-drawdown-ltv,
      target-ltv: target-ltv,
      sbtc-to-swap: sbtc-to-swap,
      sbtc-to-withdraw: sbtc-to-withdraw,
    })
    
    (ok true)
  )
)

(define-public (request-repay-permission
    (max-drawdown-ltv uint)
    (target-ltv uint)
    (aeusdc-amount uint)
    (price-feed-bytes (optional (buff 8192)))
  )
  (let (
    (wallet tx-sender)
    
    (price-update (match price-feed-bytes
      bytes (contract-call? 
        'SP1CGXWEAMG6P6FT04W66NVGJ7PQWMDAC19R7PJ0Y.pyth-oracle-v4
        verify-and-update-price-feeds
        bytes
        {
          pyth-storage-contract: 'SP1CGXWEAMG6P6FT04W66NVGJ7PQWMDAC19R7PJ0Y.pyth-storage-v4,
          pyth-decoder-contract: 'SP1CGXWEAMG6P6FT04W66NVGJ7PQWMDAC19R7PJ0Y.pyth-pnau-decoder-v3,
          wormhole-core-contract: 'SP1CGXWEAMG6P6FT04W66NVGJ7PQWMDAC19R7PJ0Y.wormhole-core-v4
        }
      )
      (ok (list))
    ))
    
    (collateral-sats (unwrap! (contract-call? 
      'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zsbtc-v2-0 
      get-balance 
      wallet) err-fetch-failed))
    
    (borrow-data (unwrap! (contract-call? 
      'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-0-reserve-v2-0 
      get-user-borrow-balance 
      wallet 
      'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc) err-fetch-failed))
    (debt-aeusdc (get compounded-balance borrow-data))
    
    (btc-price (unwrap! (contract-call? 
      'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 
      get-asset-price 
      'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token) err-fetch-failed))
    
    (collateral-usd (/ (* collateral-sats btc-price) ONE_8))
    (current-ltv (if (is-eq collateral-usd u0)
      u0
      (/ (* debt-aeusdc ONE_8 u100) collateral-usd)))
    
    (new-debt (if (> debt-aeusdc aeusdc-amount)
      (- debt-aeusdc aeusdc-amount)
      u0))
    
    (new-ltv (if (is-eq collateral-usd u0)
      u0
      (/ (* new-debt ONE_8 u100) collateral-usd)))
  )
    (asserts! (>= current-ltv max-drawdown-ltv) err-ltv-below-threshold)
    
    (asserts! (or (is-eq new-debt u0) (>= new-ltv target-ltv)) err-exceeds-target)
    
    (print {
      a: "guardian-repay-validated",
      wallet: wallet,
      current-ltv: current-ltv,
      new-ltv: new-ltv,
      max-drawdown-ltv: max-drawdown-ltv,
      target-ltv: target-ltv,
      aeusdc-amount: aeusdc-amount,
    })
    
    (ok true)
  )
)

(define-public (get-position-data (wallet principal))
  (let (
    (collateral-sats (unwrap! (contract-call? 
      'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zsbtc-v2-0 
      get-balance 
      wallet) err-fetch-failed))
    
    (borrow-data (unwrap! (contract-call? 
      'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-0-reserve-v2-0 
      get-user-borrow-balance 
      wallet 
      'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc) err-fetch-failed))
    (debt-aeusdc (get compounded-balance borrow-data))
    
    (btc-price (unwrap! (contract-call? 
      'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 
      get-asset-price 
      'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token) err-fetch-failed))
    
    (collateral-usd (/ (* collateral-sats btc-price) ONE_8))
    (current-ltv (if (is-eq collateral-usd u0)
      u0
      (/ (* debt-aeusdc ONE_8 u100) collateral-usd)))
  )
    (ok {
      collateral-sats: collateral-sats,
      debt-aeusdc: debt-aeusdc,
      btc-price: btc-price,
      collateral-usd: collateral-usd,
      current-ltv: current-ltv,
    })
  )
)

(define-public (can-guardian-act (wallet principal) (max-drawdown-ltv uint))
  (let (
    (collateral-sats (unwrap! (contract-call? 
      'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zsbtc-v2-0 
      get-balance 
      wallet) err-fetch-failed))
    
    (borrow-data (unwrap! (contract-call? 
      'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-0-reserve-v2-0 
      get-user-borrow-balance 
      wallet 
      'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc) err-fetch-failed))
    (debt-aeusdc (get compounded-balance borrow-data))
    
    (btc-price (unwrap! (contract-call? 
      'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 
      get-asset-price 
      'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token) err-fetch-failed))
    
    (collateral-usd (/ (* collateral-sats btc-price) ONE_8))
    (current-ltv (if (is-eq collateral-usd u0)
      u0
      (/ (* debt-aeusdc ONE_8 u100) collateral-usd)))
  )
    (ok {
      current-ltv: current-ltv,
      max-drawdown-ltv: max-drawdown-ltv,
      can-act: (>= current-ltv max-drawdown-ltv),
      collateral-sats: collateral-sats,
      debt-aeusdc: debt-aeusdc,
      btc-price: btc-price,
    })
  )
)

(define-public (calculate-unwind-to-target (wallet principal) (target-ltv uint))
  (let (
    (collateral-sats (unwrap! (contract-call? 
      'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zsbtc-v2-0 
      get-balance 
      wallet) err-fetch-failed))
    
    (borrow-data (unwrap! (contract-call? 
      'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-0-reserve-v2-0 
      get-user-borrow-balance 
      wallet 
      'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc) err-fetch-failed))
    (debt-aeusdc (get compounded-balance borrow-data))
    
    (btc-price (unwrap! (contract-call? 
      'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 
      get-asset-price 
      'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token) err-fetch-failed))
    
    (collateral-usd (/ (* collateral-sats btc-price) ONE_8))
    (current-ltv (if (is-eq collateral-usd u0)
      u0
      (/ (* debt-aeusdc ONE_8 u100) collateral-usd)))
    
    (target-debt (/ (* collateral-usd target-ltv) ONE_8))
    
    (debt-to-repay (if (> debt-aeusdc target-debt)
      (- debt-aeusdc target-debt)
      u0))
    
    (sats-to-swap (/ (* (/ (* debt-to-repay ONE_8) btc-price) u105) u100))
    
    (min-aeusdc (/ (* debt-to-repay u98) u100))
  )
    (ok {
      current-ltv: current-ltv,
      target-ltv: target-ltv,
      debt-to-repay: debt-to-repay,
      sbtc-to-swap: sats-to-swap,
      sbtc-to-withdraw: u0,
      min-aeusdc-from-swap: min-aeusdc,
    })
  )
)
```
