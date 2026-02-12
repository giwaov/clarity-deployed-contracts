;; Mock SIP-010 Token Contract for Testing
;; Implements a simple fungible token following the SIP-010 standard
;; Used for testing the multisig vault's token transfer functionality

;; Import SIP-010 trait
(impl-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; Define the fungible token
(define-fungible-token mock-token)

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u1))

;; SIP-010 Standard Functions

;; Transfer tokens from sender to recipient
(define-public (transfer 
    (amount uint) 
    (sender principal) 
    (recipient principal) 
    (memo (optional (buff 34)))
)
    (begin
        ;; Verify sender is tx-sender
        (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
        (asserts! (> amount u0) (err u3))
        ;; Execute transfer
        (try! (ft-transfer? mock-token amount sender recipient))
        (match memo to-print (print to-print) 0x)
        (ok true)
    )
)

;; Get token name
(define-read-only (get-name)
    (ok "Mock Token")
)

;; Get token symbol
(define-read-only (get-symbol)
    (ok "MT")
)

;; Get token decimals
(define-read-only (get-decimals)
    (ok u6)
)

;; Get balance of a principal
(define-read-only (get-balance (who principal))
    (ok (ft-get-balance mock-token who))
)

;; Get total supply
(define-read-only (get-total-supply)
    (ok (ft-get-supply mock-token))
)

;; Get token URI (returns none for this mock token)
(define-read-only (get-token-uri)
    (ok none)
)

;; ============================================
;; Testing Helper Functions
;; ============================================

;; Mint tokens to a recipient (for testing only)
(define-public (mint (amount uint) (recipient principal))
    (begin
        (asserts! (> amount u0) (err u3))
        (try! (ft-mint? mock-token amount recipient))
        (ok true)
    )
)
