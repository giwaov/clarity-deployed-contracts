;; ------------------------------------------------------------
;; SCORE SAVING CONTRACT 
;; ------------------------------------------------------------

;; Store user scores with timestamp
(define-map scores 
    principal 
    { score: uint, timestamp: uint }
)

;; ------------------------------------------------------------
;; PUBLIC: Save or update a user's score
;; ------------------------------------------------------------
(define-public (save-score (score uint))
    (let (
          (sender tx-sender)
          (time stacks-block-time)
         )
        (begin
            ;; Save or update the user's score
            (map-set scores sender { score: score, timestamp: time })
            
            (ok { 
                user: sender, 
                score: score, 
                saved-at: time 
            })
        )
    )
)

;; ------------------------------------------------------------
;; READ-ONLY: Get a user's score
;; ------------------------------------------------------------
(define-read-only (get-score (user principal))
    (ok (map-get? scores user))
)

;; ------------------------------------------------------------
;; READ-ONLY: Get the current caller's score
;; ------------------------------------------------------------
(define-read-only (get-my-score)
    (ok (map-get? scores tx-sender))
)

