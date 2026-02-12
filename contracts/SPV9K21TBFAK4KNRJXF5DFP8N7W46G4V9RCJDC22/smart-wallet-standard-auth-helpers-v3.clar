(define-constant SIP018_MSG_PREFIX 0x534950303138)

(define-read-only (get-domain-hash)
  (sha256 (unwrap-panic (to-consensus-buff? {
    name: "smart-wallet-standard",
    version: "1.0.0",
    chain-id: chain-id,
    wallet: contract-caller,
  })))
)

(define-read-only (build-stx-transfer-hash (details {
  auth-id: uint,
  amount: uint,
  recipient: principal,
  memo: (optional (buff 34)),
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "stx-transfer",
        auth-id: (get auth-id details),
        amount: (get amount details),
        recipient: (get recipient details),
        memo: (get memo details),
      })))
    )))
)

(define-read-only (build-extension-call-hash (details {
  auth-id: uint,
  extension: principal,
  payload: (buff 2048),
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "extension-call",
        auth-id: (get auth-id details),
        extension: (get extension details),
        payload: (get payload details),
      })))
    )))
)

(define-read-only (build-sip010-transfer-hash (details {
  auth-id: uint,
  amount: uint,
  recipient: principal,
  memo: (optional (buff 34)),
  sip010: principal,
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "sip010-transfer",
        auth-id: (get auth-id details),
        amount: (get amount details),
        recipient: (get recipient details),
        memo: (get memo details),
        sip010: (get sip010 details),
      })))
    )))
)

(define-read-only (build-sip009-transfer-hash (details {
  auth-id: uint,
  nft-id: uint,
  recipient: principal,
  sip009: principal,
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "sip009-transfer",
        auth-id: (get auth-id details),
        nft-id: (get nft-id details),
        recipient: (get recipient details),
        sip009: (get sip009 details),
      })))
    )))
)

(define-read-only (build-add-admin-hash (details {
  auth-id: uint,
  new-admin: principal,
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "add-admin",
        auth-id: (get auth-id details),
        new-admin: (get new-admin details),
      })))
    )))
)

(define-read-only (build-propose-recovery-hash (details {
  auth-id: uint,
  new-recovery: principal,
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "propose-recovery",
        auth-id: (get auth-id details),
        new-recovery: (get new-recovery details),
      })))
    )))
)

(define-read-only (build-confirm-transfer-hash (details {
  auth-id: uint,
  new-admin: principal,
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "confirm-transfer",
        auth-id: (get auth-id details),
        new-admin: (get new-admin details),
      })))
    )))
)

(define-read-only (build-whitelist-extension-hash (details {
  auth-id: uint,
  op-id: uint,
  extension: principal,
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "whitelist-extension",
        auth-id: (get auth-id details),
        op-id: (get op-id details),
        extension: (get extension details),
      })))
    )))
)

(define-read-only (build-pillar-boost-hash (details {
  auth-id: uint,
  sbtc-amount: uint,
  aeusdc-to-borrow: uint,
  min-sbtc-from-swap: uint,
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "pillar-boost",
        auth-id: (get auth-id details),
        sbtc-amount: (get sbtc-amount details),
        aeusdc-to-borrow: (get aeusdc-to-borrow details),
        min-sbtc-from-swap: (get min-sbtc-from-swap details),
      })))
    )))
)

(define-read-only (build-pillar-unwind-hash (details {
  auth-id: uint,
  sbtc-to-swap: uint,
  sbtc-to-withdraw: uint,
  min-aeusdc-from-swap: uint,
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "pillar-unwind",
        auth-id: (get auth-id details),
        sbtc-to-swap: (get sbtc-to-swap details),
        sbtc-to-withdraw: (get sbtc-to-withdraw details),
        min-aeusdc-from-swap: (get min-aeusdc-from-swap details),
      })))
    )))
)

(define-read-only (build-pillar-repay-hash (details {
  auth-id: uint,
  aeusdc-amount: uint,
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "pillar-repay",
        auth-id: (get auth-id details),
        aeusdc-amount: (get aeusdc-amount details),
      })))
    )))
)

(define-read-only (build-pillar-add-collateral-hash (details {
  auth-id: uint,
  sbtc-amount: uint,
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "pillar-add-collateral",
        auth-id: (get auth-id details),
        sbtc-amount: (get sbtc-amount details),
      })))
    )))
)

(define-read-only (build-pillar-withdraw-collateral-hash (details {
  auth-id: uint,
  sbtc-amount: uint,
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "pillar-withdraw-collateral",
        auth-id: (get auth-id details),
        sbtc-amount: (get sbtc-amount details),
      })))
    )))
)

(define-read-only (build-pillar-borrow-more-hash (details {
  auth-id: uint,
  aeusdc-amount: uint,
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "pillar-borrow-more",
        auth-id: (get auth-id details),
        aeusdc-amount: (get aeusdc-amount details),
      })))
    )))
)

(define-read-only (build-pillar-repay-withdraw-hash (details {
  auth-id: uint,
  aeusdc-to-repay: uint,
  sbtc-to-withdraw: uint,
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "pillar-repay-withdraw",
        auth-id: (get auth-id details),
        aeusdc-to-repay: (get aeusdc-to-repay details),
        sbtc-to-withdraw: (get sbtc-to-withdraw details),
      })))
    )))
)

(define-read-only (build-remove-extension-whitelist-hash (details {
  auth-id: uint,
  extension: principal,
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "remove-extension-whitelist",
        auth-id: (get auth-id details),
        extension: (get extension details),
      })))
    )))
)

(define-read-only (build-veto-operation-hash (details {
  auth-id: uint,
  op-id: uint,
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "veto-operation",
        auth-id: (get auth-id details),
        op-id: (get op-id details),
      })))
    )))
)

(define-read-only (build-propose-guardian-hash (details {
  auth-id: uint,
  new-guardian: principal,
  max-drawdown-ltv: uint,
  target-ltv: uint,
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "propose-guardian",
        auth-id: (get auth-id details),
        new-guardian: (get new-guardian details),
        max-drawdown-ltv: (get max-drawdown-ltv details),
        target-ltv: (get target-ltv details),
      })))
    )))
)

(define-read-only (build-disable-guardian-hash (details {
  auth-id: uint,
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "disable-guardian",
        auth-id: (get auth-id details),
      })))
    )))
)

(define-read-only (build-enroll-dual-stacking-hash (details {
  auth-id: uint,
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "enroll-dual-stacking",
        auth-id: (get auth-id details),
      })))
    )))
)

(define-read-only (build-stack-stx-fast-pool-hash (details {
  auth-id: uint,
  amount-ustx: uint,
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "stack-stx-fast-pool",
        auth-id: (get auth-id details),
        amount-ustx: (get amount-ustx details),
      })))
    )))
)

(define-read-only (build-revoke-fast-pool-hash (details {
  auth-id: uint,
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "revoke-fast-pool",
        auth-id: (get auth-id details),
      })))
    )))
)

(define-read-only (build-stake-stx-stacking-dao-hash (details {
  auth-id: uint,
  stx-amount: uint,
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "stake-stx-stacking-dao",
        auth-id: (get auth-id details),
        stx-amount: (get stx-amount details),
      })))
    )))
)

(define-read-only (build-set-keeper-hash (details {
  auth-id: uint,
  keeper: (optional principal),
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "set-keeper",
        auth-id: (get auth-id details),
        keeper: (get keeper details),
      })))
    )))
)

(define-read-only (build-set-keeper-dust-sweep-hash (details {
  auth-id: uint,
  enabled: bool,
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "set-keeper-dust-sweep",
        auth-id: (get auth-id details),
        enabled: (get enabled details),
      })))
    )))
)

(define-read-only (build-set-keeper-auto-compound-hash (details {
  auth-id: uint,
  enabled: bool,
  min-sbtc: uint,
  trigger: uint,
}))
  (sha256 (concat SIP018_MSG_PREFIX
    (concat (get-domain-hash)
      (sha256 (unwrap-panic (to-consensus-buff? {
        topic: "set-keeper-auto-compound",
        auth-id: (get auth-id details),
        enabled: (get enabled details),
        min-sbtc: (get min-sbtc details),
        trigger: (get trigger details),
      })))
    )))
)