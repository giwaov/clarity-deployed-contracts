;; Warranty Claims
(define-map claims {claim-id: uint} {claimant: principal, product-id: uint, issue: (string-ascii 200), filed-at: uint, status: (string-ascii 20)})
(define-public (file-claim (claim-id uint) (product-id uint) (issue (string-ascii 200)) (filed-at uint) (status (string-ascii 20)))
  (begin (map-set claims {claim-id: claim-id} {claimant: tx-sender, product-id: product-id, issue: issue, filed-at: filed-at, status: status}) (ok true)))
(define-read-only (get-claim (claim-id uint))
  (map-get? claims {claim-id: claim-id}))
