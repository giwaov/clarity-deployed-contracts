;; SIP-010 Fungible Token Trait
;; This trait defines the standard interface for fungible tokens on Stacks
;; All fungible tokens should implement this trait for compatibility

(define-trait sip-010-trait
  (
    ;; Transfer tokens from sender to recipient
    ;; @param amount: number of tokens to transfer
    ;; @param from: sender principal
    ;; @param to: recipient principal
    ;; @param memo: optional memo for the transfer
    ;; @returns: (response bool uint) - success or error code
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))

    ;; Get the human-readable name of the token
    ;; @returns: (response (string-ascii 32) uint) - token name or error
    (get-name () (response (string-ascii 32) uint))

    ;; Get the ticker symbol of the token
    ;; @returns: (response (string-ascii 10) uint) - token symbol or error
    (get-symbol () (response (string-ascii 10) uint))

    ;; Get the number of decimals used by the token
    ;; @returns: (response uint uint) - decimal places or error
    (get-decimals () (response uint uint))

    ;; Get the balance of tokens for a specific principal
    ;; @param who: the principal to check balance for
    ;; @returns: (response uint uint) - balance or error
    (get-balance (principal) (response uint uint))

    ;; Get the total supply of tokens in circulation
    ;; @returns: (response uint uint) - total supply or error
    (get-total-supply () (response uint uint))

    ;; Get the token URI for metadata
    ;; @returns: (response (optional (string-utf8 256)) uint) - URI or error
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)