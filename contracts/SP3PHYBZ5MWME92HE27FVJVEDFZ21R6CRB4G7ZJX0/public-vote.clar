;; Contract: Voting Engine
;; Description: Logic for casting votes linked to gov-token.

(define-map proposals uint { title: (string-ascii 50), votes: uint })
(define-data-var proposal-count uint u0)

(define-public (create-proposal (title (string-ascii 50)))
    (let
        (
            (new-id (+ (var-get proposal-count) u1))
        )
        (map-set proposals new-id { title: title, votes: u0 })
        (var-set proposal-count new-id)
        (ok new-id)
    )
)

(define-public (vote (proposal-id uint) (amount uint))
    (let
        (
            ;; Call the gov-token contract to check balance
            (balance (unwrap-panic (contract-call? .gov-token get-balance tx-sender)))
            (current-proposal (unwrap! (map-get? proposals proposal-id) (err u404)))
        )
        ;; Assert user has enough tokens to vote
        (asserts! (>= balance amount) (err u401))
        
        ;; Update vote count
        (map-set proposals proposal-id 
            (merge current-proposal { votes: (+ (get votes current-proposal) amount) })
        )
        (ok "Vote Cast Successfully")
    )
)