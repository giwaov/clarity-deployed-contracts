;; weighted-voting.clar
;; Voting power proportional to STX balance

(define-map votes { proposal: uint, voter: principal } uint)
(define-map proposals uint { title: (string-ascii 50), total-votes: uint })

(define-public (vote (proposal-id uint))
    (let
        (
            (weight (stx-get-balance tx-sender))
            (proposal (unwrap! (map-get? proposals proposal-id) (err u404)))
        )
        (asserts! (map-insert votes { proposal: proposal-id, voter: tx-sender } weight) (err u100)) ;; ERR_ALREADY_VOTED
        (map-set proposals proposal-id (merge proposal { total-votes: (+ (get total-votes proposal) weight) }))
        (ok weight)
    )
)

(define-public (create-proposal (id uint) (title (string-ascii 50)))
    (ok (map-set proposals id { title: title, total-votes: u0 }))
)
