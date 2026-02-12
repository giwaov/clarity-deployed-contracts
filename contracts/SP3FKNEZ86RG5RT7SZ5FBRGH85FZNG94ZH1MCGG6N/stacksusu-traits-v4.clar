;; StackSusu Traits v4
;; Enhanced trait definitions for v6 contracts

;; Admin management trait
(define-trait admin-trait
  (
    (is-paused () (response bool uint))
    (get-admin-fee-bps () (response uint uint))
    (get-treasury () (response principal uint))
    (record-fee (uint) (response bool uint))
    (get-multi-sig-threshold () (response uint uint))
  )
)

;; Core circle trait
(define-trait core-trait
  (
    (get-circle-info (uint) (response (optional {
      creator: principal,
      name: (string-ascii 50),
      contribution: uint,
      max-members: uint,
      payout-interval: uint,
      status: uint,
      current-round: uint,
      member-count: uint
    }) uint))
    (is-member (uint principal) (response bool uint))
    (get-member-slot (uint principal) (response uint uint))
  )
)

;; Reputation trait (enhanced in v4)
(define-trait reputation-trait
  (
    (get-member-score (principal) (response uint uint))
    (record-completion (principal uint uint bool) (response bool uint))
    (record-default (principal uint) (response bool uint))
    (meets-requirement (principal uint) (response bool uint))
    (initialize-member (principal) (response bool uint))
    (record-contribution (principal uint) (response bool uint))
    (get-badge-count (principal) (response uint uint))
    (apply-decay (principal) (response uint uint))
  )
)

;; Referral trait (enhanced in v4)
(define-trait referral-trait
  (
    (register-referral (principal) (response bool uint))
    (record-activity (principal uint) (response uint uint))
    (has-referrer (principal) (response bool uint))
    (get-referral-chain (principal) (response (list 3 principal) uint))
  )
)

;; Escrow trait (new in v4)
(define-trait escrow-trait
  (
    (get-balance (uint principal) (response uint uint))
    (lock-funds (uint principal uint) (response bool uint))
    (release-funds (uint principal uint) (response bool uint))
    (get-dispute-status (uint) (response uint uint))
  )
)

;; Governance trait (new in v4)
(define-trait governance-trait
  (
    (get-proposal (uint) (response (optional {
      circle-id: uint,
      proposer: principal,
      status: uint,
      votes-for: uint,
      votes-against: uint
    }) uint))
    (get-voting-power (uint principal) (response uint uint))
    (has-voted (uint principal) (response bool uint))
  )
)

;; Emergency trait (new in v4)
(define-trait emergency-trait
  (
    (can-request-emergency (uint principal) (response bool uint))
    (get-insurance-pool-balance () (response uint uint))
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

;; SIP-010 Fungible Token trait (for future token integration)
(define-trait sip010-ft-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
  )
)
