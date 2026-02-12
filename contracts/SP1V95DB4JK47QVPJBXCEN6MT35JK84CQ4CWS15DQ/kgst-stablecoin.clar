(define-fungible-token kgst)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-frozen (err u103))

(define-data-var token-uri (optional (string-utf8 256)) none)

(define-map frozen principal bool)
(define-map minters principal bool)

(define-read-only (get-name)
  (ok "Kyrgyzstani Stablecoin"))

(define-read-only (get-symbol)
  (ok "KGST"))

(define-read-only (get-decimals)
  (ok u6))

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance kgst account)))

(define-read-only (get-total-supply)
  (ok (ft-get-supply kgst)))

(define-read-only (get-token-uri)
  (ok (var-get token-uri)))

(define-read-only (is-frozen (account principal))
  (default-to false (map-get? frozen account)))

(define-read-only (is-minter (account principal))
  (default-to false (map-get? minters account)))

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (not (is-frozen sender)) err-frozen)
    (asserts! (not (is-frozen recipient)) err-frozen)
    (asserts! (is-eq tx-sender sender) err-not-authorized)
    (try! (ft-transfer? kgst amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)))

(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (or (is-eq tx-sender contract-owner) (is-minter tx-sender)) err-owner-only)
    (asserts! (not (is-frozen recipient)) err-frozen)
    (ft-mint? kgst amount recipient)))

(define-public (burn (amount uint))
  (begin
    (asserts! (not (is-frozen tx-sender)) err-frozen)
    (ft-burn? kgst amount tx-sender)))

(define-public (set-token-uri (value (string-utf8 256)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (var-set token-uri (some value)))))

(define-public (freeze-account (account principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set frozen account true))))

(define-public (unfreeze-account (account principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-delete frozen account))))

(define-public (add-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set minters minter true))))

(define-public (remove-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-delete minters minter))))
