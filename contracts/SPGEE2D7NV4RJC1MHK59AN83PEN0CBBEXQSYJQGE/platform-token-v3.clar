;; Platform Token Contract - Clarity 4
;; SIP-010 compliant fungible token for the marketplace platform

(impl-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

(define-fungible-token platform-token)

(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-invalid-amount (err u102))

(define-data-var token-name (string-ascii 32) "Platform Token")
(define-data-var token-symbol (string-ascii 10) "PLAT")
(define-data-var token-decimals uint u6)
(define-data-var token-uri (optional (string-utf8 256)) none)

;; SIP-010 functions
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) err-not-authorized)
    (try! (ft-transfer? platform-token amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)

(define-read-only (get-name)
  (ok (var-get token-name))
)

(define-read-only (get-symbol)
  (ok (var-get token-symbol))
)

(define-read-only (get-decimals)
  (ok (var-get token-decimals))
)

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance platform-token account))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply platform-token))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

;; Mint tokens (owner only)
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
    (asserts! (> amount u0) err-invalid-amount)
    (ft-mint? platform-token amount recipient)
  )
)

;; Burn tokens
(define-public (burn (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (ft-burn? platform-token amount tx-sender)
  )
)

;; Update token URI (owner only)
(define-public (set-token-uri (new-uri (string-utf8 256)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
    (var-set token-uri (some new-uri))
    (ok true)
  )
)

;; Initialize with supply
(begin
  (try! (ft-mint? platform-token u1000000000000 contract-owner))
)
