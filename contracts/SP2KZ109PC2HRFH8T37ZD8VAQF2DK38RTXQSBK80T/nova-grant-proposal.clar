
;; nova-grant-proposal.clar
;; System for requesting funds from treasury
;; CLARITY VERSION: 2

(define-map grants
    uint
    {
        recipient: principal,
        amount: uint,
        description: (string-ascii 64),
        approved: bool
    }
)
(define-data-var grant-nonce uint u0)

(define-public (submit-grant (amount uint) (desc (string-ascii 64)))
    (let ((id (var-get grant-nonce)))
        (map-set grants id {
            recipient: tx-sender,
            amount: amount,
            description: desc,
            approved: false
        })
        (var-set grant-nonce (+ id u1))
        (ok id)
    )
)

(define-public (approve-grant (id uint))
    (let ((grant (unwrap! (map-get? grants id) (err u404))))
        ;; Auth check omitted
        (map-set grants id (merge grant {approved: true}))
        (ok true)
    )
)
