;; @clarity-version 2
;; KoloX Constants

;; Version
(define-read-only (CONTRACT-VERSION) u1)

;; Error codes - Authorization
(define-read-only (ERR-NOT-AUTHORIZED) (err u100))

;; Error codes - Kolo state
(define-read-only (ERR-KOLO-NOT-FOUND) (err u101))
(define-read-only (ERR-KOLO-FULL) (err u102))
(define-read-only (ERR-KOLO-NOT-ACTIVE) (err u110))
(define-read-only (ERR-PAUSED) (err u113))
(define-read-only (ERR-KOLO-STARTED) (err u115))

;; Error codes - Membership
(define-read-only (ERR-ALREADY-MEMBER) (err u103))
(define-read-only (ERR-NOT-MEMBER) (err u104))
(define-read-only (ERR-ALREADY-WITHDRAWN) (err u114))

;; Error codes - Payments
(define-read-only (ERR-ALREADY-PAID) (err u105))
(define-read-only (ERR-WRONG-AMOUNT) (err u106))
(define-read-only (ERR-NOT-STARTED) (err u107))
(define-read-only (ERR-PAYOUT-NOT-READY) (err u108))
(define-read-only (ERR-NOT-YOUR-TURN) (err u109))

;; Error codes - Validation
(define-read-only (ERR-INVALID-PARAMS) (err u111))
(define-read-only (ERR-CANNOT-JOIN) (err u112))

;; Frequency constants (in blocks - Stacks block time ~10 minutes)
(define-read-only (WEEKLY) u1008) ;; ~7 days
(define-read-only (MONTHLY) u4320) ;; ~30 days
(define-read-only (GRACE-PERIOD) u144) ;; ~1 day grace period
(define-read-only (MIN-CONTRIBUTION) u1000000) ;; 1 STX minimum
(define-read-only (MAX-MEMBERS) u50) ;; Maximum members per kolo
(define-read-only (MIN-MEMBERS) u2) ;; Minimum members per kolo
(define-read-only (BLOCKS-PER-DAY) u144) ;; ~10 min per block
