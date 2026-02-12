;; This contract implements the SIP-010 community-standard Fungible Token trait.

;; Define the FT, with a configurable maximum supply enforced in `mint`
(define-fungible-token clarity-coin)

;; Define errors
(define-constant ERR_OWNER_ONLY (err u100))
(define-constant ERR_NOT_TOKEN_OWNER (err u101))
(define-constant ERR_MAX_SUPPLY_REACHED (err u102))
(define-constant ERR_MINTING_PAUSED (err u103))

;; Define constants for contract
(define-constant CONTRACT_OWNER tx-sender)
(define-constant TOKEN_NAME "Clarity Coin")
(define-constant TOKEN_SYMBOL "CC")
(define-constant TOKEN_DECIMALS u6) ;; 6 units displayed past decimal, e.g. 1.000_000 = 1 token

;; Max supply in base units (e.g. 1_000_000 tokens with 6 decimals)
(define-constant MAX_SUPPLY (* u1000000 u1000000))

(define-data-var token-uri (string-utf8 256) u"https://hiro.so") ;; utf-8 string with token metadata host

;; Minting guard: owner can pause further minting once distribution is complete
(define-data-var minting-paused bool false)

;; SIP-010 function: Get the token balance of a specified principal
(define-read-only (get-balance (who principal))
  (ok (ft-get-balance clarity-coin who))
)

;; SIP-010 function: Returns the total supply of fungible token
(define-read-only (get-total-supply)
  (ok (ft-get-supply clarity-coin))
)

;; SIP-010 function: Returns the human-readable token name
(define-read-only (get-name)
  (ok TOKEN_NAME)
)

;; SIP-010 function: Returns the symbol or "ticker" for this token
(define-read-only (get-symbol)
  (ok TOKEN_SYMBOL)
)

;; SIP-010 function: Returns number of decimals to display
(define-read-only (get-decimals)
  (ok TOKEN_DECIMALS)
)

;; SIP-010 function: Returns the URI containing token metadata
(define-read-only (get-token-uri)
  (ok (some (var-get token-uri)))
)

;; Properly updates token URI by emitting a SIP-019 token metadata update notification
(define-public (set-token-uri (value (string-utf8 256)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
        (var-set token-uri value)
        (ok (print {
              notification: "token-metadata-update",
              payload: {
                contract-id: CONTRACT_OWNER,
                token-class: "ft"
              }
            })
        )
    )
)

;; Mint new tokens and send them to a recipient.
;; Only the contract deployer can perform this operation.
;; Enforces a global MAX_SUPPLY and an owner-controlled pause switch.
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (asserts! (not (var-get minting-paused)) ERR_MINTING_PAUSED)
    (let (
      (current-supply (ft-get-supply clarity-coin))
      (new-supply (+ current-supply amount))
    )
      (asserts! (<= new-supply MAX_SUPPLY) ERR_MAX_SUPPLY_REACHED)
    )
    (ft-mint? clarity-coin amount recipient)
  )
)

;; Owner-only control to permanently (or temporarily) pause minting.
(define-public (set-minting-paused (value bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (var-set minting-paused value)
    (ok value)
  )
)

;; SIP-010 function: Transfers tokens to a recipient
;; Sender must be the same as the caller to prevent principals from transferring tokens they do not own.
(define-public (transfer
  (amount uint)
  (sender principal)
  (recipient principal)
  (memo (optional (buff 34)))
)
  (begin
    ;; #[filter(amount, recipient)]
    (asserts! (or (is-eq tx-sender sender) (is-eq contract-caller sender)) ERR_NOT_TOKEN_OWNER)
    (try! (ft-transfer? clarity-coin amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)