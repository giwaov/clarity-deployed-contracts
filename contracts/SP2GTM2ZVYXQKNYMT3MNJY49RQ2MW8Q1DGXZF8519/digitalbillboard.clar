;; Digital Billboard Contract

;; Data variables to track the message, current price, and owner
(define-data-var billboard-message (string-ascii 50) "Your Ad Here")
(define-data-var current-price uint u100) ;; Price in micro-STX (100 = 0.0001 STX)
(define-data-var current-owner principal tx-sender)

;; Read-only function to get current billboard status
(define-read-only (get-billboard-status)
  {
    message: (var-get billboard-message),
    price: (var-get current-price),
    owner: (var-get current-owner)
  }
)

;; Public function to buy the billboard and update the message
(define-public (buy-billboard (new-message (string-ascii 50)) (pay-amount uint))
  (let ((price (var-get current-price)))
    ;; Check if the paid amount is greater than the current price
    (asserts! (> pay-amount price) (err u403))
    
    ;; Transfer STX from the buyer to the previous owner
    (try! (stx-transfer? pay-amount tx-sender (var-get current-owner)))
    
    ;; Update the billboard state
    (var-set billboard-message new-message)
    (var-set current-price pay-amount)
    (var-set current-owner tx-sender)
    
    (ok "Billboard updated successfully!")
  )
)
