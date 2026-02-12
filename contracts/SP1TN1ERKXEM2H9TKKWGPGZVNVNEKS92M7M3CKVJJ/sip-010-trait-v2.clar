;; SIP-010 Fungible Token Trait
;; Standard trait definition for fungible tokens

(define-trait sip-010-trait
  (
    ;; Transfer from the caller to a new principal
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))

    ;; Human readable name of the token
    (get-name () (response (string-ascii 32) uint))

    ;; Human readable symbol of the token
    (get-symbol () (response (string-ascii 32) uint))

    ;; The number of decimals used
    (get-decimals () (response uint uint))

    ;; The current total supply (optional)
    (get-total-supply () (response uint uint))

    ;; Get the token balance of the specified principal
    (get-balance (principal) (response uint uint))

    ;; Get the current URI (optional)
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)
