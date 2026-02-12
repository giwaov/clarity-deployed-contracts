

(define-non-fungible-token streak-nft uint)

(define-read-only (get-token-uri (token-id uint))
  (some "ipfs://streak-nft-metadata")
)


(define-map user-stats
  principal
  {
    current-streak: uint,
    max-streak: uint,
    total-checkins: uint
  }
)


(define-map claimed
  { user: principal, milestone: uint }
  bool
)


(define-data-var total-users uint u0)
(define-data-var total-checkins uint u0)


(define-data-var last-token-id uint u0)



(define-read-only (get-user (user principal))
  (map-get? user-stats user)
)

(define-read-only (get-global-stats)
  {
    total-users: (var-get total-users),
    total-checkins: (var-get total-checkins)
  }
)


(define-private (mint-streak-nft (to principal))
  (let ((id (+ (var-get last-token-id) u1)))
    (begin
      (var-set last-token-id id)
      (unwrap-panic (nft-mint? streak-nft id to))
      id
    )
  )
)


(define-public (check-in)
  (let (
        (caller tx-sender)
        (stats (map-get? user-stats caller))
       )

    (if (is-none stats)


        (begin
          (map-set user-stats caller {
            current-streak: u1,
            max-streak: u1,
            total-checkins: u1
          })

          (var-set total-users (+ (var-get total-users) u1))
          (var-set total-checkins (+ (var-get total-checkins) u1))

          (ok {
            streak: u1,
            minted: false
          })
        )


        (let (
              (current (get current-streak (unwrap-panic stats)))
              (max (get max-streak (unwrap-panic stats)))
              (total (get total-checkins (unwrap-panic stats)))
              (new-streak (+ current u1))
              (new-max (if (> (+ current u1) max) (+ current u1) max))
             )

          (map-set user-stats caller {
            current-streak: new-streak,
            max-streak: new-max,
            total-checkins: (+ total u1)
          })

          (var-set total-checkins (+ (var-get total-checkins) u1))

          (let (
                (minted
                  (if (and
                        (>= new-streak u7)
                        (is-none (map-get? claimed { user: caller, milestone: u7 }))
                      )
                      (begin
                        (map-set claimed { user: caller, milestone: u7 } true)
                        (mint-streak-nft caller)
                        true
                      )
                      false
                  )
                )
               )

            (ok {
              streak: new-streak,
              minted: minted
            })
          )
        )
    )
  )
)
