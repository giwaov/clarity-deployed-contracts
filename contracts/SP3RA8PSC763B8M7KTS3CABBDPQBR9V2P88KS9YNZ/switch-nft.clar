;; ============================================
;; SWITCH NFT - Proof of Configuration
;; SIP-009 Compliant
;; Clarity 4 Smart Contract
;; ============================================

(impl-trait .nft-trait.nft-trait)

(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_NO_SWITCH (err u404))

(define-non-fungible-token switch-nft uint)
(define-data-var last-token-id uint u0)

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
  (begin
    token-id ;; silence unused warning
    (ok none)
  )
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? switch-nft token-id))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_NOT_AUTHORIZED)
    (asserts! (not (is-eq sender recipient)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (some sender) (nft-get-owner? switch-nft token-id)) ERR_NOT_AUTHORIZED)
    (nft-transfer? switch-nft token-id sender recipient)
  )
)

(define-public (mint)
  (let
    (
      (user tx-sender)
      (status (contract-call? .heartbeat-core get-status user))
      (new-id (+ (var-get last-token-id) u1))
    )
    (asserts! (is-some status) ERR_NO_SWITCH)
    (try! (nft-mint? switch-nft new-id user))
    (var-set last-token-id new-id)
    (ok new-id)
  )
)
