
;; centrifuge-king
;; A King of the Hill game where users pay to become the King.
;; The cost to become King increases with each claim.

;; constants
(define-constant err-not-enough-payment (err u100))
(define-constant contract-owner tx-sender)

;; data vars
(define-data-var current-king principal tx-sender)
(define-data-var current-price uint u1000000) ;; Starts at 1 STX (microSTX)
(define-data-var message (string-utf8 100) u"I am the King!")

;; public functions

(define-read-only (get-king-info)
  (ok {
    king: (var-get current-king),
    price: (var-get current-price),
    message: (var-get message)
  })
)

(define-public (claim-crown (new-message (string-utf8 100)))
  (let
    (
      (price (var-get current-price))
      (previous-king (var-get current-king))
    )
    ;; Ensure sender pays the current price to the previous king
    ;; If previous king is contract owner (initial state), pay to contract owner
    (try! (stx-transfer? price tx-sender previous-king))
    
    ;; Update state
    (var-set current-king tx-sender)
    (var-set current-price (+ price u100000)) ;; Increase price by 0.1 STX
    (var-set message new-message)
    
    ;; Emit event for chainhook
    (print {
      event: "claim-crown",
      king: tx-sender,
      price: (var-get current-price),
      message: new-message
    })
    
    (ok true)
  )
)
