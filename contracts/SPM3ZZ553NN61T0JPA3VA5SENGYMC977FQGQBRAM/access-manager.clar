(define-map permissions
  {
    user: principal,
    resource: (string-ascii 50),
  }
  bool
)

(define-constant err-unauthorized (err u400))

(define-public (grant-permission
    (user principal)
    (resource (string-ascii 50))
  )
  (begin
    (asserts! (not (is-eq user tx-sender)) (err u401))
    (asserts! (> (len resource) u0) (err u402))
    (map-set permissions {
      user: user,
      resource: resource,
    } true
    )
    (ok true)
  )
)

(define-public (revoke-permission
    (user principal)
    (resource (string-ascii 50))
  )
  (begin
    (asserts! (not (is-eq user tx-sender)) (err u401))
    (asserts! (> (len resource) u0) (err u402))
    (map-delete permissions {
      user: user,
      resource: resource,
    })
    (ok true)
  )
)

(define-read-only (has-permission
    (user principal)
    (resource (string-ascii 50))
  )
  (ok (default-to false
    (map-get? permissions {
      user: user,
      resource: resource,
    })
  ))
)
