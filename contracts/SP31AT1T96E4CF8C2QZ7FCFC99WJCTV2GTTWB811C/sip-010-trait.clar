;; SIP-010 Fungible Token Trait
;; Standard trait for fungible tokens on Stacks

(define-trait sip-010-trait
  (
    ;; Transfer from the sender to a new principal
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))

    ;; Get the token name
    (get-name () (response (string-ascii 32) uint))

    ;; Get the token symbol
    (get-symbol () (response (string-ascii 32) uint))

    ;; Get the number of decimals used
    (get-decimals () (response uint uint))

    ;; Get the balance of the specified owner
    (get-balance (principal) (response uint uint))

    ;; Get the total supply of tokens
    (get-total-supply () (response uint uint))

    ;; Get the token URI for metadata
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)
