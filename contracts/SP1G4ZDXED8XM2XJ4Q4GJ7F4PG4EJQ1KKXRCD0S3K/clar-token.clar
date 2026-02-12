;; -------------------------------------------------
;; Simple Fungible Token (FT)
;; Compliant with Stacks FT standard
;; -------------------------------------------------

;; -------------------------
;; Token owner (deployer)
;; -------------------------
(define-constant CONTRACT_OWNER tx-sender)

;; -------------------------
;; Error codes
;; -------------------------
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_INSUFFICIENT_BALANCE (err u402))

;; -------------------------
;; Token definition
;; -------------------------
(define-fungible-token my-token)

;; -------------------------
;; Token metadata
;; -------------------------
(define-constant TOKEN_NAME "My Token")
(define-constant TOKEN_SYMBOL "MTK")
(define-constant TOKEN_DECIMALS u6)

;; -------------------------
;; Initial supply (1,000,000 tokens)
;; With 6 decimals = 1_000_000 * 10^6
;; -------------------------
(define-constant INITIAL_SUPPLY u1000000000000)

;; -------------------------
;; Mint initial supply to owner
;; -------------------------
(begin
    (ft-mint? my-token INITIAL_SUPPLY CONTRACT_OWNER)
)
;; -------------------------------------------------
;; Read-only functions
;; -------------------------------------------------

(define-read-only (get-name)
    TOKEN_NAME
)

(define-read-only (get-symbol)
    TOKEN_SYMBOL
)

(define-read-only (get-decimals)
    TOKEN_DECIMALS
)

(define-read-only (get-total-supply)
    (ft-get-supply my-token)
)

(define-read-only (get-balance (who principal))
    (ft-get-balance my-token who)
)

;; -------------------------------------------------
;; Public transfer function
;; -------------------------------------------------

(define-public (transfer
        (amount uint)
        (to principal)
    )
    (begin
        (asserts! (>= (ft-get-balance my-token tx-sender) amount)
            ERR_INSUFFICIENT_BALANCE
        )

        (try! (ft-transfer? my-token amount tx-sender to))

        (ok true)
    )
)

;; -------------------------------------------------
;; Owner-only mint (optional)
;; -------------------------------------------------

(define-public (mint
        (amount uint)
        (to principal)
    )
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)

        (try! (ft-mint? my-token amount to))

        (ok true)
    )
)
