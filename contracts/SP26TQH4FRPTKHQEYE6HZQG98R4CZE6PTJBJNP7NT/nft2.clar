(define-non-fungible-token game-item uint)
(define-data-var last-id uint u0)

(define-public (mint (to principal))
  (let ((id (+ (var-get last-id) u1)))
    (begin
      (try! (nft-mint? game-item id to))
      (var-set last-id id)
      (ok id)
    )
  )
)
