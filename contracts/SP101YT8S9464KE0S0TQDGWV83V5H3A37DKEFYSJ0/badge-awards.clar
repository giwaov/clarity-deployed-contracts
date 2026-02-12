;; Badge Awards - Award badges to users

(define-map badges
  { user: principal, badge-type: (string-ascii 30) }
  { awarded-at: uint }
)

(define-public (award-badge (user principal) (badge-type (string-ascii 30)))
  (begin
    (map-set badges { user: user, badge-type: badge-type } {
      awarded-at: stacks-block-height
    })
    (ok true)
  )
)

(define-read-only (has-badge (user principal) (badge-type (string-ascii 30)))
  (is-some (map-get? badges { user: user, badge-type: badge-type }))
)

(define-read-only (get-badge (user principal) (badge-type (string-ascii 30)))
  (map-get? badges { user: user, badge-type: badge-type })
)
