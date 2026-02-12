;; simple-nft.clar

(define-constant ERR-NOT-OWNER u401)
(define-constant ERR-NOT-TOKEN-OWNER u404)

(define-non-fungible-token simple-nft uint)

(define-data-var owner principal tx-sender)
(define-data-var next-id uint u1)

(define-public (mint (recipient principal))
  (if (is-eq tx-sender (var-get owner))
    (let ((id (var-get next-id)))
      (var-set next-id (+ id u1))
      (try! (nft-mint? simple-nft id recipient))
      (ok id))
    (err ERR-NOT-OWNER)))

(define-public (transfer (id uint) (sender principal) (recipient principal))
  (if (is-eq tx-sender sender)
    (match (nft-transfer? simple-nft id sender recipient)
      ok-val (ok true)
      err-val (err ERR-NOT-TOKEN-OWNER))
    (err ERR-NOT-OWNER)))

(define-read-only (get-owner-of (id uint))
  (ok (nft-get-owner? simple-nft id)))