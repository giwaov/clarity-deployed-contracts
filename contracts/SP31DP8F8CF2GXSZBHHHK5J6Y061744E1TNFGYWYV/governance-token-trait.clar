
;; governance-token-trait.clar
;; Trait definition for governance tokens with snapshot capabilities (simplified).
;; CLARITY VERSION: 4

(use-trait sip-010-trait .sip-010-trait-ft-standard.sip-010-trait)

(define-trait governance-token-trait
    (
        ;; Inherits SIP-010
        (transfer (uint principal principal (optional (buff 34))) (response bool uint))
        (get-name () (response (string-ascii 32) uint))
        (get-symbol () (response (string-ascii 10) uint))
        (get-decimals () (response uint uint))
        (get-balance (principal) (response uint uint))
        (get-total-supply () (response uint uint))
        (get-token-uri () (response (optional (string-utf8 256)) uint))

        ;; Governance specific
        (get-balance-at-block (principal uint) (response uint uint))
        (get-total-supply-at-block (uint) (response uint uint))
    )
)
