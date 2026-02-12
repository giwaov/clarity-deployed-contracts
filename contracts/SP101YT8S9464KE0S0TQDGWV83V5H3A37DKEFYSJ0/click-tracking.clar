;; Click Tracking
(define-map clicks {element: (string-ascii 50), user: principal} {clicks: uint})
(define-public (track-click (element (string-ascii 50)))
  (let ((current (default-to u0 (get clicks (map-get? clicks {element: element, user: tx-sender})))))
    (map-set clicks {element: element, user: tx-sender} {clicks: (+ current u1)})
    (ok true)))
(define-read-only (get-clicks (element (string-ascii 50)) (user principal))
  (default-to u0 (get clicks (map-get? clicks {element: element, user: user}))))
