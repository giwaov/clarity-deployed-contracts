
;; Centrifuge King V2
;; "Defensive King" Mechanic
;; 
;; Rules:
;; 1. To become King, you must bid strictly MORE than the current King's stake.
;; 2. If Bid > Current Stake:
;;    - You become the new King.
;;    - Your bid becomes the new "Current Stake" (locked in contract).
;;    - The previous King gets their original stake REFUNDED 100%.
;; 3. If Bid <= Current Stake (Failed Attempt):
;;    - You do NOT become King.
;;    - 95% of your bid is REFUNDED to you.
;;    - 5% of your bid is paid as TRIBUTE to the current King.
;;
;; This incentivizes setting a high stake to farm tribute from failed attackers.
;; If you are dethroned, you exit safely with your principal.

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-ENOUGH-FUNDS (err u100))
(define-constant ERR-BID-TOO-LOW (err u101))

;; Data Vars
(define-data-var current-king principal tx-sender)
(define-data-var current-stake uint u0) ;; The amount the current king put in
(define-data-var message (string-utf8 100) u"I am the King!")

;; Read-only functions
(define-read-only (get-king-info)
    (ok {
        king: (var-get current-king),
        price: (var-get current-stake),
        message: (var-get message)
    })
)

;; Public functions
(define-public (claim-crown (amount uint) (new-message (string-utf8 100)))
    (let
        (
            (current-price (var-get current-stake))
            (king (var-get current-king))
            (sender tx-sender)
            (contract-address (as-contract tx-sender))
        )
        ;; 1. User must transfer the bid amount to the contract first (to lock or distribute)
        (try! (stx-transfer? amount sender contract-address))

        (if (> amount current-price)
            ;; SUCCESS: Dethrone the King
            (begin
                ;; Refund the previous king their full stake
                ;; Note: If it's the first run (stake 0), this transfers 0 which is fine.
                ;; We use (as-contract) to send from the contract's balance.
                (if (> current-price u0)
                    (try! (as-contract (stx-transfer? current-price tx-sender king)))
                    true
                )

                ;; Update State
                (var-set current-king sender)
                (var-set current-stake amount)
                (var-set message new-message)
                
                (print {event: "claim-crown", type: "success", king: sender, price: amount, message: new-message})
                (ok true)
            )
            ;; FAILURE: Pay Tribute
            (begin
                (let
                    (
                        (tribute (/ (* amount u5) u100)) ;; 5%
                        (refund (- amount tribute))      ;; 95%
                    )
                    ;; Refund 95% to the failed bidder
                    (try! (as-contract (stx-transfer? refund tx-sender sender)))
                    
                    ;; Pay 5% tribute to the current king
                    (try! (as-contract (stx-transfer? tribute tx-sender king)))

                    (print {event: "claim-crown", type: "failure", bidder: sender, amount: amount, tribute: tribute})
                    (ok false)
                )
            )
        )
    )
)
