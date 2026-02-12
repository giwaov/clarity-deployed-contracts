
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-NOT-AUTHORIZED (err u401))


(define-map diaries
  principal
  {
    word: (string-ascii 32),
    story: (string-utf8 512),
    timestamp: uint
  }
)


(define-public (add-diary
  (word (string-ascii 32))
  (story (string-utf8 512))
  (timestamp uint)
)
  (begin
    (map-set diaries
      tx-sender
      {
        word: word,
        story: story,
        timestamp: timestamp
      }
    )
    (ok true)
  )
)


(define-read-only (get-diary (user principal))
  (match (map-get? diaries user)
    diary (ok diary)
    ERR-NOT-FOUND
  )
)
