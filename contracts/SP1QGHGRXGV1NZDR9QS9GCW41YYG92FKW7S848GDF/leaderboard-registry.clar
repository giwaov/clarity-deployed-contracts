;; leaderboard-registry
;; Gaming Assets & Leaderboards

(define-map player-stats
  { player: principal }
  { xp: uint, level: uint, wins: uint }
)

(define-map items
  { item-id: uint }
  { owner: principal, name: (string-ascii 32), power: uint }
)

(define-public (gain-xp (amount uint))
  (let ((stats (default-to { xp: u0, level: u1, wins: u0 } (map-get? player-stats { player: tx-sender }))))
    (ok (map-set player-stats { player: tx-sender }
      (merge stats { xp: (+ (get xp stats) amount) })
    ))
  )
)

(define-public (mint-item (item-id uint) (name (string-ascii 32)) (power uint))
  (ok (map-set items { item-id: item-id } { owner: tx-sender, name: name, power: power }))
)