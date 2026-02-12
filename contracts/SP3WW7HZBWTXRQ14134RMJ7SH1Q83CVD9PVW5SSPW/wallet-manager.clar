;; Multi-Sig Wallet Manager

(define-constant contract-owner tx-sender)
(define-data-var required-signatures uint u2)

(define-map signers principal bool)
(define-map pending-transactions uint { amount: uint, recipient: principal, signatures: uint })
(define-data-var next-tx-id uint u1)

(define-public (add-signer (signer principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err u100))
    (map-set signers signer true)
    (ok true)
  )
)

(define-public (propose-transaction (amount uint) (recipient principal))
  (let ((tx-id (var-get next-tx-id)))
    (asserts! (default-to false (map-get? signers tx-sender)) (err u101))
    (map-set pending-transactions tx-id { amount: amount, recipient: recipient, signatures: u1 })
    (var-set next-tx-id (+ tx-id u1))
    (ok tx-id)
  )
)
