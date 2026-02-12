---
title: "Trait v1-transfer"
draft: true
---
```

(use-trait ft 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.ft-trait.ft-trait)
(use-trait ft-mint-trait 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.ft-mint-trait.ft-mint-trait)
(use-trait a-token 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.a-token-trait.a-token-trait)
(use-trait flash-loan 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.flash-loan-trait.flash-loan-trait)
(use-trait oracle-trait 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.oracle-trait.oracle-trait)
(use-trait redeemeable-token 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.redeemeable-trait-v1-2.redeemeable-trait)
(use-trait incentives-trait 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.incentives-trait-v2-1.incentives-trait)

(define-constant ERR_UNAUTHORIZED (err u1000000000000))
(define-constant ERR_REWARDS_CONTRACT (err u1000000000001))
(define-constant ERR_NO_REWARDS (err u1000000000003))

(define-constant max-value u340282366920938463463374607431768211455)

(define-read-only (is-rewards-contract (contract principal))
  (is-eq contract (contract-call? 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.rewards-data get-rewards-contract-read)))

(define-public (withdraw-deposit-all
  (assets (list 100 { asset: <ft>, lp-token: <ft-mint-trait>, oracle: <oracle-trait> }))
  (price-feed-bytes (optional (buff 8192)))
  (ststx-withdraw bool)
  (wstx-withdraw bool)
  (usdh-withdraw bool)
  (sbtc-withdraw bool)
  (ststxbtc-withdraw bool)
  )
  (let (
    (account tx-sender)
  )
    (asserts! (is-eq account contract-caller) ERR_UNAUTHORIZED)

    (if ststx-withdraw
      (let (
        (token-balance
          (try!
            (withdraw
              'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zststx-v2-0
              'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-0-reserve-v2-0
              'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststx-token
              'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4
              max-value
              account
              assets
              'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.incentives-v2-2
              price-feed-bytes
            )
          )
        )
      )
        (try! (contract-call? 'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststx-token transfer token-balance account current-contract none))
        (try! (as-contract? ((with-all-assets-unsafe))
          (try! (contract-call? 'SP1A27KFY4XERQCCRCARCYD1CC5N7M6688BSYADJ7.vault-ststx
            deposit
            token-balance
            u0
            account
          ))
        ))
      )
      u0
    )

    (if wstx-withdraw
      (let (
        (token-balance
          (try!
            (withdraw
              'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zwstx-v2-0
              'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-0-reserve-v2-0
              'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.wstx
              'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4
              max-value
              account
              assets
              'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.incentives-v2-2
              price-feed-bytes
            )
          )
        )
      )
        (try! (contract-call? 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.wstx transfer token-balance account current-contract none))
        (try! (as-contract? ((with-all-assets-unsafe))
          (try! (contract-call? 'SP1A27KFY4XERQCCRCARCYD1CC5N7M6688BSYADJ7.vault-stx
            deposit
            token-balance
            u0
            account
          ))
        ))
      )
      u0
    )

    (if usdh-withdraw
      (let (
        (token-balance
          (try!
            (withdraw
              'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zusdh-v2-0
              'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-0-reserve-v2-0
              'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.usdh-token-v1
              'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.usdh-oracle-v1-0
              max-value
              account
              assets
              'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.incentives-v2-2
              price-feed-bytes
            )
          )
        )
      )
        (try! (contract-call? 'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.usdh-token-v1 transfer token-balance account current-contract none))
        (try! (as-contract? ((with-all-assets-unsafe))
          (try! (contract-call? 'SP1A27KFY4XERQCCRCARCYD1CC5N7M6688BSYADJ7.vault-usdh
            deposit
            token-balance
            u0
            account
          ))
        ))
      )
      u0
    )

    (if sbtc-withdraw
      (let (
        (token-balance
          (try!
            (withdraw
              'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zsbtc-v2-0
              'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-0-reserve-v2-0
              'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
              'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4
              max-value
              account
              assets
              'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.incentives-v2-2
              price-feed-bytes
            )
          )
        )
      )
        (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token transfer token-balance account current-contract none))
        (try! (as-contract? ((with-all-assets-unsafe))
          (try! (contract-call? 'SP1A27KFY4XERQCCRCARCYD1CC5N7M6688BSYADJ7.vault-sbtc
            deposit
            token-balance
            u0
            account
          ))
        ))
      )
      u0
    )

    (if ststxbtc-withdraw
      (let (
        (token-balance
          (try!
            (withdraw
              'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zststxbtc-v2_v2-0
              'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-0-reserve-v2-0
              'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststxbtc-token-v2
              'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4
              max-value
              account
              assets
              'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.incentives-v2-2
              price-feed-bytes
            )
          )
        )
      )
        (try! (contract-call? 'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststxbtc-token-v2 transfer token-balance account current-contract none))
        (try! (as-contract? ((with-all-assets-unsafe))
          (try! (contract-call? 'SP1A27KFY4XERQCCRCARCYD1CC5N7M6688BSYADJ7.vault-ststxbtc
            deposit
            token-balance
            u0
            account
          ))
        ))
      )
      u0
    )


    (ok true)
  )
)


(define-private (withdraw
  (lp <redeemeable-token>)
  (pool-reserve principal)
  (asset <ft>)
  (oracle <oracle-trait>)
  (amount uint)
  (owner principal)
  (assets (list 100 { asset: <ft>, lp-token: <ft-mint-trait>, oracle: <oracle-trait> }))
  (incentives <incentives-trait>)
  (price-feed-bytes (optional (buff 8192)))
  )
  (let (
    (asset-principal (contract-of asset))
    (check-ok (asserts! (is-eq tx-sender contract-caller) ERR_UNAUTHORIZED))
    (check-on-rewards (asserts! (is-rewards-contract (contract-of incentives)) ERR_REWARDS_CONTRACT))
    (price-ok (try! (write-feed price-feed-bytes)))
    (result-claim (try! (contract-call? incentives claim-rewards-to-vault lp asset owner)))
    (withdraw-res (try! (contract-call? 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-borrow-v2-4 withdraw pool-reserve asset lp oracle assets amount owner)))
    )
    (ok withdraw-res)
  )
)

(define-private (write-feed (price-feed-bytes (optional (buff 8192))))
  (match price-feed-bytes
    bytes (begin
      (try! 
        (contract-call? 'SP1CGXWEAMG6P6FT04W66NVGJ7PQWMDAC19R7PJ0Y.pyth-oracle-v4 verify-and-update-price-feeds
          bytes
          {
            pyth-storage-contract: 'SP1CGXWEAMG6P6FT04W66NVGJ7PQWMDAC19R7PJ0Y.pyth-storage-v4,
            pyth-decoder-contract: 'SP1CGXWEAMG6P6FT04W66NVGJ7PQWMDAC19R7PJ0Y.pyth-pnau-decoder-v3,
            wormhole-core-contract: 'SP1CGXWEAMG6P6FT04W66NVGJ7PQWMDAC19R7PJ0Y.wormhole-core-v4
          }
        )
      )
      (ok true)
    )
    (begin
      (print "no-feed-update")
      ;; do nothing if none
      (ok true)
    )
  )
)
```
