;; Contract: Staking Pool
;; Description: Locks STX and mints Yield Token.

(define-map staker-info principal uint)

(define-public (stake-stx (amount uint))
    (begin
        ;; 1. Lock STX in this contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; 2. Record the stake
        (map-set staker-info tx-sender amount)
        
        ;; 3. Call the token contract to mint rewards (1:1 ratio)
        (contract-call? .yield-token mint-reward amount tx-sender)
    )
)

(define-read-only (get-stake (user principal))
    (ok (map-get? staker-info user))
)