;; Simple Token Contract (SIP-010 compatible)
;; A basic fungible token implementation

(define-fungible-token simple-token)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-invalid-amount (err u102))

(define-data-var token-name (string-ascii 32) "SimpleToken")
(define-data-var token-symbol (string-ascii 10) "SIMPLE")
(define-data-var token-decimals uint u6)
(define-data-var token-uri (optional (string-utf8 256)) none)

;; SIP-010 Interface
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
  (ok (ft-get-balance simple-token account))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply simple-token))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

;; Transfer tokens
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err u103))
    (asserts! (> amount u0) err-invalid-amount)
    (try! (ft-transfer? simple-token amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)

;; Mint tokens (owner only)
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> amount u0) err-invalid-amount)
    (ft-mint? simple-token amount recipient)
  )
)

;; Burn tokens
(define-public (burn (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (ft-burn? simple-token amount tx-sender)
  )
)

;; Faucet - anyone can claim 1000 tokens once
(define-map claimed-faucet principal bool)

(define-public (claim-faucet)
  (begin
    (asserts! (is-none (map-get? claimed-faucet tx-sender)) (err u104))
    (map-set claimed-faucet tx-sender true)
    (ft-mint? simple-token u1000000000 tx-sender)
  )
)

;; Check if faucet claimed
(define-read-only (has-claimed-faucet (account principal))
  (ok (default-to false (map-get? claimed-faucet account)))
)
