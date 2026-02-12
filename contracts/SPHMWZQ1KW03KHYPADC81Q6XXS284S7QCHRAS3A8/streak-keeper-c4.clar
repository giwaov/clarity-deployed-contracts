
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-LOGGED-TODAY (err u403))

(define-constant BLOCKS-PER-DAY u144) 

(define-map DiaryEntries 
    { user: principal, id: uint } 
    { content: (string-utf8 280), height: uint }
)

(define-map UserStreaks 
    principal 
    { current-streak: uint, last-log-height: uint, total-entries: uint }
)



(define-public (log-entry (content (string-utf8 280)))
    (let 
        (
            (caller tx-sender)
            (current-stats (default-to { current-streak: u0, last-log-height: u0, total-entries: u0 } (map-get? UserStreaks caller)))
            (last-height (get last-log-height current-stats))
            (current-streak (get current-streak current-stats))
            (new-id (+ (get total-entries current-stats) u1))

            (current-height burn-block-height)
            
            (diff (- current-height last-height))
        )

        (let 
            (
                (new-streak 
                    (if (is-eq last-height u0)
                        u1 
                        (if (< diff BLOCKS-PER-DAY)
                            current-streak 
                            (if (< diff (* BLOCKS-PER-DAY u2))
                                (+ current-streak u1)
                                u1 
                            )
                        )
                    )
                )
            )
            
       
            (map-insert DiaryEntries 
                { user: caller, id: new-id } 
                { content: content, height: current-height }
            )

   
            (map-set UserStreaks 
                caller 
                { 
                    current-streak: new-streak, 
                    last-log-height: current-height, 
                    total-entries: new-id 
                }
            )

      
            (print { event: "journal-logged", user: caller, streak: new-streak, id: new-id })
            
            (ok new-streak)
        )
    )
)



(define-read-only (get-user-stats (user principal))
    (ok (default-to { current-streak: u0, last-log-height: u0, total-entries: u0 } (map-get? UserStreaks user)))
)

(define-read-only (get-entry (user principal) (id uint))
    (ok (map-get? DiaryEntries { user: user, id: id }))
)

(define-read-only (get-current-streak (user principal))
    (let 
        ((stats (default-to { current-streak: u0, last-log-height: u0, total-entries: u0 } (map-get? UserStreaks user))))
        (ok (get current-streak stats))
    )
)