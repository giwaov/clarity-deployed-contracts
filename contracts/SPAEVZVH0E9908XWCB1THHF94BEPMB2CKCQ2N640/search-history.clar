;; Search History Contract
;; Users can save addresses they search for

;; Store list of searched addresses per user
;; Key: user principal, Value: list of addresses (max 20)
(define-map search-history
  principal
  (list 20 principal)
)

;; Error codes
(define-constant ERR-LIST-FULL (err u1))
(define-constant ERR-ALREADY-EXISTS (err u2))

;; Add an address to user's search history
(define-public (add-to-history (searched-address principal))
  (let (
    (current-list (default-to (list) (map-get? search-history tx-sender)))
  )
    ;; Check if address already in list
    (asserts! (is-none (index-of current-list searched-address)) ERR-ALREADY-EXISTS)
    
    ;; Check if list is full
    (asserts! (< (len current-list) u20) ERR-LIST-FULL)
    
    ;; Add to list
    (ok (map-set search-history 
      tx-sender 
      (unwrap-panic (as-max-len? (append current-list searched-address) u20))
    ))
  )
)

;; Get user's search history
(define-read-only (get-history (user principal))
  (ok (default-to (list) (map-get? search-history user)))
)

;; Clear user's search history
(define-public (clear-history)
  (ok (map-delete search-history tx-sender))
)