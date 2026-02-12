;; ClawBTC Token - Inspired by Clawbot, a claw agent token on Stacks
;; SIP-010 Fungible Token Standard

(define-fungible-token claw-btc u1000000000000) ;; Total supply: 1,000,000 with 6 decimals (1e6 * 1e6 = 1e12 micro-units)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))

;; SIP-010 Functions

(define-trait ft-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) err-not-token-owner)
    (try! (ft-transfer? claw-btc amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)

(define-read-only (get-name)
  (ok "ClawBTC")
)

(define-read-only (get-symbol)
  (ok "CBTC")
)

(define-read-only (get-decimals)
  (ok u6)
)

(define-read-only (get-balance (who principal))
  (ok (ft-get-balance claw-btc who))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply claw-btc))
)

(define-read-only (get-token-uri)
  (ok (some u"https://example.com/clawbtc-metadata.json")) ;; Replace with your metadata URI
)

;; Mint initial supply to deployer (for testing/distribution)
(begin
  (try! (ft-mint? claw-btc u1000000000000 contract-owner))
)