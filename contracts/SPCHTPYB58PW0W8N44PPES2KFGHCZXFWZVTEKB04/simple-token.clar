;; Simple Fungible Token (SIP-010)
;; A basic fungible token implementation

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-insufficient-balance (err u102))

;; Token definition
(define-fungible-token simple-token u1000000000)

;; SIP-010 Functions
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (asserts! (<= amount (ft-get-balance simple-token sender)) err-insufficient-balance)
        (try! (ft-transfer? simple-token amount sender recipient))
        (match memo to-print (print to-print) 0x)
        (ok true)
    )
)

(define-read-only (get-name)
    (ok "Simple Token")
)

(define-read-only (get-symbol)
    (ok "SIMP")
)

(define-read-only (get-decimals)
    (ok u6)
)

(define-read-only (get-balance (who principal))
    (ok (ft-get-balance simple-token who))
)

(define-read-only (get-total-supply)
    (ok (ft-get-supply simple-token))
)

(define-read-only (get-token-uri)
    (ok (some u"https://example.com/token-metadata.json"))
)

;; Mint initial supply to contract owner
(begin
    (try! (ft-mint? simple-token u1000000000 contract-owner))
)
