;; Client Database - Track clients
(define-map clients {provider: principal, client: principal} {name: (string-ascii 50), active: bool})

(define-public (add-client (client principal) (name (string-ascii 50)))
  (begin
    (map-set clients {provider: tx-sender, client: client} {name: name, active: true})
    (ok true)))

(define-read-only (get-client (provider principal) (client principal))
  (map-get? clients {provider: provider, client: client}))
