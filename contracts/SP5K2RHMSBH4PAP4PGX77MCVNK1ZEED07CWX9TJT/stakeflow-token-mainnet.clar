;; StakeFlow Token (STF) - SIP-010 Fungible Token
;; Reward token for StakeFlow NFT staking platform
;; MAINNET VERSION

(impl-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-TOKEN-OWNER (err u101))

;; Token definitions
(define-fungible-token stakeflow-token)

;; Data vars
(define-data-var token-name (string-ascii 32) "StakeFlow Token")
(define-data-var token-symbol (string-ascii 10) "STF")
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var token-decimals uint u6)

;; Authorized minters (rewards contract)
(define-map authorized-minters principal bool)

;; Initialize deployer as authorized minter
(map-set authorized-minters CONTRACT-OWNER true)

;; ---------------------------------------------------------
;; SIP-010 Functions
;; ---------------------------------------------------------

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
  (ok (ft-get-balance stakeflow-token account))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply stakeflow-token))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR-NOT-TOKEN-OWNER)
    (try! (ft-transfer? stakeflow-token amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)

;; ---------------------------------------------------------
;; Minting Functions (Only authorized contracts)
;; ---------------------------------------------------------

(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-authorized-minter tx-sender) ERR-NOT-AUTHORIZED)
    (ft-mint? stakeflow-token amount recipient)
  )
)

;; Contract-call mint for rewards contract
(define-public (mint-for-staking (amount uint) (recipient principal))
  (begin
    (asserts! (is-authorized-minter contract-caller) ERR-NOT-AUTHORIZED)
    (ft-mint? stakeflow-token amount recipient)
  )
)

;; ---------------------------------------------------------
;; Admin Functions
;; ---------------------------------------------------------

(define-public (set-authorized-minter (minter principal) (authorized bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-minters minter authorized))
  )
)

(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (var-set token-uri new-uri))
  )
)

;; ---------------------------------------------------------
;; Read-only Functions
;; ---------------------------------------------------------

(define-read-only (is-authorized-minter (account principal))
  (default-to false (map-get? authorized-minters account))
)

(define-read-only (get-contract-owner)
  CONTRACT-OWNER
)
