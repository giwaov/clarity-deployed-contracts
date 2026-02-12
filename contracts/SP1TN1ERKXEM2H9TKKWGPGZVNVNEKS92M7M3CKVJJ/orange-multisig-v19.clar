(define-map transactions uint {confirmed: bool})
(define-public (confirm (id uint)) (ok (map-set transactions id {confirmed: true})))
