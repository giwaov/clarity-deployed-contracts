;; simple-whitelist.clar

(define-constant ERR-NOT-OWNER u401)
(define-data-var owner principal tx-sender)
(define-map whitelist {user: principal} {ok: bool})

(define-read-only (is-whitelisted (user principal))
  (default-to false (get ok (map-get? whitelist {user: user}))))

(define-public (add (user principal))
  (if (is-eq tx-sender (var-get owner))
    (begin (map-set whitelist {user: user} {ok: true}) (ok true))
    (err ERR-NOT-OWNER)))

(define-public (remove (user principal))
  (if (is-eq tx-sender (var-get owner))
    (begin (map-delete whitelist {user: user}) (ok true))
    (err ERR-NOT-OWNER)))
