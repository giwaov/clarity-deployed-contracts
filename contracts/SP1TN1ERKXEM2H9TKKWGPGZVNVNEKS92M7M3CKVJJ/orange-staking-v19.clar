(use-trait ft-trait .orange-sip010-ft-trait-v19.ft-trait)

(define-map stakes principal {amount: uint, staked-at: uint})

(define-public (stake-tokens (amount uint) (token-trait <ft-trait>))
  (begin
    ;; User transfers tokens to contract (user is tx-sender)
    (try! (contract-call? token-trait transfer amount tx-sender current-contract none))
    ;; Record the stake with current Stacks block height
    (map-set stakes tx-sender {amount: amount, staked-at: stacks-block-height})
    (ok true)))

(define-public (unstake-tokens (token-trait <ft-trait>))
  (let
    (
      (staker tx-sender)
      (stake (unwrap! (map-get? stakes staker) (err u404)))
      (amount (get amount stake))
    )
    (begin
      ;; Contract calls token contract to transfer FROM itself TO the staker
      (try! (contract-call? token-trait transfer amount current-contract staker none))
      ;; Delete the stake record
      (map-delete stakes staker)
      (ok amount))))

(define-read-only (get-stake (principal principal))
  (ok (map-get? stakes principal)))
