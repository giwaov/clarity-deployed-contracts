;; Title: STX Multi-Send Public
;; Description: Robust version without lambda to ensure VM compatibility.
;; Constraints: Min 5 recipients, Max 50 recipients.

;; Error Codes
(define-constant ERR-MIN-RECIPIENTS (err u101))
(define-constant ERR-MAX-RECIPIENTS (err u102))

;; Define a data var to store the amount temporarily during the loop
(define-data-var temp-amount uint u0)

;; Public Function
(define-public (airdrop-stx (recipients (list 50 principal)) (amount-per-address uint))
  (let 
    (
      (count (len recipients))
    )
    ;; 1. Check constraints
    (asserts! (>= count u5) ERR-MIN-RECIPIENTS)
    (asserts! (<= count u50) ERR-MAX-RECIPIENTS)
    
    ;; 2. Set the amount to a global variable so the private function can read it
    (var-set temp-amount amount-per-address)

    ;; 3. Execute transfers using a named private function
    (ok (fold check-err (map send-stx-iter recipients) (ok true)))
  )
)

;; Named private function for mapping
(define-private (send-stx-iter (receiver principal))
  (stx-transfer? (var-get temp-amount) tx-sender receiver)
)

;; Helper function to handle errors in the fold
(define-private (check-err (result (response bool uint)) (prior (response bool uint)))
  (if (is-err prior) prior result)
)