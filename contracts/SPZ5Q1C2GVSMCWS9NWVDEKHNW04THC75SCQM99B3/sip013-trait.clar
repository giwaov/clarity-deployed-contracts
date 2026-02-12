(define-trait sip013-trait
  (
    ;; Transfer
    (transfer (uint uint principal principal) (response bool uint))

    ;; Get balance
    (get-balance (uint principal) (response uint uint))

    ;; Get total supply
    (get-total-supply (uint) (response uint uint))

    ;; Get decimals
    (get-decimals (uint) (response uint uint))

    ;; Get token URI
    (get-token-uri (uint) (response (optional (string-utf8 256)) uint))
  )
)
