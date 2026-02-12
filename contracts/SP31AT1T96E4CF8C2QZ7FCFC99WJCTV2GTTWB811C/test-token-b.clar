;; Test Token B (e.g., USDA-like stablecoin for testing)
;; Implements SIP-010 fungible token standard

(impl-trait .sip-010-trait.sip-010-trait)

;; Token configuration
(define-constant contract-owner tx-sender)
(define-constant token-name "Test Token B")
(define-constant token-symbol "TTB")
(define-constant token-decimals u6)
(define-constant token-uri u"https://example.com/token-b.json")

;; Error codes
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-insufficient-balance (err u102))

;; Storage
(define-fungible-token test-token-b)

;; Private functions
(define-private (check-err (result (response bool uint)) (prior (response bool uint)))
  (match prior ok-value result err-value (err err-value))
)

;; SIP-010 implementation
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) err-not-token-owner)
    (try! (ft-transfer? test-token-b amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)

(define-read-only (get-name)
  (ok token-name)
)

(define-read-only (get-symbol)
  (ok token-symbol)
)

(define-read-only (get-decimals)
  (ok token-decimals)
)

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance test-token-b account))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply test-token-b))
)

(define-read-only (get-token-uri)
  (ok (some token-uri))
)

;; Mint function for testing
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ft-mint? test-token-b amount recipient)
  )
)

;; Initialize with some supply for testing
(begin
  (try! (ft-mint? test-token-b u1000000000000 contract-owner))
  (ok true)
)
