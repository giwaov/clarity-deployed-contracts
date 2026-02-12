;; Contract Name: incinerator-test
;; Description: Permanently burns STX. Accepts u0 for gas-only testing.
;; Clarity Version: 4

;; Public function to burn STX
(define-public (burn (amount uint))
    (begin
        ;; REMOVED: (asserts! (> amount u0) ...) to allow 0 STX testing
        
        ;; If amount is u0, this succeeds but burns nothing. 
        ;; You pay only gas fees.
        (stx-burn? amount tx-sender)
    )
)

(define-read-only (get-burn-message)
    (ok "Ready to incinerate.")
)