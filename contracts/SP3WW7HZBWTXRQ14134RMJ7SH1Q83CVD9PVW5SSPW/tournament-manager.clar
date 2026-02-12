;; Tournament Manager
;; Manages gaming tournaments

(define-constant contract-owner tx-sender)
(define-data-var next-tournament-id uint u1)

(define-map tournaments
  uint
  {
    creator: principal,
    prize-pool: uint,
    entry-fee: uint,
    max-players: uint,
    active: bool
  }
)

(define-map tournament-players { tournament-id: uint, player: principal } bool)

(define-read-only (get-tournament (tournament-id uint))
  (map-get? tournaments tournament-id)
)

(define-public (create-tournament (prize-pool uint) (entry-fee uint) (max-players uint))
  (let ((tournament-id (var-get next-tournament-id)))
    (map-set tournaments tournament-id {
      creator: tx-sender,
      prize-pool: prize-pool,
      entry-fee: entry-fee,
      max-players: max-players,
      active: true
    })
    (var-set next-tournament-id (+ tournament-id u1))
    (ok tournament-id)
  )
)

(define-public (join-tournament (tournament-id uint))
  (let ((tournament (unwrap! (map-get? tournaments tournament-id) (err u100))))
    (try! (stx-transfer? (get entry-fee tournament) tx-sender (as-contract tx-sender)))
    (map-set tournament-players { tournament-id: tournament-id, player: tx-sender } true)
    (ok true)
  )
)
