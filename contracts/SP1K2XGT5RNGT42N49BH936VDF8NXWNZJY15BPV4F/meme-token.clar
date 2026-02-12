(define-constant ERR-NOT-AUTH u100)

(define-fungible-token meme-token)

(define-data-var token-owner principal tx-sender)
(define-data-var total-supply uint u0)

(define-read-only (get-token-owner)
  (var-get token-owner)
)

(define-read-only (get-name)
  (ok u"MEME TOKEN")
)

(define-read-only (get-symbol)
  (ok u"MEME")
)

(define-read-only (get-decimals)
  (ok u6)
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-read-only (get-balance (who principal))
  (ok (ft-get-balance meme-token who))
)

(define-private (is-authorized (sender principal))
  (or (is-eq tx-sender sender) (is-eq contract-caller sender))
)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    memo
    (if (is-authorized sender)
      (match (ft-transfer? meme-token amount sender recipient)
        transferred (ok transferred)
        err (err err))
      (err ERR-NOT-AUTH)
    )
  )
)

(define-public (mint (amount uint) (recipient principal))
  (if (is-eq tx-sender (var-get token-owner))
    (match (ft-mint? meme-token amount recipient)
      minted
        (begin
          (var-set total-supply (+ (var-get total-supply) amount))
          (ok minted)
        )
      err (err err))
    (err ERR-NOT-AUTH)
  )
)

(define-public (burn (amount uint) (sender principal))
  (if (is-authorized sender)
    (match (ft-burn? meme-token amount sender)
      burned
        (begin
          (var-set total-supply (- (var-get total-supply) amount))
          (ok burned)
        )
      err (err err))
    (err ERR-NOT-AUTH)
  )
)
