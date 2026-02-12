;; ------------------------------------------------------------
;; ONE WORD STORY Clarity 4 Contract
;; Users can add ONE WORD at a time.
;; Each entry is saved with:
;;  - the word
;;  - the sender (converted to ASCII text)
;;  - the block timestamp (Clarity 4 feature)
;; ------------------------------------------------------------

;; Error codes
(define-constant ERR-STORY-FULL (err u100))

;; Data store for the story an increasing list of entries
(define-data-var story (list 200 { 
    word: (string-ascii 32),
    sender: principal,
    timestamp: uint
}) 
    ;; initial empty list
    (list)
)

;; ------------------------------------------------------------
;; PUBLIC FUNCTION: Add a single word to the story
;; Users call this directly from Stacks Explorer.
;; Uses Clarity 4 timestamp and ASCII principal conversion.
;; ------------------------------------------------------------
(define-public (add-word (word (string-ascii 32)))
    (let (
            (sender tx-sender)
            (time u0)
            (current (var-get story))
         )
        ;; Prevent exceeding max length
        (if (< (len current) u200)
            (begin
                (var-set story
                    (unwrap-panic
                        (as-max-len?
                            (append current
                                { 
                                    word: word,
                                    sender: sender,
                                    timestamp: time
                                }
                            )
                            u200
                        )
                    )
                )
                (ok { added: word, by: sender, at: time })
            )
            ERR-STORY-FULL
        )
    )
)

;; ------------------------------------------------------------
;; PUBLIC VIEW: Get the whole story
;; ------------------------------------------------------------
(define-read-only (get-story)
    (ok (var-get story))
)

;; ------------------------------------------------------------
;; PUBLIC VIEW: Get the number of entries
;; ------------------------------------------------------------
(define-read-only (story-length)
    (ok (len (var-get story)))
)
