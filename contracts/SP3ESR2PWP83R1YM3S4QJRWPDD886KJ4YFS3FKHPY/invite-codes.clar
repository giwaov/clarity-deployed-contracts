;; Invite Codes

(define-map invites
  (string-ascii 20)
  { creator: principal, used: bool, usedBy: (optional principal) }
)

(define-public (create-invite (code (string-ascii 20)))
  (begin
    (asserts! (is-none (map-get? invites code)) (err u409))
    (map-set invites code { creator: tx-sender, used: false, usedBy: none })
    (ok true)
  )
)

(define-public (use-invite (code (string-ascii 20)))
  (let ((invite (unwrap! (map-get? invites code) (err u404))))
    (asserts! (not (get used invite)) (err u409))
    (map-set invites code (merge invite { used: true, usedBy: (some tx-sender) }))
    (ok true)
  )
)

(define-read-only (get-invite (code (string-ascii 20)))
  (map-get? invites code)
)
