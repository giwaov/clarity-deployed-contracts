(define-data-var proposal-counter uint u0)

(define-map proposals
  uint
  {
    proposer: principal,
    title: (string-utf8 128),
    description: (string-utf8 512),
    submitted-at: uint,
  }
)

(define-public (submit-proposal
    (title (string-utf8 128))
    (description (string-utf8 512))
  )
  (let ((proposal-id (var-get proposal-counter)))
    (asserts! (> (len title) u0) (err u1))
    (asserts! (> (len description) u0) (err u2))
    (map-set proposals proposal-id {
      proposer: tx-sender,
      title: title,
      description: description,
      submitted-at: stacks-block-height,
    })
    (var-set proposal-counter (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-read-only (get-proposal (proposal-id uint))
  (ok (map-get? proposals proposal-id))
)
