;; Content Access - Manage content access

(define-map content-access
  { user: principal, content-id: (string-ascii 50) }
  { unlocked-at: uint }
)

(define-public (unlock-content (content-id (string-ascii 50)))
  (begin
    (map-set content-access { user: tx-sender, content-id: content-id } {
      unlocked-at: stacks-block-height
    })
    (ok true)
  )
)

(define-read-only (has-access (user principal) (content-id (string-ascii 50)))
  (is-some (map-get? content-access { user: user, content-id: content-id }))
)
