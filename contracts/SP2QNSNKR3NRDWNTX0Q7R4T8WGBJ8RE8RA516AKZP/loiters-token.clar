;; Loiters Token (LOIT)
;; SIP-010 Fungible Token for platform rewards

(impl-trait .sip-010-trait.sip-010-trait)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant TOKEN-NAME "Loiters Token")
(define-constant TOKEN-SYMBOL "LOIT")
(define-constant TOKEN-DECIMALS u6)
(define-constant TOKEN-TOTAL-SUPPLY u1000000000000000) ;; 1 billion tokens with 6 decimals

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u2000))
(define-constant ERR-INSUFFICIENT-BALANCE (err u2001))
(define-constant ERR-INVALID-AMOUNT (err u2002))

;; Data Variables
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var contract-paused bool false)

;; Data Maps
(define-map balances principal uint)
(define-map allowances {owner: principal, spender: principal} uint)
(define-map authorized-minters principal bool)

;; Initialize contract owner balance
(map-set balances CONTRACT-OWNER TOKEN-TOTAL-SUPPLY)

;; SIP-010 Functions

(define-read-only (get-name)
  (ok TOKEN-NAME)
)

(define-read-only (get-symbol)
  (ok TOKEN-SYMBOL)
)

(define-read-only (get-decimals)
  (ok TOKEN-DECIMALS)
)

(define-read-only (get-balance (account principal))
  (ok (default-to u0 (map-get? balances account)))
)

(define-read-only (get-total-supply)
  (ok TOKEN-TOTAL-SUPPLY)
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (try! (transfer-internal sender recipient amount))
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)

;; Internal transfer function
(define-private (transfer-internal (sender principal) (recipient principal) (amount uint))
  (let
    (
      (sender-balance (default-to u0 (map-get? balances sender)))
      (recipient-balance (default-to u0 (map-get? balances recipient)))
    )
    (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
    (map-set balances sender (- sender-balance amount))
    (map-set balances recipient (+ recipient-balance amount))
    (print {type: "transfer", sender: sender, recipient: recipient, amount: amount})
    (ok true)
  )
)

;; Minting function (only authorized contracts)
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-authorized-minter tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (let
      (
        (recipient-balance (default-to u0 (map-get? balances recipient)))
      )
      (map-set balances recipient (+ recipient-balance amount))
      (print {type: "mint", recipient: recipient, amount: amount})
      (ok true)
    )
  )
)

;; Authorization functions
(define-public (authorize-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-minters minter true))
  )
)

(define-public (revoke-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-delete authorized-minters minter))
  )
)

(define-read-only (is-authorized-minter (minter principal))
  (default-to false (map-get? authorized-minters minter))
)

;; Admin functions
(define-public (set-token-uri (new-uri (string-utf8 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (var-set token-uri (some new-uri)))
  )
)

(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (var-set contract-paused true))
  )
)

(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (var-set contract-paused false))
  )
)
