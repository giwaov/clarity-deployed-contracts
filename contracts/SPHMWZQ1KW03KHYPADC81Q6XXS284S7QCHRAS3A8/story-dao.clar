;; contracts/story-dao.clar


(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-ALREADY-VOTED (err u402))
(define-constant ERR-ROUND-ENDED (err u403))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u404))


(define-data-var current-round-id uint u1)
(define-data-var round-end-block uint u0)
(define-data-var full-story (string-utf8 4096) u"Once upon a time in the Stacks universe, ")


(define-map proposals 
  { round: uint, id: uint } 
  { author: principal, content: (string-utf8 256), votes: uint }
)


(define-map round-proposal-count uint uint)


(define-map user-voted { round: uint, user: principal } bool)


(define-read-only (get-full-story)
  (ok (var-get full-story))
)


(define-read-only (get-proposal-count (round uint))
  (default-to u0 (map-get? round-proposal-count round))
)


(define-read-only (get-proposal (round uint) (id uint))
  (map-get? proposals { round: round, id: id })
)


(define-public (submit-proposal (content (string-utf8 256)))
  (let 
    (
      (round (var-get current-round-id))
      (current-count (get-proposal-count round))
      (next-id (+ current-count u1))
    )

    (map-set proposals 
      { round: round, id: next-id }
      { author: tx-sender, content: content, votes: u0 }
    )
    (map-set round-proposal-count round next-id)
    (ok next-id)
  )
)


(define-public (vote-proposal (proposal-id uint))
  (let 
    (
      (round (var-get current-round-id))
      (user tx-sender)
      (has-voted (default-to false (map-get? user-voted { round: round, user: user })))
      (proposal (unwrap! (map-get? proposals { round: round, id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
    )
    (asserts! (not has-voted) ERR-ALREADY-VOTED)
    
    
    (map-set proposals 
      { round: round, id: proposal-id }
      (merge proposal { votes: (+ (get votes proposal) u1) })
    )
    
  
    (map-set user-voted { round: round, user: user } true)
    (ok true)
  )
)


(define-public (finalize-round (winning-proposal-id uint))
  (let 
    (
      (round (var-get current-round-id))
      (proposal (unwrap! (map-get? proposals { round: round, id: winning-proposal-id }) ERR-PROPOSAL-NOT-FOUND))
    )
    
    
    (var-set full-story 
      (unwrap-panic (as-max-len? (concat (var-get full-story) (concat u" " (get content proposal))) u4096))
    )
    
    
    (var-set current-round-id (+ round u1))
    (ok true)
  )
)