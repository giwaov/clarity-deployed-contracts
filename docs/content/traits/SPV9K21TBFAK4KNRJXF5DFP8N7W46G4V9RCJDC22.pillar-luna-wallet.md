---
title: "Trait pillar-luna-wallet"
draft: true
---
```

(use-trait extension-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.extension-trait.extension-trait)

(use-trait sip-010-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)
(use-trait sip-009-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

(define-constant err-unauthorised (err u4001))
(define-constant err-invalid-signature (err u4002))
(define-constant err-forbidden (err u4003))
(define-constant err-unregistered-pubkey (err u4004))
(define-constant err-not-admin-pubkey (err u4005))
(define-constant err-signature-replay (err u4006))
(define-constant err-no-auth-id (err u4007))
(define-constant err-no-message-hash (err u4008))
(define-constant err-inactive-required (err u4009))
(define-constant err-no-pending-recovery (err u4010))
(define-constant err-not-whitelisted (err u4011))
(define-constant err-in-cooldown (err u4012))
(define-constant err-invalid-operation (err u4013))
(define-constant err-already-executed (err u4014))
(define-constant err-vetoed (err u4015))
(define-constant err-not-signaled (err u4016))
(define-constant err-cooldown-not-passed (err u4017))
(define-constant err-threshold-exceeded (err u4018))
(define-constant err-cooldown-too-long (err u4019))
(define-constant err-no-pending-transfer (err u4020))
(define-constant err-no-pending-pubkey (err u4021))
(define-constant err-already-initialized (err u4022))
(define-constant err-guardian-not-allowed (err u4023))
(define-constant err-permission-expired (err u4024))
(define-constant err-permission-mismatch (err u4025))
(define-constant err-fatal-owner-not-admin (err u9999))

(define-constant INACTIVITY-PERIOD u52560) 
(define-constant MAX-CONFIG-COOLDOWN u4032) ;; ~28 days max for config changes
(define-constant DEPLOYED-BURNT-BLOCK burn-block-height)
(define-constant SBTC-CONTRACT 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token)
(define-constant PILLAR-DEPLOYER 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22)
(define-constant PUBK 0x000000000000000000000000000000000000000000000000000000000000000000)

(define-data-var last-activity-block uint burn-block-height)
(define-data-var recovery-address principal 'SP000000000000000000002Q6VF78)
(define-data-var initial-pubkey (buff 33) PUBK)
(define-data-var is-initialized bool false)
(define-data-var pubkey-initialized bool false)

(define-data-var guardian-principal (optional principal) none)
(define-data-var guardian-enabled bool false)
(define-data-var guardian-max-drawdown-ltv uint u65000000)
(define-data-var guardian-target-ltv uint u50000000)
(define-data-var pending-guardian {
  guardian: (optional principal),
  max-drawdown-ltv: uint,
  target-ltv: uint,
  proposed-at: uint,
} {
  guardian: none,
  max-drawdown-ltv: u0,
  target-ltv: u0,
  proposed-at: u0,
})

(define-data-var guardian-unwind-permission {
  sbtc-to-swap: uint,
  sbtc-to-withdraw: uint,
  granted-at: uint,
} {
  sbtc-to-swap: u0,
  sbtc-to-withdraw: u0,
  granted-at: u0,
})

(define-data-var guardian-repay-permission {
  aeusdc-amount: uint,
  granted-at: uint,
} {
  aeusdc-amount: u0,
  granted-at: u0,
})

(define-data-var pending-pubkey {
  pubkey: (buff 33),
  proposed-at: uint,
} {
  pubkey: (var-get initial-pubkey),
  proposed-at: u0,
})

(define-data-var owner principal 'SP000000000000000000002Q6VF78)
(define-data-var pending-recovery principal 'SP000000000000000000002Q6VF78)
(define-data-var pending-transfer principal 'SP000000000000000000002Q6VF78)

(define-fungible-token ect)

(define-map used-pubkey-authorizations
  (buff 32) 
  (buff 33)
)


(define-data-var wallet-config {
  stx-threshold: uint,            
  sbtc-threshold: uint,          
  cooldown-period: uint,         
  config-signaled-at: (optional uint),
} {
  stx-threshold: u100000000,
  sbtc-threshold: u100000,
  cooldown-period: u144,
  config-signaled-at: none,
})

(define-data-var spent-this-period {
  stx: uint,
  sbtc: uint,
  period-start: uint,
} {
  stx: u0,
  sbtc: u0,
  period-start: DEPLOYED-BURNT-BLOCK,
})

(define-private (get-current-spent)
  (let (
      (spent (var-get spent-this-period))
      (config (var-get wallet-config))
      (period-expired (> burn-block-height (+ (get period-start spent) (get cooldown-period config))))
    )
    (if period-expired
      { stx: u0, sbtc: u0, period-start: burn-block-height }
      spent
    )
  )
)

(define-private (add-spent-stx (amount uint))
  (let ((current (get-current-spent)))
    (var-set spent-this-period (merge current { stx: (+ (get stx current) amount) }))
  )
)

(define-private (add-spent-sbtc (amount uint))
  (let ((current (get-current-spent)))
    (var-set spent-this-period (merge current { sbtc: (+ (get sbtc current) amount) }))
  )
)

(define-map whitelisted-extensions principal bool)

(define-map pending-operations
  uint 
  {
    op-type: (string-ascii 20),
    amount: uint,
    recipient: principal,
    token: (optional principal),  
    extension: (optional principal),
    payload: (optional (buff 2048)),
    execute-after: uint,
    executed: bool,
    vetoed: bool,
  }
)

(define-data-var operation-nonce uint u0)

(define-public (signal-config-change)
  (let ((config (var-get wallet-config)))
    (try! (is-authorized none))
    (var-set wallet-config (merge config { config-signaled-at: (some burn-block-height) }))
    (print { a: "signal-config-change", signaled-at: burn-block-height })
    (ok true)
  )
)

(define-public (set-wallet-config
    (new-stx-threshold uint)
    (new-sbtc-threshold uint)
    (new-cooldown-period uint)
  )
  (let (
      (config (var-get wallet-config))
      (signaled-at (default-to u0 (get config-signaled-at config)))
      (wallet-cooldown (get cooldown-period config))
      (effective-config-cooldown (if (> wallet-cooldown MAX-CONFIG-COOLDOWN)
        MAX-CONFIG-COOLDOWN
        wallet-cooldown
      ))
    )
    (try! (is-authorized none))
    (asserts! (not (is-eq signaled-at u0)) err-not-signaled)
    (asserts! (>= burn-block-height (+ signaled-at effective-config-cooldown)) err-in-cooldown)
    (var-set wallet-config {
      stx-threshold: new-stx-threshold,
      sbtc-threshold: new-sbtc-threshold,
      cooldown-period: new-cooldown-period,
      config-signaled-at: none,
    })
    (print { 
      a: "set-wallet-config", 
      stx-threshold: new-stx-threshold,
      sbtc-threshold: new-sbtc-threshold,
      cooldown-period: new-cooldown-period,
    })
    (ok true)
  )
)

(define-private (create-pending-operation
    (op-type (string-ascii 20))
    (amount uint)
    (recipient principal)
    (token (optional principal))
    (extension (optional principal))
    (payload (optional (buff 2048)))
  )
  (let (
      (config (var-get wallet-config))
      (op-id (var-get operation-nonce))
    )
    (map-set pending-operations op-id {
      op-type: op-type,
      amount: amount,
      recipient: recipient,
      token: token,
      extension: extension,
      payload: payload,
      execute-after: (+ burn-block-height (get cooldown-period config)),
      executed: false,
      vetoed: false,
    })
    (var-set operation-nonce (+ op-id u1))
    (print { 
      a: "pending-operation-created",
      op-id: op-id,
      op-type: op-type,
      amount: amount,
      execute-after: (+ burn-block-height (get cooldown-period config)),
    })
    (ok op-id)
  )
)

(define-public (veto-operation 
    (op-id uint)
    (sig-auth (optional {
      auth-id: uint,
      signature: (buff 65),
      pubkey: (buff 33),
    }))
  )
  (let ((op (unwrap! (map-get? pending-operations op-id) err-invalid-operation)))
    (match sig-auth
      sig-auth-details (try! (is-authorized (some {
        message-hash: (contract-call?
          'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.smart-wallet-standard-auth-helpers-v2
          build-veto-operation-hash {
          auth-id: (get auth-id sig-auth-details),
          op-id: op-id,
        }),
        signature: (get signature sig-auth-details),
        pubkey: (get pubkey sig-auth-details),
      })))
      (try! (is-authorized none))
    )
    (asserts! (not (get executed op)) err-already-executed)
    (map-set pending-operations op-id (merge op { vetoed: true }))
    (print { a: "operation-vetoed", op-id: op-id })
    (ok true)
  )
)

(define-read-only (get-pending-operation (op-id uint))
  (map-get? pending-operations op-id)
)

(define-private (would-exceed-stx-threshold (amount uint))
  (let (
      (config (var-get wallet-config))
      (spent (get-current-spent))
    )
    (> (+ (get stx spent) amount) (get stx-threshold config))
  )
)

(define-private (would-exceed-sbtc-threshold (amount uint))
  (let (
      (config (var-get wallet-config))
      (spent (get-current-spent))
    )
    (> (+ (get sbtc spent) amount) (get sbtc-threshold config))
  )
)

(define-private (is-authorized (sig-message-auth (optional {
  message-hash: (buff 32),
  signature: (buff 65),
  pubkey: (buff 33),
})))
  (match sig-message-auth
    sig-message-details (consume-signature (get message-hash sig-message-details)
      (get signature sig-message-details) (get pubkey sig-message-details)
    )
    (is-admin-calling tx-sender)
  )
)

(define-read-only (is-admin-calling (caller principal))
  (ok (asserts! (is-some (map-get? admins caller)) err-unauthorised))
)

(define-public (whitelist-extension (extension principal))
  (begin
    (try! (is-admin-calling tx-sender))
    (create-pending-operation "whitelist-ext" u0 extension none (some extension) none)
  )
)

(define-public (execute-pending-whitelist 
    (op-id uint)
    (sig-auth {
      auth-id: uint,
      signature: (buff 65),
      pubkey: (buff 33),
    })
  )
  (let ((op (unwrap! (map-get? pending-operations op-id) err-invalid-operation)))
    (asserts! (is-eq (get op-type op) "whitelist-ext") err-invalid-operation)
    (asserts! (not (get executed op)) err-already-executed)
    (asserts! (not (get vetoed op)) err-vetoed)
    (asserts! (>= burn-block-height (get execute-after op)) err-cooldown-not-passed)
    (try! (is-authorized (some {
      message-hash: (contract-call? 
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.smart-wallet-standard-auth-helpers-v2
        build-whitelist-extension-hash {
        auth-id: (get auth-id sig-auth),
        op-id: op-id,
        extension: (unwrap! (get extension op) err-invalid-operation),
      }),
      signature: (get signature sig-auth),
      pubkey: (get pubkey sig-auth),
    })))
    (map-set pending-operations op-id (merge op { executed: true }))
    (map-set whitelisted-extensions (unwrap! (get extension op) err-invalid-operation) true)
    (print { a: "extension-whitelisted", extension: (get extension op) })
    (ok true)
  )
)

(define-public (remove-extension-whitelist 
    (extension principal)
    (sig-auth (optional {
      auth-id: uint,
      signature: (buff 65),
      pubkey: (buff 33),
    }))
  )
  (begin
    (match sig-auth
      sig-auth-details (try! (is-authorized (some {
        message-hash: (contract-call?
          'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.smart-wallet-standard-auth-helpers-v2
          build-remove-extension-whitelist-hash {
          auth-id: (get auth-id sig-auth-details),
          extension: extension,
        }),
        signature: (get signature sig-auth-details),
        pubkey: (get pubkey sig-auth-details),
      })))
      (try! (is-authorized none))
    )
    (ok (map-delete whitelisted-extensions extension))
  )
)

(define-read-only (is-extension-whitelisted (extension principal))
  (default-to false (map-get? whitelisted-extensions extension))
)

(define-public (stx-transfer
    (amount uint)
    (recipient principal)
    (memo (optional (buff 34)))
    (sig-auth (optional {
      auth-id: uint,
      signature: (buff 65),
      pubkey: (buff 33),
    }))
  )
  (begin
    (update-activity)
    (match sig-auth
      sig-auth-details (try! (is-authorized (some {
        message-hash: (contract-call?
          'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.smart-wallet-standard-auth-helpers-v2
          build-stx-transfer-hash {
          auth-id: (get auth-id sig-auth-details),
          amount: amount,
          recipient: recipient,
          memo: memo,
        }),
        signature: (get signature sig-auth-details),
        pubkey: (get pubkey sig-auth-details),
      })))
      (try! (is-authorized none))
    )
    (if (would-exceed-stx-threshold amount)
      (begin
        (unwrap-panic (create-pending-operation "stx-transfer" amount recipient none none none))
        (ok true)
      )
      (begin
        (add-spent-stx amount)
        (print {
          a: "stx-transfer",
          payload: { amount: amount, recipient: recipient, memo: memo },
        })
        (as-contract? ((with-stx amount))
          (match memo
            to-print (try! (stx-transfer-memo? amount tx-sender recipient to-print))
            (try! (stx-transfer? amount tx-sender recipient))
          ))
      )
    )
  )
)

(define-public (execute-pending-stx-transfer 
    (op-id uint)
    (memo (optional (buff 34)))
  )
  (let ((op (unwrap! (map-get? pending-operations op-id) err-invalid-operation)))
    (asserts! (is-eq (get op-type op) "stx-transfer") err-invalid-operation)
    (asserts! (not (get executed op)) err-already-executed)
    (asserts! (not (get vetoed op)) err-vetoed)
    (asserts! (>= burn-block-height (get execute-after op)) err-cooldown-not-passed)
    (try! (is-authorized none))
    (map-set pending-operations op-id (merge op { executed: true }))
    (print {
      a: "stx-transfer",
      payload: { amount: (get amount op), recipient: (get recipient op), memo: memo },
    })
    (as-contract? ((with-stx (get amount op)))
      (match memo
        to-print (try! (stx-transfer-memo? (get amount op) tx-sender (get recipient op) to-print))
        (try! (stx-transfer? (get amount op) tx-sender (get recipient op)))
      ))
  )
)

(define-public (extension-call
    (extension <extension-trait>)
    (payload (buff 2048))
    (sig-auth (optional {
      auth-id: uint,
      signature: (buff 65),
      pubkey: (buff 33),
    }))
  )
  (begin
    (update-activity)
    (asserts! (is-extension-whitelisted (contract-of extension)) err-not-whitelisted)
    (match sig-auth
      sig-auth-details (try! (is-authorized (some {
        message-hash: (contract-call?
          'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.smart-wallet-standard-auth-helpers-v2
          build-extension-call-hash {
          auth-id: (get auth-id sig-auth-details),
          extension: (contract-of extension),
          payload: payload,
        }),
        signature: (get signature sig-auth-details),
        pubkey: (get pubkey sig-auth-details),
      })))
      (try! (is-authorized none))
    )
    (try! (ft-mint? ect u1 current-contract))
    (try! (ft-burn? ect u1 current-contract))
    (print {
      a: "extension-call",
      payload: { extension: extension, payload: payload },
    })
    (as-contract? ((with-all-assets-unsafe))
      (try! (contract-call? extension call payload))
    )
  )
)

(define-public (sip010-transfer
    (amount uint)
    (recipient principal)
    (memo (optional (buff 34)))
    (sip010 <sip-010-trait>)
    (token-name (string-ascii 128))
    (sig-auth (optional {
      auth-id: uint,
      signature: (buff 65),
      pubkey: (buff 33),
    }))
  )
  (begin
    (update-activity)
    (match sig-auth
      sig-auth-details (try! (is-authorized (some {
        message-hash: (contract-call?
          'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.smart-wallet-standard-auth-helpers-v2
          build-sip010-transfer-hash {
          auth-id: (get auth-id sig-auth-details),
          amount: amount,
          recipient: recipient,
          memo: memo,
          sip010: (contract-of sip010),
        }),
        signature: (get signature sig-auth-details),
        pubkey: (get pubkey sig-auth-details),
      })))
      (try! (is-authorized none))
    )
    (if (and (is-eq (contract-of sip010) SBTC-CONTRACT) (would-exceed-sbtc-threshold amount))
      (begin
        (unwrap-panic (create-pending-operation "sbtc-transfer" amount recipient (some SBTC-CONTRACT) none none))
        (ok true)
      )
      (begin
        (if (is-eq (contract-of sip010) SBTC-CONTRACT)
          (add-spent-sbtc amount)
          true
        )
        (print {
          a: "sip010-transfer",
          payload: { amount: amount, recipient: recipient, memo: memo, sip010: sip010 },
        })
        (as-contract? ((with-ft (contract-of sip010) token-name amount))
          (try! (contract-call? sip010 transfer amount current-contract recipient memo))
        )
      )
    )
  )
)

(define-public (execute-pending-sbtc-transfer
    (op-id uint)
    (memo (optional (buff 34)))
  )
  (let ((op (unwrap! (map-get? pending-operations op-id) err-invalid-operation)))
    (asserts! (is-eq (get op-type op) "sbtc-transfer") err-invalid-operation)
    (asserts! (not (get executed op)) err-already-executed)
    (asserts! (not (get vetoed op)) err-vetoed)
    (asserts! (>= burn-block-height (get execute-after op)) err-cooldown-not-passed)
    (try! (is-authorized none))
    (map-set pending-operations op-id (merge op { executed: true }))
    (print {
      a: "sip010-transfer",
      payload: { amount: (get amount op), recipient: (get recipient op), memo: memo, sip010: SBTC-CONTRACT },
    })
    (as-contract? ((with-ft SBTC-CONTRACT "sBTC" (get amount op)))
      (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token transfer 
        (get amount op) current-contract (get recipient op) memo))
    )
  )
)

(define-public (sip009-transfer
    (nft-id uint)
    (recipient principal)
    (sip009 <sip-009-trait>)
    (token-name (string-ascii 128))
    (sig-auth (optional {
      auth-id: uint,
      signature: (buff 65),
      pubkey: (buff 33),
    }))
  )
  (begin
    (update-activity)
    (match sig-auth
      sig-auth-details (try! (is-authorized (some {
        message-hash: (contract-call?
          'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.smart-wallet-standard-auth-helpers-v2
          build-sip009-transfer-hash {
          auth-id: (get auth-id sig-auth-details),
          nft-id: nft-id,
          recipient: recipient,
          sip009: (contract-of sip009),
        }),
        signature: (get signature sig-auth-details),
        pubkey: (get pubkey sig-auth-details),
      })))
      (try! (is-authorized none))
    )
    (print {
      a: "sip009-transfer",
      payload: {
        nft-id: nft-id,
        recipient: recipient,
        sip009: sip009,
      },
    })
    (as-contract? ((with-nft (contract-of sip009) token-name (list nft-id)))
      (try! (contract-call? sip009 transfer nft-id current-contract recipient))
    )
  )
)

(define-public (pillar-boost
    (sbtc-amount uint)
    (aeusdc-to-borrow uint)
    (min-sbtc-from-swap uint)
    (price-feed-bytes (optional (buff 8192)))  
    (sig-auth (optional { auth-id: uint, signature: (buff 65), pubkey: (buff 33) }))
  )
  (begin
    (update-activity)
    (match sig-auth
      sig-auth-details (try! (is-authorized (some {
        message-hash: (contract-call?
          'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.smart-wallet-standard-auth-helpers-v2
          build-pillar-boost-hash {
          auth-id: (get auth-id sig-auth-details),
          sbtc-amount: sbtc-amount,
          aeusdc-to-borrow: aeusdc-to-borrow,
          min-sbtc-from-swap: min-sbtc-from-swap,
        }),
        signature: (get signature sig-auth-details),
        pubkey: (get pubkey sig-auth-details),
      })))
      (try! (is-authorized none))
    )
    
    (try! (as-contract? ((with-all-assets-unsafe)) (try! (contract-call? 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v2-1-7 supply
      'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zsbtc-v2-0
      'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-0-reserve-v2-0
      'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
      sbtc-amount
      current-contract
      none
      'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.incentives-v2-2
    ))))
    
    (try! (as-contract? ((with-all-assets-unsafe)) (try! (contract-call? 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v2-1-7 borrow
      'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-0-reserve-v2-0
      'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.aeusdc-oracle-v1-0
      'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc
      'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zaeusdc-v2-0
      (list
        { asset: 'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststx-token, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zststx-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 }
        { asset: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zaeusdc-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.aeusdc-oracle-v1-0 }
        { asset: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.wstx, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zwstx-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 }
        { asset: 'SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.arkadiko-token, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zdiko-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.diko-oracle-v1-1 }
        { asset: 'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.usdh-token-v1, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zusdh-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.usdh-oracle-v1-0 }
        { asset: 'SP2XD7417HGPRTREMKF748VNEQPDRR0RMANB7X1NK.token-susdt, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zsusdt-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.susdt-oracle-v1-0 }
        { asset: 'SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.usda-token, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zusda-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.usda-oracle-v1-1 }
        { asset: 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zsbtc-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 }
        { asset: 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zalex-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.alex-oracle-v1-1 }
        { asset: 'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststxbtc-token-v2, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zststxbtc-v2_v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 }
      )
      aeusdc-to-borrow
      'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.fees-calculator
      u0
      current-contract
      price-feed-bytes
    ))))
    
    (let ((sbtc-received (try! (as-contract? ((with-all-assets-unsafe)) (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-swap-helper-v-1-3 swap-helper-b
        aeusdc-to-borrow
        min-sbtc-from-swap
        none
        {
          a: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc,
          b: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2,
          c: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2,
          d: 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
        }
        {
          a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-aeusdc-v-1-2,
          b: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-stx-v-1-1
        }
      ))))))
      
      (try! (as-contract? ((with-all-assets-unsafe)) (try! (contract-call? 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v2-1-7 supply
        'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zsbtc-v2-0
        'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-0-reserve-v2-0
        'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
        sbtc-received
        current-contract
        none
        'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.incentives-v2-2
      ))))
      
      (print {
        action: "pillar-boost",
        sbtc-deposited: sbtc-amount,
        aeusdc-borrowed: aeusdc-to-borrow,
        sbtc-from-swap: sbtc-received,
        total-collateral: (+ sbtc-amount sbtc-received),
      })
      
      (ok { sbtc-deposited: sbtc-amount, aeusdc-borrowed: aeusdc-to-borrow, sbtc-from-swap: sbtc-received })
    )
  )
)

(define-public (pillar-unwind
    (sbtc-to-swap uint)
    (sbtc-to-withdraw uint)
    (min-aeusdc-from-swap uint)
    (price-feed-bytes (optional (buff 8192)))  
    (sig-auth (optional { auth-id: uint, signature: (buff 65), pubkey: (buff 33) }))
  )
  (begin
    (update-activity)
    (match sig-auth
      sig-auth-details (try! (is-authorized (some {
        message-hash: (contract-call?
          'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.smart-wallet-standard-auth-helpers-v2
          build-pillar-unwind-hash {
          auth-id: (get auth-id sig-auth-details),
          sbtc-to-swap: sbtc-to-swap,
          sbtc-to-withdraw: sbtc-to-withdraw,
          min-aeusdc-from-swap: min-aeusdc-from-swap,
        }),
        signature: (get signature sig-auth-details),
        pubkey: (get pubkey sig-auth-details),
      })))
      (if (is-guardian-calling)
        (let ((perm (var-get guardian-unwind-permission)))
          (asserts! (<= burn-block-height (+ (get granted-at perm) u2)) err-permission-expired)
          (asserts! (is-eq (get sbtc-to-swap perm) sbtc-to-swap) err-permission-mismatch)
          (asserts! (is-eq (get sbtc-to-withdraw perm) sbtc-to-withdraw) err-permission-mismatch)
          (var-set guardian-unwind-permission { sbtc-to-swap: u0, sbtc-to-withdraw: u0, granted-at: u0 })
        )
        (try! (is-authorized none))
      )
    )
    
    (try! (as-contract? ((with-all-assets-unsafe)) (try! (contract-call? 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v2-1-7 withdraw
      'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zsbtc-v2-0
      'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-0-reserve-v2-0
      'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
      'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4
      sbtc-to-swap
      current-contract
      (list
        { asset: 'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststx-token, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zststx-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 }
        { asset: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zaeusdc-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.aeusdc-oracle-v1-0 }
        { asset: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.wstx, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zwstx-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 }
        { asset: 'SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.arkadiko-token, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zdiko-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.diko-oracle-v1-1 }
        { asset: 'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.usdh-token-v1, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zusdh-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.usdh-oracle-v1-0 }
        { asset: 'SP2XD7417HGPRTREMKF748VNEQPDRR0RMANB7X1NK.token-susdt, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zsusdt-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.susdt-oracle-v1-0 }
        { asset: 'SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.usda-token, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zusda-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.usda-oracle-v1-1 }
        { asset: 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zsbtc-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 }
        { asset: 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zalex-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.alex-oracle-v1-1 }
        { asset: 'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststxbtc-token-v2, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zststxbtc-v2_v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 }
      )
      'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.incentives-v2-2
      price-feed-bytes
    ))))
    
    (let ((aeusdc-received (try! (as-contract? ((with-all-assets-unsafe)) (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-swap-helper-v-1-3 swap-helper-b
        sbtc-to-swap
        min-aeusdc-from-swap
        none
        {
          a: 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token,
          b: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2,
          c: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2,
          d: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc
        }
        {
          a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-stx-v-1-1,
          b: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-aeusdc-v-1-2
        }
      ))))))
      
      (try! (as-contract? ((with-all-assets-unsafe)) (try! (contract-call? 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v2-1-7 repay
        'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc
        aeusdc-received
        current-contract
        current-contract
      ))))
      
      (if (> sbtc-to-withdraw u0)
      (try! (as-contract? ((with-all-assets-unsafe)) (try! (contract-call? 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v2-1-7 withdraw
        'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zsbtc-v2-0
        'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-0-reserve-v2-0
        'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
        'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4
        sbtc-to-withdraw
        current-contract
        (list
          { asset: 'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststx-token, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zststx-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 }
          { asset: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zaeusdc-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.aeusdc-oracle-v1-0 }
          { asset: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.wstx, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zwstx-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 }
          { asset: 'SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.arkadiko-token, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zdiko-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.diko-oracle-v1-1 }
          { asset: 'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.usdh-token-v1, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zusdh-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.usdh-oracle-v1-0 }
          { asset: 'SP2XD7417HGPRTREMKF748VNEQPDRR0RMANB7X1NK.token-susdt, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zsusdt-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.susdt-oracle-v1-0 }
          { asset: 'SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.usda-token, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zusda-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.usda-oracle-v1-1 }
          { asset: 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zsbtc-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 }
          { asset: 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zalex-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.alex-oracle-v1-1 }
          { asset: 'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststxbtc-token-v2, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zststxbtc-v2_v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 }
        )
        'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.incentives-v2-2
        price-feed-bytes
      ))))
      true)
      
      (print {
        action: "pillar-unwind",
        sbtc-swapped: sbtc-to-swap,
        aeusdc-received: aeusdc-received,
        sbtc-withdrawn: sbtc-to-withdraw,
      })
      
      (ok { sbtc-swapped: sbtc-to-swap, aeusdc-received: aeusdc-received, sbtc-withdrawn: sbtc-to-withdraw })
    )
  )
)

(define-public (pillar-repay
    (aeusdc-amount uint)
    (sig-auth (optional { auth-id: uint, signature: (buff 65), pubkey: (buff 33) }))
  )
  (begin
    (update-activity)
    (match sig-auth
      sig-auth-details (try! (is-authorized (some {
        message-hash: (contract-call?
          'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.smart-wallet-standard-auth-helpers-v2
          build-pillar-repay-hash {
          auth-id: (get auth-id sig-auth-details),
          aeusdc-amount: aeusdc-amount,
        }),
        signature: (get signature sig-auth-details),
        pubkey: (get pubkey sig-auth-details),
      })))
      (if (is-guardian-calling)
        (let ((perm (var-get guardian-repay-permission)))
          (asserts! (<= burn-block-height (+ (get granted-at perm) u2)) err-permission-expired)
          (asserts! (is-eq (get aeusdc-amount perm) aeusdc-amount) err-permission-mismatch)
          (var-set guardian-repay-permission { aeusdc-amount: u0, granted-at: u0 })
        )
        (try! (is-authorized none))
      )
    )
    
    (try! (as-contract? ((with-all-assets-unsafe)) 
      (try! (contract-call? 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v2-1-7 repay
        'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc
        aeusdc-amount
        current-contract
        current-contract
      ))
    ))
    
    (print { action: "pillar-repay", aeusdc-repaid: aeusdc-amount })
    (ok { aeusdc-repaid: aeusdc-amount })
  )
)

(define-public (pillar-add-collateral
    (sbtc-amount uint)
    (sig-auth (optional { auth-id: uint, signature: (buff 65), pubkey: (buff 33) }))
  )
  (begin
    (update-activity)
    (match sig-auth
      sig-auth-details (try! (is-authorized (some {
        message-hash: (contract-call?
          'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.smart-wallet-standard-auth-helpers-v2
          build-pillar-add-collateral-hash {
          auth-id: (get auth-id sig-auth-details),
          sbtc-amount: sbtc-amount,
        }),
        signature: (get signature sig-auth-details),
        pubkey: (get pubkey sig-auth-details),
      })))
      (try! (is-authorized none))
    )
    
    (try! (as-contract? ((with-all-assets-unsafe)) 
      (try! (contract-call? 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v2-1-7 supply
        'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zsbtc-v2-0
        'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-0-reserve-v2-0
        'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
        sbtc-amount
        current-contract
        none
        'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.incentives-v2-2
      ))
    ))
    
    (print { action: "pillar-add-collateral", sbtc-added: sbtc-amount })
    (ok { sbtc-added: sbtc-amount })
  )
)

(define-public (pillar-withdraw-collateral
    (sbtc-amount uint)
    (price-feed-bytes (optional (buff 8192)))
    (sig-auth (optional { auth-id: uint, signature: (buff 65), pubkey: (buff 33) }))
  )
  (begin
    (update-activity)
    (match sig-auth
      sig-auth-details (try! (is-authorized (some {
        message-hash: (contract-call?
          'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.smart-wallet-standard-auth-helpers-v2
          build-pillar-withdraw-collateral-hash {
          auth-id: (get auth-id sig-auth-details),
          sbtc-amount: sbtc-amount,
        }),
        signature: (get signature sig-auth-details),
        pubkey: (get pubkey sig-auth-details),
      })))
      (try! (is-authorized none))
    )
    
    (try! (as-contract? ((with-all-assets-unsafe)) 
      (try! (contract-call? 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v2-1-7 withdraw
        'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zsbtc-v2-0
        'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-0-reserve-v2-0
        'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
        'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4
        sbtc-amount
        current-contract
        (list
          { asset: 'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststx-token, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zststx-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 }
          { asset: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zaeusdc-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.aeusdc-oracle-v1-0 }
          { asset: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.wstx, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zwstx-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 }
          { asset: 'SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.arkadiko-token, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zdiko-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.diko-oracle-v1-1 }
          { asset: 'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.usdh-token-v1, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zusdh-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.usdh-oracle-v1-0 }
          { asset: 'SP2XD7417HGPRTREMKF748VNEQPDRR0RMANB7X1NK.token-susdt, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zsusdt-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.susdt-oracle-v1-0 }
          { asset: 'SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.usda-token, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zusda-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.usda-oracle-v1-1 }
          { asset: 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zsbtc-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 }
          { asset: 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zalex-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.alex-oracle-v1-1 }
          { asset: 'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststxbtc-token-v2, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zststxbtc-v2_v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 }
        )
        'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.incentives-v2-2
        price-feed-bytes
      ))
    ))
    
    (print { action: "pillar-withdraw-collateral", sbtc-withdrawn: sbtc-amount })
    (ok { sbtc-withdrawn: sbtc-amount })
  )
)

(define-public (pillar-borrow-more
    (aeusdc-amount uint)
    (price-feed-bytes (optional (buff 8192)))
    (sig-auth (optional { auth-id: uint, signature: (buff 65), pubkey: (buff 33) }))
  )
  (begin
    (update-activity)
    (match sig-auth
      sig-auth-details (try! (is-authorized (some {
        message-hash: (contract-call?
          'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.smart-wallet-standard-auth-helpers-v2
          build-pillar-borrow-more-hash {
          auth-id: (get auth-id sig-auth-details),
          aeusdc-amount: aeusdc-amount,
        }),
        signature: (get signature sig-auth-details),
        pubkey: (get pubkey sig-auth-details),
      })))
      (try! (is-authorized none))
    )
    
    (try! (as-contract? ((with-all-assets-unsafe)) 
      (try! (contract-call? 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v2-1-7 borrow
        'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-0-reserve-v2-0
        'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.aeusdc-oracle-v1-0
        'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc
        'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zaeusdc-v2-0
        (list
          { asset: 'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststx-token, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zststx-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 }
          { asset: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zaeusdc-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.aeusdc-oracle-v1-0 }
          { asset: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.wstx, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zwstx-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 }
          { asset: 'SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.arkadiko-token, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zdiko-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.diko-oracle-v1-1 }
          { asset: 'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.usdh-token-v1, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zusdh-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.usdh-oracle-v1-0 }
          { asset: 'SP2XD7417HGPRTREMKF748VNEQPDRR0RMANB7X1NK.token-susdt, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zsusdt-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.susdt-oracle-v1-0 }
          { asset: 'SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.usda-token, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zusda-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.usda-oracle-v1-1 }
          { asset: 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zsbtc-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 }
          { asset: 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zalex-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.alex-oracle-v1-1 }
          { asset: 'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststxbtc-token-v2, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zststxbtc-v2_v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 }
        )
        aeusdc-amount
        'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.fees-calculator
        u0
        current-contract
        price-feed-bytes
      ))
    ))
    
    (print { action: "pillar-borrow-more", aeusdc-borrowed: aeusdc-amount })
    (ok { aeusdc-borrowed: aeusdc-amount })
  )
)

(define-public (pillar-repay-withdraw
    (aeusdc-to-repay uint)
    (sbtc-to-withdraw uint)
    (price-feed-bytes (optional (buff 8192)))
    (sig-auth (optional { auth-id: uint, signature: (buff 65), pubkey: (buff 33) }))
  )
  (begin
    (update-activity)
    (match sig-auth
      sig-auth-details (try! (is-authorized (some {
        message-hash: (contract-call?
          'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.smart-wallet-standard-auth-helpers-v2
          build-pillar-repay-withdraw-hash {
          auth-id: (get auth-id sig-auth-details),
          aeusdc-to-repay: aeusdc-to-repay,
          sbtc-to-withdraw: sbtc-to-withdraw,
        }),
        signature: (get signature sig-auth-details),
        pubkey: (get pubkey sig-auth-details),
      })))
      (try! (is-authorized none))
    )
    
    (if (> aeusdc-to-repay u0)
    (try! (as-contract? ((with-all-assets-unsafe)) 
      (try! (contract-call? 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v2-1-7 repay
        'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc
        aeusdc-to-repay
        current-contract
        current-contract
      ))
    ))
    true)
    
    (if (> sbtc-to-withdraw u0)
    (try! (as-contract? ((with-all-assets-unsafe)) 
      (try! (contract-call? 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v2-1-7 withdraw
        'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zsbtc-v2-0
        'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-0-reserve-v2-0
        'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
        'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4
        sbtc-to-withdraw
        current-contract
        (list
          { asset: 'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststx-token, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zststx-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 }
          { asset: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zaeusdc-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.aeusdc-oracle-v1-0 }
          { asset: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.wstx, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zwstx-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 }
          { asset: 'SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.arkadiko-token, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zdiko-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.diko-oracle-v1-1 }
          { asset: 'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.usdh-token-v1, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zusdh-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.usdh-oracle-v1-0 }
          { asset: 'SP2XD7417HGPRTREMKF748VNEQPDRR0RMANB7X1NK.token-susdt, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zsusdt-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.susdt-oracle-v1-0 }
          { asset: 'SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.usda-token, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zusda-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.usda-oracle-v1-1 }
          { asset: 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zsbtc-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 }
          { asset: 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zalex-v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.alex-oracle-v1-1 }
          { asset: 'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststxbtc-token-v2, lp-token: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zststxbtc-v2_v2-0, oracle: 'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-btc-oracle-v1-4 }
        )
        'SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.incentives-v2-2
        price-feed-bytes
      ))
    ))
    true)
    
    (print { action: "pillar-repay-withdraw", aeusdc-repaid: aeusdc-to-repay, sbtc-withdrawn: sbtc-to-withdraw })
    (ok { aeusdc-repaid: aeusdc-to-repay, sbtc-withdrawn: sbtc-to-withdraw })
  )
)

(define-map admins
  principal
  bool
)

(define-map pubkey-to-admin
  (buff 33) 
  principal
)

(define-read-only (is-admin-pubkey (pubkey (buff 33)))
  (let ((user-opt (map-get? pubkey-to-admin pubkey)))
    (match user-opt
      user (ok (unwrap! (is-admin-calling user) err-not-admin-pubkey))
      err-unregistered-pubkey
    )
  )
)

(define-public (propose-transfer-wallet (new-admin principal))
  (begin
    (try! (is-admin-calling tx-sender))
    (asserts! (not (is-eq new-admin tx-sender)) err-forbidden)
    (var-set pending-transfer new-admin)
    (update-activity)
    (print { a: "propose-transfer-wallet", proposed: new-admin })
    (ok true)
  )
)

(define-public (confirm-transfer-wallet
    (sig-auth {
      auth-id: uint,
      signature: (buff 65),
      pubkey: (buff 33),
    })
  )
  (let ((pending (var-get pending-transfer)))
    (asserts! (not (is-eq pending 'SP000000000000000000002Q6VF78)) err-no-pending-transfer)
    (try! (is-authorized (some {
      message-hash: (contract-call? 
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.smart-wallet-standard-auth-helpers-v2
        build-confirm-transfer-hash {
        auth-id: (get auth-id sig-auth),
        new-admin: pending,
      }),
      signature: (get signature sig-auth),
      pubkey: (get pubkey sig-auth),
    })))
    (try! (ft-mint? ect u1 current-contract))
    (try! (ft-burn? ect u1 current-contract))
    (map-set admins pending true)
    (map-delete admins (var-get owner))
    (var-set owner pending)
    (var-set pending-transfer 'SP000000000000000000002Q6VF78)
    (update-activity)
    (print { a: "confirm-transfer-wallet", new-admin: pending })
    (ok true)
  )
)

(define-public (propose-admin-pubkey (pubkey (buff 33)))
  (begin
    (try! (is-admin-calling tx-sender))
    (var-set pending-pubkey {
      pubkey: pubkey,
      proposed-at: burn-block-height,
    })
    (update-activity)
    (print { a: "propose-admin-pubkey", pubkey: pubkey, proposed-at: burn-block-height })
    (ok true)
  )
)

(define-public (confirm-admin-pubkey)
  (let (
      (pending (var-get pending-pubkey))
      (config (var-get wallet-config))
      (wallet-cooldown (get cooldown-period config))
      (effective-cooldown (if (> wallet-cooldown MAX-CONFIG-COOLDOWN)
        MAX-CONFIG-COOLDOWN
        wallet-cooldown
      ))
      (pubk (get pubkey pending))
    )
    (asserts! (not (is-eq (get proposed-at pending) u0)) err-no-pending-pubkey)
    (asserts! (>= burn-block-height (+ (get proposed-at pending) effective-cooldown)) err-in-cooldown)
    (try! (is-admin-calling tx-sender))
    (map-set pubkey-to-admin pubk tx-sender)
    (var-set pending-pubkey {
      pubkey: 0x000000000000000000000000000000000000000000000000000000000000000000,
      proposed-at: u0,
    })
    (update-activity)
    (print { a: "confirm-admin-pubkey", pubkey: pubk })
    (ok true)
  )
)

(define-public (remove-admin-pubkey (pubkey (buff 33)))
  (begin
    (try! (is-authorized none))
    (ok (map-delete pubkey-to-admin pubkey))
  )
)

(define-read-only (verify-signature
    (message-hash (buff 32))
    (signature (buff 65))
    (pubkey (buff 33))
  )
  (begin
    (try! (is-admin-pubkey pubkey))
    (ok (asserts! (is-eq (secp256k1-recover? message-hash signature) (ok pubkey))
      err-invalid-signature
    ))
  )
)

(define-private (consume-signature
    (message-hash (buff 32))
    (signature (buff 65))
    (pubkey (buff 33))
  )
  (begin
    (try! (verify-signature message-hash signature pubkey))
    (asserts! (is-none (map-get? used-pubkey-authorizations message-hash))
      err-signature-replay
    )
    (map-set used-pubkey-authorizations message-hash pubkey)
    (ok true)
  )
)

(define-read-only (get-owner)
  (ok (var-get owner))
)

(define-read-only (is-inactive)
  (> burn-block-height (+ INACTIVITY-PERIOD (var-get last-activity-block)))
)

(define-private (update-activity)
  (var-set last-activity-block burn-block-height)
)

(define-public (add-admin-with-signature
    (new-admin principal)
    (sig-auth {
      auth-id: uint,
      signature: (buff 65),
      pubkey: (buff 33),
    })
  )
  (begin
    (asserts! (not (var-get is-initialized)) err-already-initialized)
    (try! (is-authorized (some {
      message-hash: (contract-call? 
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.smart-wallet-standard-auth-helpers-v2
        build-add-admin-hash {
        auth-id: (get auth-id sig-auth),
        new-admin: new-admin,
      }),
      signature: (get signature sig-auth),
      pubkey: (get pubkey sig-auth),
    })))
    (map-delete admins 'SP000000000000000000002Q6VF78)
    (map-set admins new-admin true)
    (map-set pubkey-to-admin (get pubkey sig-auth) new-admin)
    (var-set owner new-admin)
    (update-activity)
    (var-set is-initialized true)
    (print { a: "add-admin", admin: new-admin })
    (ok true)
  )
)

(define-public (propose-recovery
    (new-recovery principal)
    (sig-auth {
      auth-id: uint,
      signature: (buff 65),
      pubkey: (buff 33),
    })
  )
  (begin
    (try! (is-authorized (some {
      message-hash: (contract-call? 
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.smart-wallet-standard-auth-helpers-v2
        build-propose-recovery-hash {
        auth-id: (get auth-id sig-auth),
        new-recovery: new-recovery,
      }),
      signature: (get signature sig-auth),
      pubkey: (get pubkey sig-auth),
    })))
    (var-set pending-recovery new-recovery)
    (update-activity)
    (print { a: "propose-recovery", proposed: new-recovery })
    (ok true)
  )
)

(define-public (confirm-recovery)
  (let ((pending (var-get pending-recovery)))
    (asserts! (not (is-eq pending 'SP000000000000000000002Q6VF78)) err-no-pending-recovery)
    (try! (is-admin-calling tx-sender))
    (var-set recovery-address pending)
    (var-set pending-recovery 'SP000000000000000000002Q6VF78)
    (update-activity)
    (print { a: "confirm-recovery", recovery: pending })
    (ok true)
  )
)

(define-public (recover-inactive-wallet (new-admin principal))
  (begin
    (asserts! (is-inactive) err-inactive-required)
    (asserts! (is-eq tx-sender (var-get recovery-address)) err-unauthorised)
    (map-delete admins (var-get owner))
    (map-set admins new-admin true)
    (var-set owner new-admin)
    (var-set last-activity-block burn-block-height)
    (print { a: "recover-inactive-wallet", new-admin: new-admin, recovered-by: tx-sender })
    (ok true)
  )
)

(define-read-only (get-pending-guardian)
  (var-get pending-guardian)
)

(define-public (propose-guardian
    (new-guardian principal)
    (max-drawdown-ltv uint)
    (target-ltv uint)
    (sig-auth {
      auth-id: uint,
      signature: (buff 65),
      pubkey: (buff 33),
    })
  )
  (begin
    (try! (is-authorized (some {
      message-hash: (contract-call?
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.smart-wallet-standard-auth-helpers-v2
        build-propose-guardian-hash {
        auth-id: (get auth-id sig-auth),
        new-guardian: new-guardian,
        max-drawdown-ltv: max-drawdown-ltv,
        target-ltv: target-ltv,
      }),
      signature: (get signature sig-auth),
      pubkey: (get pubkey sig-auth),
    })))
    (asserts! (< target-ltv max-drawdown-ltv) err-invalid-operation)
    (asserts! (<= max-drawdown-ltv u75000000) err-invalid-operation)
    (var-set pending-guardian {
      guardian: (some new-guardian),
      max-drawdown-ltv: max-drawdown-ltv,
      target-ltv: target-ltv,
      proposed-at: burn-block-height,
    })
    (print { 
      a: "propose-guardian",
      guardian: new-guardian,
      max-drawdown-ltv: max-drawdown-ltv,
      target-ltv: target-ltv,
    })
    (ok true)
  )
)

(define-public (confirm-guardian)
  (let ((pending (var-get pending-guardian)))
    (asserts! (is-some (get guardian pending)) err-invalid-operation)
    (try! (is-admin-calling tx-sender))
    (var-set guardian-principal (get guardian pending))
    (var-set guardian-max-drawdown-ltv (get max-drawdown-ltv pending))
    (var-set guardian-target-ltv (get target-ltv pending))
    (var-set guardian-enabled true)
    (var-set pending-guardian {
      guardian: none,
      max-drawdown-ltv: u0,
      target-ltv: u0,
      proposed-at: u0,
    })
    (print { 
      a: "confirm-guardian", 
      guardian: (get guardian pending), 
      max-drawdown-ltv: (get max-drawdown-ltv pending),
      target-ltv: (get target-ltv pending),
      enabled: true 
    })
    (ok true)
  )
)

(define-public (disable-guardian
    (sig-auth (optional {
      auth-id: uint,
      signature: (buff 65),
      pubkey: (buff 33),
    }))
  )
  (begin
    (match sig-auth
      sig-auth-details (try! (is-authorized (some {
        message-hash: (contract-call?
          'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.smart-wallet-standard-auth-helpers-v2
          build-disable-guardian-hash {
          auth-id: (get auth-id sig-auth-details),
        }),
        signature: (get signature sig-auth-details),
        pubkey: (get pubkey sig-auth-details),
      })))
      (try! (is-authorized none))
    )
    (var-set guardian-enabled false)
    (print { a: "disable-guardian" })
    (ok true)
  )
)

(define-private (is-guardian-calling)
  (match (var-get guardian-principal)
    guardian (and 
      (is-eq contract-caller guardian)
      (var-get guardian-enabled)
    )
    false
  )
)

(define-read-only (get-guardian-config)
  {
    guardian: (var-get guardian-principal),
    enabled: (var-get guardian-enabled),
    max-drawdown-ltv: (var-get guardian-max-drawdown-ltv),
    target-ltv: (var-get guardian-target-ltv),
  }
)

(define-public (set-guardian-unwind-permission
    (sbtc-to-swap uint)
    (sbtc-to-withdraw uint)
    (price-feed-bytes (optional (buff 8192)))
  )
  (let (
    (guardian (unwrap! (var-get guardian-principal) err-guardian-not-allowed))
  )
    (asserts! (is-eq contract-caller guardian) err-unauthorised)
    (asserts! (var-get guardian-enabled) err-guardian-not-allowed)
    
    (try! (as-contract? ((with-all-assets-unsafe))
      (try! (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.guardian request-unwind-permission
        (var-get guardian-max-drawdown-ltv)
        (var-get guardian-target-ltv)
        sbtc-to-swap
        sbtc-to-withdraw
        price-feed-bytes
      ))
    ))
    (var-set guardian-unwind-permission {
      sbtc-to-swap: sbtc-to-swap,
      sbtc-to-withdraw: sbtc-to-withdraw,
      granted-at: burn-block-height,
    })
    
    (print { 
      a: "guardian-unwind-permission-set",
      sbtc-to-swap: sbtc-to-swap,
      sbtc-to-withdraw: sbtc-to-withdraw,
      granted-at: burn-block-height,
    })
    (ok true)
  )
)

(define-public (set-guardian-repay-permission
    (aeusdc-amount uint)
    (price-feed-bytes (optional (buff 8192)))
  )
  (let (
    (guardian (unwrap! (var-get guardian-principal) err-guardian-not-allowed))
  )
    (asserts! (is-eq contract-caller guardian) err-unauthorised)
    (asserts! (var-get guardian-enabled) err-guardian-not-allowed)
    
    (try! (as-contract? ((with-all-assets-unsafe))
      (try! (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.guardian request-repay-permission
        (var-get guardian-max-drawdown-ltv)
        (var-get guardian-target-ltv)
        aeusdc-amount
        price-feed-bytes
      ))
    ))
    
    (var-set guardian-repay-permission {
      aeusdc-amount: aeusdc-amount,
      granted-at: burn-block-height,
    })
    
    (print { 
      a: "guardian-repay-permission-set",
      aeusdc-amount: aeusdc-amount,
      granted-at: burn-block-height,
    })
    (ok true)
  )
)

(define-public (enroll-dual-stacking
    (sig-auth (optional { auth-id: uint, signature: (buff 65), pubkey: (buff 33) }))
  )
  (begin
    (update-activity)
    (match sig-auth
      sig-auth-details (try! (is-authorized (some {
        message-hash: (contract-call?
          'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.smart-wallet-standard-auth-helpers-v2
          build-enroll-dual-stacking-hash {
          auth-id: (get auth-id sig-auth-details),
        }),
        signature: (get signature sig-auth-details),
        pubkey: (get pubkey sig-auth-details),
      })))
      (try! (is-authorized none))
    )
    (as-contract? ((with-all-assets-unsafe))
      (try! (contract-call? 'SP1HFCRKEJ8BYW4D0E3FAWHFDX8A25PPAA83HWWZ9.dual-stacking-v2_0_2 enroll none))
    )
  )
)

(define-public (stack-stx-fast-pool
    (amount-ustx uint)
    (sig-auth (optional { auth-id: uint, signature: (buff 65), pubkey: (buff 33) }))
  )
  (begin
    (update-activity)
    (match sig-auth
      sig-auth-details (try! (is-authorized (some {
        message-hash: (contract-call?
          'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.smart-wallet-standard-auth-helpers-v2
          build-stack-stx-fast-pool-hash {
          auth-id: (get auth-id sig-auth-details),
          amount-ustx: amount-ustx,
        }),
        signature: (get signature sig-auth-details),
        pubkey: (get pubkey sig-auth-details),
      })))
      (try! (is-authorized none))
    )

    (try! (as-contract? ((with-all-assets-unsafe))
      (try! (match (contract-call?
        'SP000000000000000000002Q6VF78.pox-4
        allow-contract-caller
        'SP21YTSM60CAY6D011EZVEVNKXVW8FVZE198XEFFP.pox4-fast-pool-v3
        none)
        success (ok success)
        error (err (to-uint error))))))

    (print {
      a: "stack-stx-fast-pool",
      payload: { amount-ustx: amount-ustx },
    })

    (as-contract? ((with-all-assets-unsafe))
      (try! (match (contract-call?
        'SP21YTSM60CAY6D011EZVEVNKXVW8FVZE198XEFFP.pox4-fast-pool-v3
        delegate-stx
        amount-ustx)
        success (ok true)
        error (err error))))
  )
)

(define-public (revoke-fast-pool
    (sig-auth (optional { auth-id: uint, signature: (buff 65), pubkey: (buff 33) }))
  )
  (begin
    (update-activity)
    (match sig-auth
      sig-auth-details (try! (is-authorized (some {
        message-hash: (contract-call?
          'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.smart-wallet-standard-auth-helpers-v2
          build-revoke-fast-pool-hash {
          auth-id: (get auth-id sig-auth-details),
        }),
        signature: (get signature sig-auth-details),
        pubkey: (get pubkey sig-auth-details),
      })))
      (try! (is-authorized none))
    )

    (print {
      a: "revoke-fast-pool",
    })

    (as-contract? ((with-all-assets-unsafe))
      (try! (match (contract-call?
        'SP000000000000000000002Q6VF78.pox-4
        revoke-delegate-stx)
        success (ok true)
        error (err (to-uint error)))))
  )
)

(define-public (stake-stx-stacking-dao
    (stx-amount uint)
    (sig-auth (optional { auth-id: uint, signature: (buff 65), pubkey: (buff 33) }))
  )
  (begin
    (update-activity)
    (match sig-auth
      sig-auth-details (try! (is-authorized (some {
        message-hash: (contract-call?
          'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.smart-wallet-standard-auth-helpers-v2
          build-stake-stx-stacking-dao-hash {
          auth-id: (get auth-id sig-auth-details),
          stx-amount: stx-amount,
        }),
        signature: (get signature sig-auth-details),
        pubkey: (get pubkey sig-auth-details),
      })))
      (try! (is-authorized none))
    )

    (print {
      a: "stake-stx-stacking-dao",
      payload: { stx-amount: stx-amount },
    })

    (as-contract? ((with-all-assets-unsafe))
      (try! (match (contract-call?
        'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.stacking-dao-core-v6
        deposit
        'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.reserve-v1
        'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.commission-v2
        'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.staking-v0
        'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.direct-helpers-v4
        stx-amount
        (some 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22) 
        none) 
        success (ok true)
        error (err error))))
  )
)

(map-set admins 'SP000000000000000000002Q6VF78 true)
(map-set admins current-contract true) 

  (define-public (onboard (pubkey (buff 33)))
    (begin
      (asserts! (is-eq tx-sender PILLAR-DEPLOYER) err-unauthorised)
      (asserts! (not (var-get pubkey-initialized)) err-unauthorised)
      (var-set initial-pubkey pubkey)
      (map-set pubkey-to-admin pubkey 'SP000000000000000000002Q6VF78)
      (var-set pubkey-initialized true)
      (print { a: "wallet-pubkey-initialized", pubkey: pubkey })
      (ok true)
    )
  )

```
