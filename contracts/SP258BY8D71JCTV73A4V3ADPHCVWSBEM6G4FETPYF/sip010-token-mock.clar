;; SIP-010 Fungible Token Mock
;; A simple test token for testing multi-token support in StacksTacToe
;; Implements the SIP-010 fungible token standard

(impl-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; ============================================
;; Constants
;; ============================================

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u1))
(define-constant ERR_NOT_TOKEN_OWNER (err u2))
(define-constant ERR_INSUFFICIENT_BALANCE (err u3))

;; Token metadata
(define-constant TOKEN_NAME "Mock Token")
(define-constant TOKEN_SYMBOL "MOCK")
(define-constant TOKEN_DECIMALS u6)

;; ============================================
;; Data Variables
;; ============================================

(define-fungible-token mock-token)

;; ============================================
;; SIP-010 Functions
;; ============================================

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
        (try! (ft-transfer? mock-token amount sender recipient))
        (match memo to-print (print to-print) 0x)
        (ok true)
    )
)

(define-read-only (get-name)
    (ok TOKEN_NAME)
)

(define-read-only (get-symbol)
    (ok TOKEN_SYMBOL)
)

(define-read-only (get-decimals)
    (ok TOKEN_DECIMALS)
)

(define-read-only (get-balance (account principal))
    (ok (ft-get-balance mock-token account))
)

(define-read-only (get-total-supply)
    (ok (ft-get-supply mock-token))
)

(define-read-only (get-token-uri)
    (ok none)
)

;; ============================================
;; Mint Function (for testing only)
;; ============================================

(define-public (mint (amount uint) (recipient principal))
    (begin
        ;; In production, this would be restricted to owner
        ;; For testing, anyone can mint
        (ft-mint? mock-token amount recipient)
    )
)

;; ============================================
;; Initialization
;; ============================================

;; Mint initial supply to contract owner for testing
(ft-mint? mock-token u1000000000000 CONTRACT_OWNER)
