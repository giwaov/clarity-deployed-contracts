
;; nova-quest-tracker.clar
;; Tracks player progress
;; CLARITY VERSION: 2

(define-map quests
    {player: principal, quest-id: uint}
    bool ;; completed
)

(define-public (complete-quest (quest-id uint))
    (begin
        ;; Auth check omitted
        (map-set quests {player: tx-sender, quest-id: quest-id} true)
        (ok true)
    )
)

(define-read-only (is-complete (user principal) (quest-id uint))
    (default-to false (map-get? quests {player: user, quest-id: quest-id}))
)
