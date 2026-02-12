;; Notifaya Donation Contract
;; Simple contract to receive 1 STX donations

;; Constants
(define-constant contract-owner 'ST267C6MQJHPR7297033Z8VSKTJM7M62V3784NDT5)
(define-constant donation-amount u1000000)

;; Data variable to track total donations
(define-data-var total-donations uint u0)

;; Map to track individual donor contributions
(define-map donations principal uint)

;; Public function to donate 1 STX
(define-public (donate)
  (let
    (
      (donor tx-sender)
      (current-donation (default-to u0 (map-get? donations donor)))
    )
    (try! (stx-transfer? donation-amount donor contract-owner))
    (map-set donations donor (+ current-donation donation-amount))
    (var-set total-donations (+ (var-get total-donations) donation-amount))
    (print { event: "donation", from: donor, to: contract-owner, amount: donation-amount })
    (ok true)
  )
)

(define-read-only (get-total-donations)
  (ok (var-get total-donations))
)

(define-read-only (get-donor-amount (donor principal))
  (ok (default-to u0 (map-get? donations donor)))
)
