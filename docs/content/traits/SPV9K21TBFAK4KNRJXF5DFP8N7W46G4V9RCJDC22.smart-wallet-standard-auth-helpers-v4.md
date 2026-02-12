---
title: "Trait smart-wallet-standard-auth-helpers-v4"
draft: true
---
```
(define-constant SIP018_MSG_PREFIX 0x534950303138)

(define-read-only (get-domain-hash)
  (sha256 (unwrap-panic (to-consensus-buff? {
    name: "smart-wallet-standard",
    version: "1.0.0",
    chain-id: chain-id,
    wallet: contract-caller,
  })))
)

(define-read-only (build-faktory-execute-hash (details {
  auth-id: uint,
  pool: principal,
  amount: uint,
  opcode: (optional (buff 16)),
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "faktory-execute",
        auth-id: (get auth-id details),
        pool: (get pool details),
        amount: (get amount details),
        opcode: (get opcode details),
      })))
    )))
)

(define-read-only (build-faktory-place-order-hash (details {
  auth-id: uint,
  dex: principal,
  amount: uint,
  opcode: (optional (buff 16)),
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "faktory-place-order",
        auth-id: (get auth-id details),
        dex: (get dex details),
        amount: (get amount details),
        opcode: (get opcode details),
      })))
    )))
)

(define-read-only (build-faktory-process-hash (details {
  auth-id: uint,
  pre: principal,
  seat-count: uint,
  opcode: (optional (buff 16)),
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "faktory-process",
        auth-id: (get auth-id details),
        pre: (get pre details),
        seat-count: (get seat-count details),
        opcode: (get opcode details),
      })))
    )))
)

(define-read-only (build-faktory-process-claim-hash (details {
  auth-id: uint,
  pre: principal,
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "faktory-process-claim",
        auth-id: (get auth-id details),
        pre: (get pre details),
      })))
    )))
)

(define-read-only (build-faktory-fee-airdrop-hash (details {
  auth-id: uint,
  pre: principal,
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "faktory-fee-airdrop",
        auth-id: (get auth-id details),
        pre: (get pre details),
      })))
    )))
)

```
