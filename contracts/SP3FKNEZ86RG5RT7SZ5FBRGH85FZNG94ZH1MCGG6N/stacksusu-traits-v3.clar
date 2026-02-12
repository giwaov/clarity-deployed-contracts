;; StackSusu Traits v3
;; Simplified trait definitions for v5 contracts

;; Admin management trait
(define-trait admin-trait
  (
    (is-paused () (response bool uint))
    (get-admin-fee-bps () (response uint uint))
    (get-treasury () (response principal uint))
    (record-fee (uint) (response bool uint))
  )
)

;; Reputation trait (new in v3)
(define-trait reputation-trait
  (
    (get-member-score (principal) (response uint uint))
    (record-completion (principal uint uint bool) (response bool uint))
    (record-default (principal uint) (response bool uint))
    (meets-requirement (principal uint) (response bool uint))
    (initialize-member (principal) (response bool uint))
    (record-contribution (principal uint) (response bool uint))
  )
)

;; Referral trait (new in v3)
(define-trait referral-trait
  (
    (register-referral (principal) (response bool uint))
    (record-activity (principal uint) (response uint uint))
    (has-referrer (principal) (response bool uint))
  )
)

;; SIP-009 NFT trait
(define-trait sip009-nft-trait
  (
    (get-last-token-id () (response uint uint))
    (get-token-uri (uint) (response (optional (string-ascii 256)) uint))
    (get-owner (uint) (response (optional principal) uint))
    (transfer (uint principal principal) (response bool uint))
  )
)
