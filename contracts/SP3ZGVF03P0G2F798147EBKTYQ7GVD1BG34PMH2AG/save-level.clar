;; ------------------------------------------------------------
;; LEVEL SAVING CONTRACT 
;; ------------------------------------------------------------

;; Store user levels with timestamp
(define-map levels 
    principal 
    { level: uint, timestamp: uint }
)

;; ------------------------------------------------------------
;; PUBLIC: Save or update a user's level
;; ------------------------------------------------------------
(define-public (save-level (level uint))
    (let (
          (sender tx-sender)
          (time stacks-block-time)
         )
        (begin
            ;; Save or update the user's level
            (map-set levels sender { level: level, timestamp: time })
            
            (ok { 
                user: sender, 
                level: level, 
                saved-at: time 
            })
        )
    )
)

;; ------------------------------------------------------------
;; READ-ONLY: Get a user's level
;; ------------------------------------------------------------
(define-read-only (get-level (user principal))
    (ok (map-get? levels user))
)

;; ------------------------------------------------------------
;; READ-ONLY: Get the current caller's level
;; ------------------------------------------------------------
(define-read-only (get-my-level)
    (ok (map-get? levels tx-sender))
)

