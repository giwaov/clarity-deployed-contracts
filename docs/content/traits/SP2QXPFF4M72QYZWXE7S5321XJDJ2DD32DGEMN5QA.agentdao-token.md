---
title: "Trait agentdao-token"
draft: true
---
```
;; SP2QXPFF4M72QYZWXE7S5321XJDJ2DD32DGEMN5QA.agentdao-token
;; AgentDAO - Faktory-compatible governance token

(impl-trait 'SP3XXMS38VTAWTVPE5682XSBFXPTH7XCPEBTX8AN2.faktory-trait-v1.sip-010-trait)

(define-constant ERR-NOT-AUTHORIZED (err u401))

(define-fungible-token agentdao u100000000000000000)

(define-data-var contract-owner principal tx-sender)
(define-data-var token-uri (optional (string-utf8 256)) (some u"https://aibtc.dev/tokens/agentdao.json"))

;; SIP-010 Implementation
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
    (try! (ft-transfer? agentdao amount sender recipient))
    (match memo m (print m) 0x)
    (ok true)
  )
)

(define-read-only (get-name) (ok "AgentDAO"))
(define-read-only (get-symbol) (ok "AGNT"))
(define-read-only (get-decimals) (ok u8))
(define-read-only (get-balance (who principal)) (ok (ft-get-balance agentdao who)))
(define-read-only (get-total-supply) (ok (ft-get-supply agentdao)))
(define-read-only (get-token-uri) (ok (var-get token-uri)))

(define-public (set-token-uri (value (string-utf8 256)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set token-uri (some value))
    (ok (print {notification: "token-metadata-update", payload: {contract-id: (as-contract tx-sender), token-class: "ft"}}))
  )
)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (ok (var-set contract-owner new-owner))
  )
)

;; Batch transfer
(define-public (send-many (recipients (list 200 {to: principal, amount: uint, memo: (optional (buff 34))})))
  (fold check-err (map send-token recipients) (ok true))
)

(define-private (check-err (result (response bool uint)) (prior (response bool uint)))
  (match prior ok-value result err-value (err err-value))
)

(define-private (send-token (recipient {to: principal, amount: uint, memo: (optional (buff 34))}))
  (transfer (get amount recipient) tx-sender (get to recipient) (get memo recipient))
)

;; Mint full supply to deployer
(begin
  (try! (ft-mint? agentdao u100000000000000000 tx-sender))
  (print {
    type: "faktory-trait-v1",
    name: "agentdao",
    symbol: "AGNT",
    tokenContract: (as-contract tx-sender),
    supply: u100000000000000000,
    decimals: u8
  })
)
```
