;; voting.clar
;; Simple Proposal Voting

(define-map proposals uint { title: (string-ascii 50), votes-for: uint, votes-against: uint, ends-at: uint })
(define-map votes { proposal-id: uint, voter: principal } bool)
(define-data-var proposal-count uint u0)

(define-public (create-proposal (title (string-ascii 50)) (duration uint))
    (let
        (
            (id (var-get proposal-count))
            (end-time (+ block-height duration))
        )
        (map-set proposals id { title: title, votes-for: u0, votes-against: u0, ends-at: end-time })
        (var-set proposal-count (+ id u1))
        (ok id)
    )
)

(define-public (vote (proposal-id uint) (approve bool))
    (let
        (
            (proposal (unwrap! (map-get? proposals proposal-id) (err u404)))
            (has-voted (default-to false (map-get? votes { proposal-id: proposal-id, voter: tx-sender })))
        )
        (asserts! (not has-voted) (err u100))
        (asserts! (< block-height (get ends-at proposal)) (err u101))
        
        (map-set votes { proposal-id: proposal-id, voter: tx-sender } true)
        
        (if approve
            (map-set proposals proposal-id (merge proposal { votes-for: (+ (get votes-for proposal) u1) }))
            (map-set proposals proposal-id (merge proposal { votes-against: (+ (get votes-against proposal) u1) }))
        )
        (ok true)
    )
)
