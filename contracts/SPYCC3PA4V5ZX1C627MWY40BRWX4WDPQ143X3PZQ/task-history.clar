;; ---------------------------------------------------------
;; Task History
;; Stores task lifecycle notes
;; ---------------------------------------------------------

(define-map history uint (string-ascii 50))


(define-public (record (task-id uint) (note (string-ascii 50)))
    (begin
        (map-set history task-id note)
        (ok note)
    )
)
