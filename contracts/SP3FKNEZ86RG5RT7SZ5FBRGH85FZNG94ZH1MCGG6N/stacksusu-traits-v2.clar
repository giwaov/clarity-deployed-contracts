;; StackSUSU Traits
;; Defines interfaces for the StackSUSU protocol

;; ==============================================
;; CONSTANTS
;; ==============================================

;; Time constants (Stacks blocks, ~10 min per block)
(define-constant BLOCKS-PER-DAY u144)
(define-constant MIN-PAYOUT-INTERVAL-DAYS u1)
(define-constant MAX-PAYOUT-INTERVAL-DAYS u30)

;; Member limits
(define-constant MIN-MEMBERS u25)
(define-constant MAX-MEMBERS u50)

;; Contribution limits (in microSTX, 1 STX = 1,000,000 microSTX)
(define-constant MIN-CONTRIBUTION u500000)   ;; 0.5 STX
(define-constant MAX-CONTRIBUTION u10000000) ;; 10 STX

;; Fee constants
(define-constant EMERGENCY-FEE-BPS u200) ;; 2% = 200 basis points
(define-constant ADMIN-FEE-BPS u50)      ;; 0.5% admin fee on payouts

;; ==============================================
;; ERROR CODES
;; ==============================================

(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-CIRCLE-NOT-FOUND (err u1001))
(define-constant ERR-CIRCLE-FULL (err u1002))
(define-constant ERR-CIRCLE-NOT-FULL (err u1003))
(define-constant ERR-ALREADY-MEMBER (err u1004))
(define-constant ERR-NOT-MEMBER (err u1005))
(define-constant ERR-INVALID-AMOUNT (err u1006))
(define-constant ERR-INVALID-MEMBERS (err u1007))
(define-constant ERR-INVALID-INTERVAL (err u1008))
(define-constant ERR-ALREADY-DEPOSITED (err u1009))
(define-constant ERR-NOT-DEPOSITED (err u1010))
(define-constant ERR-DEPOSITS-INCOMPLETE (err u1011))
(define-constant ERR-PAYOUT-NOT-DUE (err u1012))
(define-constant ERR-ALREADY-CLAIMED (err u1013))
(define-constant ERR-NOT-YOUR-TURN (err u1014))
(define-constant ERR-CIRCLE-NOT-ACTIVE (err u1015))
(define-constant ERR-CIRCLE-COMPLETED (err u1016))
(define-constant ERR-TRANSFER-FAILED (err u1017))
(define-constant ERR-EMERGENCY-NOT-ALLOWED (err u1018))
(define-constant ERR-ALREADY-RECEIVED-PAYOUT (err u1019))
(define-constant ERR-CIRCLE-NOT-STARTED (err u1020))
(define-constant ERR-PAUSED (err u1021))
(define-constant ERR-INVALID-SLOT (err u1022))
(define-constant ERR-ZERO-AMOUNT (err u1023))
