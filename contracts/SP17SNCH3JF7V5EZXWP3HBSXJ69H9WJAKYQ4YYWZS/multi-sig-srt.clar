;; Multi-signature approval contract
(define-map signers principal bool)
(define-data-var signer-count uint u0)
(define-map approvals {id: uint} (list 10 principal))
(define-data-var approval-id uint u0)

(define-read-only (is-signer (user principal))
  (default-to false (map-get? signers user))
)

(define-public (add-signer (user principal))
  (begin
    (asserts! (is-signer tx-sender) (err u1))
    (asserts! (not (is-signer user)) (err u2))
    (map-set signers user true)
    (ok (var-set signer-count (+ (var-get signer-count) u1)))
  )
)

(define-public (remove-signer (user principal))
  (begin
    (asserts! (is-signer tx-sender) (err u1))
    (asserts! (is-signer user) (err u3))
    (map-delete signers user)
    (ok (var-set signer-count (- (var-get signer-count) u1)))
  )
)
