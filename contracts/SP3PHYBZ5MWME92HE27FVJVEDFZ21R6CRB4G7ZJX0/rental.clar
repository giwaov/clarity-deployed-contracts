;; Contract: Rental Market
;; Description: Handles payments and rents bikes.

(define-constant rental-price u50) ;; 50 micro-STX

(define-public (rent-bike (bike-id uint))
    (let
        (
            (bike (unwrap! (contract-call? .bikes get-bike bike-id) (err u404)))
        )
        ;; Check if already rented
        (asserts! (not (get is-rented bike)) (err u403))
        
        ;; Pay rental fee
        (try! (stx-transfer? rental-price tx-sender (as-contract tx-sender)))
        
        ;; Update status in Registry Contract
        (as-contract (contract-call? .bikes set-status bike-id true))
    )
)