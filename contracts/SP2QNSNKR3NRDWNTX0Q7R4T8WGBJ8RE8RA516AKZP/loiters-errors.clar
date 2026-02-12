;; Loiters Error Codes
;; Centralized error definitions for all Loiters contracts

;; General Errors (1000-1099)
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-ALREADY-EXISTS (err u1001))
(define-constant ERR-NOT-FOUND (err u1002))
(define-constant ERR-INVALID-PARAMS (err u1003))
(define-constant ERR-CONTRACT-PAUSED (err u1004))

;; User Errors (1100-1199)
(define-constant ERR-USER-NOT-REGISTERED (err u1100))
(define-constant ERR-USERNAME-TAKEN (err u1101))
(define-constant ERR-INVALID-USERNAME (err u1102))
(define-constant ERR-USER-ALREADY-REGISTERED (err u1103))

;; Reputation Errors (1200-1299)
(define-constant ERR-INSUFFICIENT-REPUTATION (err u1200))
(define-constant ERR-REPUTATION-OVERFLOW (err u1201))

;; Check-in Errors (1300-1399)
(define-constant ERR-CHECKIN-TOO-SOON (err u1300))
(define-constant ERR-INVALID-LOCATION (err u1301))
(define-constant ERR-CHECKIN-LIMIT-REACHED (err u1302))

;; Endorsement Errors (1400-1499)
(define-constant ERR-CANNOT-ENDORSE-SELF (err u1400))
(define-constant ERR-ENDORSEMENT-COOLDOWN (err u1401))
(define-constant ERR-ALREADY-ENDORSED (err u1402))

;; Token Errors (1500-1599)
(define-constant ERR-INSUFFICIENT-BALANCE (err u1500))
(define-constant ERR-TRANSFER-FAILED (err u1501))
(define-constant ERR-MINT-FAILED (err u1502))

;; Badge/NFT Errors (1600-1699)
(define-constant ERR-BADGE-NOT-EARNED (err u1600))
(define-constant ERR-BADGE-ALREADY-CLAIMED (err u1601))
(define-constant ERR-INVALID-BADGE-TYPE (err u1602))
(define-constant ERR-BADGE-NOT-TRANSFERABLE (err u1603))

;; Community Errors (1700-1799)
(define-constant ERR-COMMUNITY-NOT-FOUND (err u1700))
(define-constant ERR-NOT-COMMUNITY-MEMBER (err u1701))
(define-constant ERR-INSUFFICIENT-ROLE (err u1702))
(define-constant ERR-COMMUNITY-FULL (err u1703))
(define-constant ERR-MEMBERSHIP-REQUIREMENT-NOT-MET (err u1704))

;; Governance Errors (1800-1899)
(define-constant ERR-PROPOSAL-NOT-FOUND (err u1800))
(define-constant ERR-VOTING-CLOSED (err u1801))
(define-constant ERR-ALREADY-VOTED (err u1802))
(define-constant ERR-PROPOSAL-NOT-PASSED (err u1803))
(define-constant ERR-TIMELOCK-NOT-EXPIRED (err u1804))
(define-constant ERR-INSUFFICIENT-VOTING-POWER (err u1805))
