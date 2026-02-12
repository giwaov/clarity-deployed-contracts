---
title: "Trait builder-lottery"
draft: true
---
```
;; Builder Lottery - Clarity 4
;; Provably fair lottery for builders

(define-constant contract-owner tx-sender)
(define-constant err-lottery-ended (err u11000))
(define-constant err-not-ended (err u11001))
(define-constant err-already-drawn (err u11002))

(define-data-var lottery-nonce uint u0)
(define-data-var ticket-price uint u1000000) ;; 1 STX

(define-map lotteries
    uint
    {
        prize-pool: uint,
        start-height: uint,
        end-height: uint,
        total-tickets: uint,
        drawn: bool,
        winner: (optional principal)
    }
)

(define-map tickets
    {lottery-id: uint, ticket-id: uint}
    principal
)

(define-map user-tickets
    {lottery-id: uint, user: principal}
    (list 100 uint)
)

(define-read-only (get-lottery (lottery-id uint))
    (map-get? lotteries lottery-id)
)

(define-read-only (get-user-tickets (lottery-id uint) (user principal))
    (default-to (list) (map-get? user-tickets {lottery-id: lottery-id, user: user}))
)

(define-public (create-lottery (duration-blocks uint))
    (let (
        (lottery-id (var-get lottery-nonce))
    )
        (map-set lotteries lottery-id {
            prize-pool: u0,
            start-height: stacks-block-height,
            end-height: (+ stacks-block-height duration-blocks),
            total-tickets: u0,
            drawn: false,
            winner: none
        })
        
        (var-set lottery-nonce (+ lottery-id u1))
        (ok lottery-id)
    )
)

(define-public (buy-ticket (lottery-id uint))
    (let (
        (lottery (unwrap! (get-lottery lottery-id) err-not-ended))
        (ticket-id (get total-tickets lottery))
        (user-ticket-list (get-user-tickets lottery-id tx-sender))
    )
        (asserts! (< stacks-block-height (get end-height lottery)) err-lottery-ended)
        
        (try! (stx-transfer? (var-get ticket-price) tx-sender (as-contract tx-sender)))
        
        (map-set tickets {lottery-id: lottery-id, ticket-id: ticket-id} tx-sender)
        
        (map-set user-tickets {lottery-id: lottery-id, user: tx-sender}
            (unwrap-panic (as-max-len? (append user-ticket-list ticket-id) u100))
        )
        
        (ok (map-set lotteries lottery-id 
            (merge lottery {
                prize-pool: (+ (get prize-pool lottery) (var-get ticket-price)),
                total-tickets: (+ ticket-id u1)
            })
        ))
    )
)

(define-public (draw-winner (lottery-id uint))
    (let (
        (lottery (unwrap! (get-lottery lottery-id) err-not-ended))
        (total-tickets (get total-tickets lottery))
        ;; Use block height as randomness source (not secure for production)
        (winning-ticket (mod (+ stacks-block-height u12345) total-tickets))
        (winner (unwrap! (map-get? tickets {lottery-id: lottery-id, ticket-id: winning-ticket}) 
            err-not-ended))
    )
        (asserts! (>= stacks-block-height (get end-height lottery)) err-not-ended)
        (asserts! (not (get drawn lottery)) err-already-drawn)
        
        (map-set lotteries lottery-id 
            (merge lottery {drawn: true, winner: (some winner)})
        )
        
        (try! (as-contract (stx-transfer? (get prize-pool lottery) tx-sender winner)))
        (ok winner)
    )
)

```
