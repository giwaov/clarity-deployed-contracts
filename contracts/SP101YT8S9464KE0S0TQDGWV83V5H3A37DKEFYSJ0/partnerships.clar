;; Partnerships - Creator partnerships

(define-map partnerships
  { creator-a: principal, creator-b: principal }
  {
    active: bool,
    created-at: uint
  }
)

(define-public (create-partnership (partner principal))
  (begin
    (map-set partnerships { creator-a: tx-sender, creator-b: partner } {
      active: true,
      created-at: stacks-block-height
    })
    (ok true)
  )
)

(define-public (end-partnership (partner principal))
  (begin
    (map-delete partnerships { creator-a: tx-sender, creator-b: partner })
    (ok true)
  )
)

(define-read-only (is-partners (creator-a principal) (creator-b principal))
  (default-to false (get active (map-get? partnerships { creator-a: creator-a, creator-b: creator-b })))
)
