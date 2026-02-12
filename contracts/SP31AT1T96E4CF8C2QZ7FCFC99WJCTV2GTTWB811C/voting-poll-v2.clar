(define-data-var poll-counter uint u0)

(define-map polls uint {
    creator: principal,
    question: (string-utf8 256),
    yes-votes: uint,
    no-votes: uint,
    end-block: uint
})

(define-map votes {poll-id: uint, voter: principal} bool)

(define-public (create-poll (question (string-utf8 256)) (duration uint))
    (let ((poll-id (var-get poll-counter)))
        (map-set polls poll-id {
            creator: tx-sender,
            question: question,
            yes-votes: u0,
            no-votes: u0,
            end-block: (+ stacks-block-height duration)
        })
        (var-set poll-counter (+ poll-id u1))
        (ok poll-id)
    )
)

(define-public (vote (poll-id uint) (vote-yes bool))
    (let ((poll (unwrap! (map-get? polls poll-id) (err u404))))
        (asserts! (< stacks-block-height (get end-block poll)) (err u403))
        (asserts! (is-none (map-get? votes {poll-id: poll-id, voter: tx-sender})) (err u402))
        (map-set votes {poll-id: poll-id, voter: tx-sender} vote-yes)
        (if vote-yes
            (map-set polls poll-id (merge poll {yes-votes: (+ (get yes-votes poll) u1)}))
            (map-set polls poll-id (merge poll {no-votes: (+ (get no-votes poll) u1)}))
        )
        (ok true)
    )
)

(define-read-only (get-poll (poll-id uint))
    (ok (map-get? polls poll-id))
)
