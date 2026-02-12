(define-map content {hash: (buff 32)} {url: (string-ascii 200), attestor: principal})
(define-data-var paused bool false)
(define-data-var admin (optional principal) none)

(define-private (is-admin (p principal))
  (match (var-get admin)
    admin-p (is-eq p admin-p)
    false))

(define-public (init-admin (p principal))
  (if (is-none (var-get admin))
      (begin (var-set admin (some p)) (ok true))
      (err u1002)))

(define-public (attest (hash (buff 32)) (url (string-ascii 200)))
  (if (var-get paused)
      (err u1000)
      (begin
        (map-set content {hash: hash} {url: url, attestor: tx-sender})
        (ok true)
      )))

(define-public (pause)
  (if (is-admin tx-sender)
      (begin (var-set paused true) (ok true))
      (err u1003)))

(define-public (unpause)
  (if (is-admin tx-sender)
      (begin (var-set paused false) (ok true))
      (err u1003)))
