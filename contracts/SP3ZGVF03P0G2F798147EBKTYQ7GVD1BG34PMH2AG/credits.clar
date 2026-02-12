;; Credits
(define-map credits principal {balance: uint})
(define-public (add-credits (amount uint))
  (let ((current (default-to u0 (get balance (map-get? credits tx-sender)))))
    (map-set credits tx-sender {balance: (+ current amount)})
    (ok true)))
(define-read-only (get-credits (user principal))
  (default-to u0 (get balance (map-get? credits user))))
