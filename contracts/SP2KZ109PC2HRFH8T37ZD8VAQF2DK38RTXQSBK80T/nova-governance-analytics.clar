
;; Nova Governance Analytics
;; Tracks and analyzes governance participation

(define-map voter-stats
    { voter: principal }
    {
        proposals-voted: uint,
        total-voting-power: uint,
        last-active-block: uint
    }
)

(define-map proposal-analytics
    { proposal-id: uint }
    {
        total-votes: uint,
        unique-voters: uint,
        participation-rate: uint
    }
)

(define-public (record-vote (voter principal) (proposal-id uint) (power uint))
    (let
        (
            (current-stats (default-to { proposals-voted: u0, total-voting-power: u0, last-active-block: u0 } (map-get? voter-stats { voter: voter })))
            (current-proposal (default-to { total-votes: u0, unique-voters: u0, participation-rate: u0 } (map-get? proposal-analytics { proposal-id: proposal-id })))
        )
        (map-set voter-stats
            { voter: voter }
            {
                proposals-voted: (+ (get proposals-voted current-stats) u1),
                total-voting-power: (+ (get total-voting-power current-stats) power),
                last-active-block: block-height
            }
        )
        (ok (map-set proposal-analytics
            { proposal-id: proposal-id }
            {
                total-votes: (+ (get total-votes current-proposal) power),
                unique-voters: (+ (get unique-voters current-proposal) u1),
                participation-rate: u0 ;; Simplified for now
            }
        ))
    )
)

(define-read-only (get-voter-stats (voter principal))
    (map-get? voter-stats { voter: voter })
)
