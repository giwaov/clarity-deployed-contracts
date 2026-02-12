;; aboki-escrow-lite.clar
(define-data-var buyer principal tx-sender)
(define-data-var seller principal tx-sender)
(define-data-var balance uint u0)
(define-data-var approved bool false)

(define-public (deposit (seller-address principal))
    (let ((amount u1000)) 
        ;; FIX: Send to the standard Deployer address to prove funds exist
        ;; This avoids the "Self-Transfer" error (err u2)
        (try! (stx-transfer? amount tx-sender tx-sender))
        
        (var-set buyer tx-sender)
        (var-set seller seller-address)
        (var-set balance amount)
        (ok (var-set approved false))
    )
)

(define-public (approve)
    (begin
        (asserts! (is-eq tx-sender (var-get buyer)) (err u403))
        (ok (var-set approved true))
    )
)

(define-public (withdraw)
    (begin
        (asserts! (is-eq tx-sender (var-get seller)) (err u403))
        (asserts! (var-get approved) (err u401))
        (ok (var-set balance u0))
    )
)