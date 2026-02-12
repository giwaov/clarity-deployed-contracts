---
title: "Trait dual-stacking-v2-test-snapshots"
draft: true
---
```
(define-constant ERR_ACTIVATION_HEIGHT_NOT_MET (err u100))
(define-constant ERR_ALREADY_ENROLLED (err u101))
(define-constant ERR_USER_BLACKLISTED (err u102))
(define-constant ERR_NOT_ENROLLED (err u103))
(define-constant ERR_ENROLL_MINIMUM_HOLD_NOT_MET (err u104))
(define-constant ERR_CYCLE_IN_FUTURE (err u105))
(define-constant ERR_ALREADY_PROPOSED_RATIO (err u106))
(define-constant ERR_RATIO_NOT_PROPOSED (err u107))
(define-constant ERR_COMPUTE_RATIO_FOR_ALL_PARTICIPANTS_FIRST (err u108))
(define-constant ERR_COMPUTED_RATIO_ALL_PARTICIPANTS (err u109))
(define-constant ERR_RATIO_TOO_LOW (err u110))
(define-constant ERR_RATIO_TOO_HIGH (err u111))
(define-constant ERR_ALREADY_VALIDATED_RATIO (err u112))
(define-constant ERR_INVALID_RATIO_FOR_ZERO_STX (err u113))
(define-constant ERR_NOT_BLACKLISTED (err u114))

(define-constant ERR_NOT_NEW_CYCLE_YET (err u120))
(define-constant ERR_CYCLE_ENDED (err u121))
(define-constant ERR_CYCLE_ENDED_2 (err u122))
(define-constant ERR_NOT_REWARDED_ALL (err u123))
(define-constant ERR_REWARDS_NOT_SENT_YET (err u124))

(define-constant ERR_NOT_NEW_SNAPSHOT_YET (err u140))
(define-constant ERR_NOT_SNAPSHOTTED_ALL_PARTICIPANTS (err u141))
(define-constant ERR_NOT_ALL_SNAPSHOTS (err u142))
(define-constant ERR_SNAPSHOTS_NOT_CONCLUDED (err u143))
(define-constant ERR_SNAPSHOTS_ALREADY_CONCLUDED (err u144))
(define-constant ERR_STX_BLOCK_NOT_MATCHING (err u145))
(define-constant ERR_STX_BLOCK_IN_FUTURE (err u146))
(define-constant ERR_NOT_OPTIMIZED_OPERATOR (err u147))

(define-constant ERR_RATIOS_NOT_CONCLUDED (err u160))
(define-constant ERR_WEIGHTS_NOT_COMPUTED (err u161))
(define-constant ERR_WEIGHTS_ALREADY_COMPUTED (err u162))
(define-constant ERR_NOT_ALL_WEIGHTS_COMPUTED (err u163))

(define-constant ERR_CANNOT_DISTRIBUTE_REWARDS (err u180))
(define-constant ERR_ALREADY_REWARDED (err u181))
(define-constant ERR_SET_CAN_DISTRIBUTE_ALREADY_CALLED (err u182))
(define-constant ERR_ALREADY_FINALIZED (err u183))
(define-constant ERR_CANNOT_FINALIZE (err u184))
(define-constant ERR_BUFFER_NOT_ACTIVATED (err u185))
(define-constant ERR_BUFFER_PERIOD_NOT_PASSED (err u186))
(define-constant ERR_BUFFER_ALREADY_SET (err u187))

(define-constant ERR_NOT_ADMIN (err u200))
(define-constant ERR_CONTRACT_ALREADY_ACTIVE (err u201))
(define-constant ERR_CONTRACT_NOT_ACTIVE (err u202))
(define-constant ERR_APR_TOO_LOW (err u210))
(define-constant ERR_APR_TOO_HIGH (err u211))
(define-constant ERR_MULTIPLIER_TOO_LOW (err u212))
(define-constant ERR_MULTIPLIER_TOO_HIGH (err u213))

(define-constant ERR_INSUFFICIENT_FUNDS (err u240))

(define-constant ERR_NO_SNAPSHOT_DATA (err u260))
(define-constant ERR_CANNOT_ROLLBACK_FINALIZED_CYCLE (err u261))
(define-constant ERR_DEFI_NOT_COMPROMISED (err u262))

(define-constant ARKADIKO u1)
(define-constant BASED_DOLLAR u2)
(define-constant BITFLOW u3)
(define-constant GRANITE u4)
(define-constant VELAR u5)
(define-constant ZEST u6)

(define-constant SNAPSHOT_NOT_TAKEN_MARKER u1000)
(define-constant DECIMAL_PRECISION_8 u100000000)
(define-constant MIN_APR_SCALED u1000000)
(define-constant MAX_APR_SCALED u20000000)
(define-constant RATIO_SCALE_FACTOR u100000000)
(define-constant SQRT_RATIO_SCALE_FACTOR u10000)
(define-constant MIN_GOLDEN_RATIO u1)
(define-constant REWARD_MECHANISM_V1 u1)

(define-data-var is-contract-active bool false)
(define-data-var admin principal contract-caller)
(define-data-var last-operation-done uint u0)

(define-data-var cycle-id uint u3)
(define-data-var current-cycle-stacks-block-height uint u0)
(define-data-var current-cycle-stacks-block-hash (buff 32) 0x0000000000000000000000000000000000000000000000000000000000000000)
(define-data-var current-cycle-bitcoin-block-height uint u0)
(define-data-var current-cycle-total-sbtc-in-wallet uint u0)
(define-data-var current-cycle-total-sbtc-in-defis uint u0)
(define-data-var current-cycle-total-stx uint u0)
(define-data-var current-cycle-participants-count uint u0)

(define-data-var blocks-per-snapshot uint u0)
(define-data-var snapshots-per-cycle uint u0)
(define-data-var buffer-blocks-per-cycle uint u0)
(define-data-var next-blocks-per-snapshot uint (var-get blocks-per-snapshot))
(define-data-var next-snapshots-per-cycle uint (var-get snapshots-per-cycle))
(define-data-var next-buffer-blocks-per-cycle uint (var-get buffer-blocks-per-cycle))
(define-data-var next-cycle-bitcoin-block-height uint (+ (var-get current-cycle-bitcoin-block-height)
  (+ (* (var-get blocks-per-snapshot) (var-get snapshots-per-cycle))
    (var-get buffer-blocks-per-cycle)
  )))
(define-data-var bitcoin-blocks-per-year uint u52560)
(define-data-var buffer-period-start-block uint u0)

(define-data-var current-snapshot-bitcoin-block-height uint u0)
(define-data-var current-snapshot-stacks-block-height uint u0)
(define-data-var current-snapshot-total-sbtc uint u0)
(define-data-var current-snapshot-total-sbtc-in-defis uint u0)
(define-data-var current-snapshot-total-stx uint u0)
(define-data-var current-snapshot-count uint u0)
(define-data-var current-snapshot-index uint u0)
(define-data-var are-snapshots-finalized bool false)
(define-data-var is-buffer-set bool false)
(define-data-var is-liquid-stacking-enabled bool true)

(define-data-var snapshot-block-hash (buff 32) 0x0000000000000000000000000000000000000000000000000000000000000000)

(define-data-var is-ratio-validated bool false)
(define-data-var is-distribution-enabled bool false)
(define-data-var rewards-to-distribute uint u0)
(define-data-var participants-rewarded-count uint u0)

(define-data-var annual-percentage-rate uint u5000000)

(define-data-var yield-boost-multiplier uint u9)

(define-data-var reward-calculation-mechanism uint REWARD_MECHANISM_V1)

(define-data-var total-weights-sum uint u0)
(define-data-var weights-computed-count uint u0)
(define-data-var are-weights-computed bool false)

(define-data-var next-cycle-participants-count uint u0)
(define-data-var min-sbtc-hold-required-for-enrollment uint u10000)

(define-data-var ratio-being-tallied uint u0)
(define-data-var max-percentage-above-golden-ratio uint u500)
(define-constant PERCENTAGE_PRECISION_FACTOR u100)

(var-set current-cycle-bitcoin-block-height u927408)
(var-set snapshots-per-cycle u14)
(var-set blocks-per-snapshot u140)
(var-set buffer-blocks-per-cycle u140)

(define-data-var current-cycle-rollback-id uint u0)

(define-map participants
  { address: principal }
  {
    stacking-address: principal,
    rewarded-address: principal,
    tracking-address: principal,
  }
)

(define-map blacklist
  { address: principal }
  { blacklisted: bool }
)

(define-map participant-holdings-per-cycle
  {
    cycle-id: uint,
    rollback-id: uint,
    participant-address: principal,
  }
  {
    sbtc-wallet-amount: uint,
    sbtc-defi-amount: uint,
    stx-stacked-amount: uint,
    last-snapshot-index: uint,
    has-been-rewarded: bool,
    reward-amount: uint,
  }
)

(define-map participant-addresses
  {
    cycle-id: uint,
    address: principal,
  }
  {
    stacking-address: principal,
    rewarded-address: principal,
    tracking-address: principal,
  }
)

(define-map sbtc-holdings-by-tracking-address
  {
    cycle-id: uint,
    rollback-id: uint,
    tracking-address: principal,
  }
  {
    sbtc-wallet-amount: uint,
    sbtc-defi-amount: uint,
    has-been-rewarded: bool,
  }
)

(define-map stx-stacked-by-stacking-address
  {
    cycle-id: uint,
    rollback-id: uint,
    stacking-address: principal,
  }
  { stx-amount: uint }
)

(define-map snapshot-processed-stacking-addresses
  {
    cycle-id: uint,
    rollback-id: uint,
    snapshot-index: uint,
    stacking-address: principal,
  }
  { has-been-processed: bool }
)

(define-map participant-weights-by-tracking-address
  {
    cycle-id: uint,
    tracking-address: principal,
  }
  {
    weight-wallet: uint,
    weight-defi: uint,
    weight-total: uint,
  }
)

(define-map participant-weight-computation-status
  {
    cycle-id: uint,
    participant-address: principal,
  }
  { has-been-computed: bool }
)

(define-map rewards-by-rewarded-address
  {
    cycle-id: uint,
    rewarded-address: principal,
  }
  { reward-amount: uint }
)

(define-map snapshot-aggregate-data
  {
    cycle-id: uint,
    rollback-id: uint,
    snapshot-index: uint,
  }
  {
    stacks-block-height: uint,
    bitcoin-block-height: uint,
    total-sbtc-wallet: uint,
    total-sbtc-defi: uint,
    total-stx-stacked: uint,
  }
)

(define-map cycle-finalization-block-heights
  { cycle-id: uint }
  { stacks-block-height-at-finalization: uint }
)

(define-map yield-cycles-data
  { cycle-id: uint }
  {
    blocks-per-snapshot: uint,
    snapshots-per-cycle: uint,
    start-btc-block-height: uint,
    start-stx-block-height: uint,
  }
)

(define-map golden-ratio-proposals
  {
    cycle-id: uint,
    proposer-address: principal,
  }
  {
    proposed-golden-ratio: uint,
    participants-tallied: uint,
    sbtc-below-ratio: uint,
    sbtc-above-ratio: uint,
    sbtc-equal-ratio: uint,
  }
)

(define-map validated-golden-ratio-per-cycle
  { cycle-id: uint }
  { golden-ratio: uint }
)

(define-map participant-ratio-computation-status
  {
    cycle-id: uint,
    proposer-address: principal,
    ratio-value: uint,
    participant-address: principal,
  }
  { has-been-computed: bool }
)

(define-map tracking-address-ratio-computation-status
  {
    cycle-id: uint,
    proposer-address: principal,
    ratio-value: uint,
    tracking-address: principal,
  }
  { has-been-computed: bool }
)

(define-map optimized-snapshot-operators
  { operator-address: principal }
  { is-whitelisted: bool }
)

(define-map compromised-defi-protocol
  { defi-name: uint }
  {
    compromised-at-cycle: uint,
    compromised-at-snapshot: uint,
  }
)

(define-public (update-initialize-block (new-bitcoin-block-height uint))
  (begin
    (asserts! (not (var-get is-contract-active))
      ERR_CONTRACT_ALREADY_ACTIVE
    )
    (asserts! (is-eq contract-caller (var-get admin)) ERR_NOT_ADMIN)
    (ok (var-set current-cycle-bitcoin-block-height
      new-bitcoin-block-height
    ))
  )
)

(define-public (initialize-contract (stx-block-height uint))
  (begin
    (asserts!
      (>= burn-block-height
        (var-get current-cycle-bitcoin-block-height)
      )
      ERR_ACTIVATION_HEIGHT_NOT_MET
    )
    (asserts! (not (var-get is-contract-active))
      ERR_CONTRACT_ALREADY_ACTIVE
    )
    (asserts!
      (unwrap-panic (validate-bitcoin-block stx-block-height
        (var-get current-cycle-bitcoin-block-height)
      ))
      ERR_STX_BLOCK_NOT_MATCHING
    )

    (var-set next-snapshots-per-cycle (var-get snapshots-per-cycle))
    (var-set next-blocks-per-snapshot (var-get blocks-per-snapshot))
    (var-set next-buffer-blocks-per-cycle
      (var-get buffer-blocks-per-cycle)
    )
    (reset-state-for-cycle stx-block-height)
    (var-set is-contract-active true)
    (ok true)
  )
)

(define-private (reset-state-for-cycle (stx-block-height uint))
  (begin
    (var-set blocks-per-snapshot (var-get next-blocks-per-snapshot))
    (var-set snapshots-per-cycle (var-get next-snapshots-per-cycle))
    (var-set buffer-blocks-per-cycle
      (var-get next-buffer-blocks-per-cycle)
    )
    (var-set is-distribution-enabled false)
    (var-set current-cycle-stacks-block-height stx-block-height)
    (var-set current-cycle-stacks-block-hash
      (unwrap-panic (get-stacks-block-info? id-header-hash stx-block-height))
    )
    (var-set current-cycle-total-sbtc-in-wallet u0)
    (var-set current-cycle-total-sbtc-in-defis u0)
    (var-set current-cycle-total-stx u0)
    (var-set current-snapshot-total-sbtc u0)
    (var-set current-cycle-rollback-id u0)
    (var-set current-snapshot-total-sbtc-in-defis u0)
    (var-set current-snapshot-total-stx u0)
    (var-set participants-rewarded-count u0)
    (var-set are-snapshots-finalized false)
    (var-set is-ratio-validated false)
    (var-set are-weights-computed false)
    (var-set weights-computed-count u0)
    (var-set total-weights-sum u0)
    (var-set buffer-period-start-block
      (+ (var-get current-cycle-bitcoin-block-height)
        (* (- (var-get snapshots-per-cycle) u1)
          (var-get blocks-per-snapshot)
        ))
    )
    (map-set yield-cycles-data { cycle-id: (var-get cycle-id) } {
      blocks-per-snapshot: (var-get blocks-per-snapshot),
      snapshots-per-cycle: (var-get snapshots-per-cycle),
      start-btc-block-height: (var-get current-cycle-bitcoin-block-height),
      start-stx-block-height: stx-block-height,
    })
    (var-set last-operation-done u0)
    (var-set current-cycle-participants-count
      (at-block
        (unwrap-panic (get-stacks-block-info? id-header-hash stx-block-height))
        (var-get next-cycle-participants-count)
      ))
    (var-set is-buffer-set false)
    (var-set rewards-to-distribute u0)
    (var-set next-cycle-bitcoin-block-height
      (+ (var-get current-cycle-bitcoin-block-height)
        (+
          (* (var-get blocks-per-snapshot)
            (var-get snapshots-per-cycle)
          )
          (var-get buffer-blocks-per-cycle)
        ))
    )

    (var-set current-snapshot-bitcoin-block-height
      (var-get current-cycle-bitcoin-block-height)
    )
    (var-set current-snapshot-count u0)
    (var-set current-snapshot-index u0)
    (var-set current-snapshot-stacks-block-height stx-block-height)

    (map-set snapshot-aggregate-data {
      cycle-id: (var-get cycle-id),
      rollback-id: (var-get current-cycle-rollback-id),
      snapshot-index: (var-get current-snapshot-index),
    } {
      stacks-block-height: stx-block-height,
      bitcoin-block-height: (var-get current-cycle-bitcoin-block-height),
      total-sbtc-wallet: u0,
      total-sbtc-defi: u0,
      total-stx-stacked: u0,
    })
  )
)

(define-public (enroll (rewarded-address (optional principal)))
  (let (
      (rewards-recipient (default-to contract-caller rewarded-address))
      (cycle-id-current (var-get cycle-id))
      (current-snapshot-index-value (var-get current-snapshot-index))
      (arkadiko (is-defi-protocol-healthy ARKADIKO cycle-id-current
        current-snapshot-index-value
      ))
      (based-dollar (is-defi-protocol-healthy BASED_DOLLAR cycle-id-current
        current-snapshot-index-value
      ))
      (bitflow (is-defi-protocol-healthy BITFLOW cycle-id-current
        current-snapshot-index-value
      ))
      (granite (is-defi-protocol-healthy GRANITE cycle-id-current
        current-snapshot-index-value
      ))
      (velar (is-defi-protocol-healthy VELAR cycle-id-current
        current-snapshot-index-value
      ))
      (zest (is-defi-protocol-healthy ZEST cycle-id-current
        current-snapshot-index-value
      ))
    )
    (asserts!
      (is-none (map-get? participants { address: contract-caller }))
      ERR_ALREADY_ENROLLED
    )
    (asserts!
      (is-none (map-get? blacklist { address: contract-caller }))
      ERR_USER_BLACKLISTED
    )
    (asserts!
      (meets-enrollment-minimum {
        address: contract-caller,
        arkadiko: arkadiko,
        based-dollar: based-dollar,
        bitflow: bitflow,
        granite: granite,
        velar: velar,
        zest: zest,
      })
      ERR_ENROLL_MINIMUM_HOLD_NOT_MET
    )
    (var-set next-cycle-participants-count
      (+ (var-get next-cycle-participants-count) u1)
    )
    (print {
      bitcoin-block-height: burn-block-height,
      reward-address: rewards-recipient,
      enrolled-address: contract-caller,
      stacking-address: contract-caller,
      tracking-address: contract-caller,
      cycle-id: (var-get cycle-id),
      function-name: "enroll",
    })
    (ok (map-set participants { address: contract-caller } {
      rewarded-address: rewards-recipient,
      stacking-address: contract-caller,
      tracking-address: contract-caller,
    }))
  )
)

(define-public (enroll-defi-batch (defi-contracts (list
  900
  {
    defi-contract: principal,
    tracking-address: principal,
    rewarded-address: principal,
    stacking-address: (optional principal),
  }
)))
  (begin
    (asserts! (is-eq contract-caller (var-get admin)) ERR_NOT_ADMIN)
    (ok (map enroll-defi-one defi-contracts))
  )
)

(define-private (enroll-defi-one (entry {
  defi-contract: principal,
  tracking-address: principal,
  rewarded-address: principal,
  stacking-address: (optional principal),
}))
  (let (
      (defi-contract (get defi-contract entry))
      (stacking-address (get stacking-address entry))
      (rewarded-address (get rewarded-address entry))
      (tracking-address (get tracking-address entry))
    )
    (try! (enroll-defi defi-contract tracking-address rewarded-address
      stacking-address
    ))
    (ok true)
  )
)

(define-private (enroll-defi
    (defi-contract principal)
    (tracking-address principal)
    (rewarded-address principal)
    (stacking-address (optional principal))
  )
  (let ((stacking-recipient (default-to defi-contract stacking-address)))
    (asserts!
      (is-none (map-get? participants { address: defi-contract }))
      ERR_ALREADY_ENROLLED
    )
    (asserts! (is-none (map-get? blacklist { address: defi-contract }))
      ERR_USER_BLACKLISTED
    )
    (var-set next-cycle-participants-count
      (+ (var-get next-cycle-participants-count) u1)
    )
    (print {
      bitcoin-block-height: burn-block-height,
      reward-address: rewarded-address,
      stacking-address: stacking-recipient,
      tracking-address: tracking-address,
      enrolled-address: defi-contract,
      cycle-id: (var-get cycle-id),
      function-name: "enroll",
    })
    (ok (map-set participants { address: defi-contract } {
      rewarded-address: rewarded-address,
      stacking-address: stacking-recipient,
      tracking-address: tracking-address,
    }))
  )
)

(define-public (opt-out)
  (begin
    (asserts!
      (is-some (map-get? participants { address: contract-caller }))
      ERR_NOT_ENROLLED
    )
    (ok (remove-participant contract-caller))
  )
)

(define-public (opt-out-defi-batch (defi-contracts (list 200 principal)))
  (begin
    (asserts! (is-eq contract-caller (var-get admin)) ERR_NOT_ADMIN)
    (ok (map opt-out-defi defi-contracts))
  )
)

(define-private (opt-out-defi (defi-contract principal))
  (begin
    (asserts!
      (is-some (map-get? participants { address: defi-contract }))
      ERR_NOT_ENROLLED
    )
    (ok (remove-participant defi-contract))
  )
)

(define-private (remove-participant (address principal))
  (begin
    (print {
      bitcoin-block-height: burn-block-height,
      enrolled-address: address,
      cycle-id: (var-get cycle-id),
      function-name: "opt-out",
    })
    (map-delete participants { address: address })
    (var-set next-cycle-participants-count
      (- (var-get next-cycle-participants-count) u1)
    )
  )
)

(define-public (set-liquid-stacking (state bool))
  (begin
    (asserts! (is-eq contract-caller (var-get admin)) ERR_NOT_ADMIN)
    (ok (var-set is-liquid-stacking-enabled state))
  )
)

(define-public (add-optimized-operator-batch (address (list 200 principal)))
  (begin
    (asserts! (is-eq contract-caller (var-get admin)) ERR_NOT_ADMIN)
    (map add-optimized-operator address)
    (ok true)
  )
)

(define-private (add-optimized-operator (operator-address principal))
  (map-set optimized-snapshot-operators { operator-address: operator-address } { is-whitelisted: true })
)

(define-public (remove-optimized-operator-batch (address (list 200 principal)))
  (begin
    (asserts! (is-eq contract-caller (var-get admin)) ERR_NOT_ADMIN)
    (map remove-optimized-operator address)
    (ok true)
  )
)

(define-private (remove-optimized-operator (operator-address principal))
  (map-delete optimized-snapshot-operators { operator-address: operator-address })
)

(define-public (change-reward-address (new-address principal))
  (let ((participant (unwrap! (map-get? participants { address: contract-caller })
      ERR_NOT_ENROLLED
    )))
    (print {
      bitcoin-block-height: burn-block-height,
      reward-address: new-address,
      stacking-address: (get stacking-address participant),
      tracking-address: (get tracking-address participant),
      enrolled-address: contract-caller,
      cycle-id: (var-get cycle-id),
      function-name: "update-participant-details",
    })
    (ok (map-set participants { address: contract-caller }
      (merge participant { rewarded-address: new-address })
    ))
  )
)

(define-public (change-addresses-defi-batch (defi-contracts (list
  900
  {
    defi-contract: principal,
    tracking-address: (optional principal),
    rewarded-address: (optional principal),
    stacking-address: (optional principal),
  }
)))
  (begin
    (asserts! (is-eq contract-caller (var-get admin)) ERR_NOT_ADMIN)
    (ok (map change-addresses-defi-one defi-contracts))
  )
)

(define-private (change-addresses-defi-one (entry {
  defi-contract: principal,
  tracking-address: (optional principal),
  rewarded-address: (optional principal),
  stacking-address: (optional principal),
}))
  (let (
      (defi-contract (get defi-contract entry))
      (participant (unwrap! (map-get? participants { address: defi-contract })
        ERR_NOT_ENROLLED
      ))
    )
    (let (
        (local-reward-address (default-to (get rewarded-address participant)
          (get rewarded-address entry)
        ))
        (local-stacking-address (default-to (get stacking-address participant)
          (get stacking-address entry)
        ))
        (local-tracking-address (default-to (get tracking-address participant)
          (get tracking-address entry)
        ))
      )
      (print {
        bitcoin-block-height: burn-block-height,
        reward-address: local-reward-address,
        stacking-address: local-stacking-address,
        tracking-address: local-tracking-address,
        enrolled-address: defi-contract,
        cycle-id: (var-get cycle-id),
        function-name: "update-participant-details",
      })
      (map-set participants { address: defi-contract } {
        rewarded-address: local-reward-address,
        tracking-address: local-tracking-address,
        stacking-address: local-stacking-address,
      })
      (ok true)
    )
  )
)

(define-public (add-blacklisted-batch (addresses (list 200 principal)))
  (begin
    (asserts! (is-eq (var-get admin) contract-caller) ERR_NOT_ADMIN)
    (ok (map add-blacklisted addresses))
  )
)

(define-private (add-blacklisted (address principal))
  (let ((participant (map-get? participants { address: address })))
    (if (is-some participant)
      (begin
        (remove-participant address)
        (print {
          bitcoin-block-height: burn-block-height,
          reward-address: (get rewarded-address participant),
          stacking-address: (get stacking-address participant),
          tracking-address: (get tracking-address participant),
          enrolled-address: address,
          cycle-id: (var-get cycle-id),
          function-name: "blacklisted",
        })
        (ok (map-set blacklist { address: address } { blacklisted: true }))
      )
      (begin
        (print {
          bitcoin-block-height: burn-block-height,
          enrolled-address: address,
          cycle-id: (var-get cycle-id),
          function-name: "blacklisted",
        })
        (ok (map-set blacklist { address: address } { blacklisted: true }))
      )
    )
  )
)

(define-public (remove-blacklisted-batch (addresses (list 200 principal)))
  (begin
    (asserts! (is-eq (var-get admin) contract-caller) ERR_NOT_ADMIN)
    (ok (map remove-blacklisted addresses))
  )
)

(define-private (remove-blacklisted (address principal))
  (begin
    (asserts! (is-some (map-get? blacklist { address: address }))
      ERR_NOT_BLACKLISTED
    )
    (print {
      bitcoin-block-height: burn-block-height,
      enrolled-address: address,
      cycle-id: (var-get cycle-id),
      function-name: "unblacklisted",
    })
    (ok (map-delete blacklist { address: address }))
  )
)

(define-public (update-admin (new-admin-address principal))
  (begin
    (asserts! (is-eq contract-caller (var-get admin)) ERR_NOT_ADMIN)
    (print {
      bitcoin-block-height: burn-block-height,
      admin-address: new-admin-address,
      cycle-id: (var-get cycle-id),
      function-name: "update-admin",
    })
    (ok (var-set admin new-admin-address))
  )
)

(define-public (update-min-sbtc-hold-required-for-enrollment (new-min-hold uint))
  (begin
    (asserts! (is-eq contract-caller (var-get admin)) ERR_NOT_ADMIN)
    (print {
      bitcoin-block-height: burn-block-height,
      min-sbtc-hold-required-for-enrollment: new-min-hold,
      cycle-id: (var-get cycle-id),
      function-name: "update-min-enrollment",
    })
    (ok (var-set min-sbtc-hold-required-for-enrollment new-min-hold))
  )
)

(define-public (update-snapshot-length (updated-blocks-per-snapshot uint))
  (begin
    (asserts! (is-eq (var-get admin) contract-caller) ERR_NOT_ADMIN)
    (print {
      bitcoin-block-height: burn-block-height,
      snapshot-length: updated-blocks-per-snapshot,
      cycle-id: (var-get cycle-id),
      function-name: "update-snapshot-length",
    })
    (ok (var-set next-blocks-per-snapshot updated-blocks-per-snapshot))
  )
)

(define-public (update-snapshots-per-cycle (updated-snapshots-per-cycle uint))
  (begin
    (asserts! (is-eq (var-get admin) contract-caller) ERR_NOT_ADMIN)
    (print {
      bitcoin-block-height: burn-block-height,
      snapshots-per-cycle: updated-snapshots-per-cycle,
      cycle-id: (var-get cycle-id),
      function-name: "update-snapshots-per-cycle",
    })
    (ok (var-set next-snapshots-per-cycle updated-snapshots-per-cycle))
  )
)

(define-public (update-buffer-blocks (updated-buffer-blocks-per-cycle uint))
  (begin
    (asserts! (is-eq (var-get admin) contract-caller) ERR_NOT_ADMIN)
    (print {
      bitcoin-block-height: burn-block-height,
      buffer-blocks-per-cycle: updated-buffer-blocks-per-cycle,
      cycle-id: (var-get cycle-id),
      function-name: "update-buffer-blocks",
    })
    (ok (var-set next-buffer-blocks-per-cycle
      updated-buffer-blocks-per-cycle
    ))
  )
)

(define-public (update-cycle-data
    (updated-snapshots-per-cycle uint)
    (updated-blocks-per-snapshot uint)
    (updated-buffer-blocks-per-cycle uint)
  )
  (begin
    (asserts! (is-eq (var-get admin) contract-caller) ERR_NOT_ADMIN)
    (print {
      bitcoin-block-height: burn-block-height,
      snapshot-length: updated-blocks-per-snapshot,
      snapshots-per-cycle: updated-snapshots-per-cycle,
      buffer-blocks-per-cycle: updated-buffer-blocks-per-cycle,
      cycle-id: (var-get cycle-id),
      function-name: "update-cycle-data",
    })
    (var-set next-snapshots-per-cycle updated-snapshots-per-cycle)
    (var-set next-blocks-per-snapshot updated-blocks-per-snapshot)
    (ok (var-set next-buffer-blocks-per-cycle
      updated-buffer-blocks-per-cycle
    ))
  )
)

(define-public (update-cycle-data-before-initialized
    (updated-snapshots-per-cycle uint)
    (updated-blocks-per-snapshot uint)
    (updated-buffer-blocks-per-cycle uint)
  )
  (begin
    (asserts! (is-eq (var-get admin) contract-caller) ERR_NOT_ADMIN)
    (asserts! (not (var-get is-contract-active))
      ERR_CONTRACT_ALREADY_ACTIVE
    )
    (print {
      bitcoin-block-height: burn-block-height,
      snapshot-length: updated-blocks-per-snapshot,
      snapshots-per-cycle: updated-snapshots-per-cycle,
      buffer-blocks-per-cycle: updated-buffer-blocks-per-cycle,
      cycle-id: (var-get cycle-id),
      function-name: "update-cycle-data",
    })
    (var-set next-snapshots-per-cycle updated-snapshots-per-cycle)
    (var-set next-blocks-per-snapshot updated-blocks-per-snapshot)
    (ok (var-set next-buffer-blocks-per-cycle
      updated-buffer-blocks-per-cycle
    ))
  )
)

(define-public (update-bitcoin-blocks-per-year (updated-bitcoin-blocks-per-year uint))
  (begin
    (asserts! (is-eq (var-get admin) contract-caller) ERR_NOT_ADMIN)
    (print {
      bitcoin-block-height: burn-block-height,
      cycle-id: (var-get cycle-id),
      bitcoin-blocks-per-year: updated-bitcoin-blocks-per-year,
      function-name: "update-bitcoin-blocks-per-year",
    })
    (ok (var-set bitcoin-blocks-per-year updated-bitcoin-blocks-per-year))
  )
)

(define-public (update-apr (new-apr-scaled uint))
  (begin
    (asserts! (is-eq (var-get admin) contract-caller) ERR_NOT_ADMIN)
    (asserts! (>= new-apr-scaled MIN_APR_SCALED) ERR_APR_TOO_LOW)
    (asserts! (<= new-apr-scaled MAX_APR_SCALED) ERR_APR_TOO_HIGH)
    (ok (var-set annual-percentage-rate new-apr-scaled))
  )
)

(define-public (update-yield-boost-multiplier (new-multiplier uint))
  (begin
    (asserts! (is-eq (var-get admin) contract-caller) ERR_NOT_ADMIN)
    (asserts! (>= new-multiplier u1) ERR_MULTIPLIER_TOO_LOW)
    (asserts! (<= new-multiplier u20) ERR_MULTIPLIER_TOO_HIGH)
    (print {
      bitcoin-block-height: burn-block-height,
      yield-boost-multiplier: new-multiplier,
      max-boost: (+ new-multiplier u1),
      cycle-id: (var-get cycle-id),
      function-name: "update-yield-boost-multiplier",
    })
    (ok (var-set yield-boost-multiplier new-multiplier))
  )
)

(define-public (emergency-withdraw-sbtc
    (amount uint)
    (recipient principal)
  )
  (begin
    (asserts! (is-eq contract-caller (var-get admin)) ERR_NOT_ADMIN)
    (asserts! (> amount u0) ERR_INSUFFICIENT_FUNDS)
    (let ((contract-balance (get-wallet-sbtc-balance current-contract)))
      (asserts! (>= contract-balance amount) ERR_INSUFFICIENT_FUNDS)
      (print {
        bitcoin-block-height: burn-block-height,
        cycle-id: (var-get cycle-id),
        amount: amount,
        recipient: recipient,
        contract-balance: contract-balance,
        function-name: "emergency-withdraw-sbtc",
      })
      (try! (transfer-sbtc-from-contract amount recipient))
      (ok true)
    )
  )
)

(define-read-only (is-defi-protocol-healthy
    (defi-name uint)
    (check-cycle uint)
    (check-snapshot uint)
  )
  (let ((status (map-get? compromised-defi-protocol { defi-name: defi-name })))
    (if (is-none status)
      true
      (let (
          (status-data (unwrap-panic status))
          (compromised-cycle (get compromised-at-cycle status-data))
          (compromised-snapshot (get compromised-at-snapshot status-data))
        )
        (or
          (> compromised-cycle check-cycle)
          (and
            (is-eq compromised-cycle check-cycle)
            (> compromised-snapshot check-snapshot)
          )
        )
      )
    )
  )
)

(define-public (mark-defi-compromised
    (defi-name uint)
    (first-compromised-snapshot uint)
  )
  (begin
    (asserts! (is-eq contract-caller (var-get admin)) ERR_NOT_ADMIN)
    (print {
      bitcoin-block-height: burn-block-height,
      cycle-id: (var-get cycle-id),
      defi-name: defi-name,
      compromised-at-snapshot: first-compromised-snapshot,
      function-name: "mark-defi-compromised",
    })
    (ok (map-set compromised-defi-protocol { defi-name: defi-name } {
      compromised-at-cycle: (var-get cycle-id),
      compromised-at-snapshot: first-compromised-snapshot,
    }))
  )
)

(define-public (restore-defi-protocol (defi-name uint))
  (begin
    (asserts! (is-eq contract-caller (var-get admin)) ERR_NOT_ADMIN)
    (asserts!
      (is-some (map-get? compromised-defi-protocol { defi-name: defi-name }))
      ERR_DEFI_NOT_COMPROMISED
    )
    (print {
      bitcoin-block-height: burn-block-height,
      cycle-id: (var-get cycle-id),
      defi-name: defi-name,
      function-name: "restore-defi-protocol",
    })
    (ok (map-delete compromised-defi-protocol { defi-name: defi-name }))
  )
)

(define-public (trigger-full-cycle-rollback)
  (begin
    (asserts! (is-eq contract-caller (var-get admin)) ERR_NOT_ADMIN)
    (asserts!
      (is-none (map-get? cycle-finalization-block-heights { cycle-id: (var-get cycle-id) }))
      ERR_CANNOT_ROLLBACK_FINALIZED_CYCLE
    )

    (var-set current-cycle-rollback-id
      (+ (var-get current-cycle-rollback-id) u1)
    )

    (var-set current-snapshot-index u0)
    (var-set current-snapshot-count u0)
    (var-set current-snapshot-total-sbtc u0)
    (var-set current-snapshot-total-sbtc-in-defis u0)
    (var-set current-snapshot-total-stx u0)
    (var-set current-cycle-total-sbtc-in-wallet u0)
    (var-set current-cycle-total-sbtc-in-defis u0)
    (var-set current-cycle-total-stx u0)
    (var-set last-operation-done u0)
    (var-set are-snapshots-finalized false)
    (var-set is-buffer-set false)
    (var-set is-ratio-validated false)
    (var-set are-weights-computed false)
    (var-set is-distribution-enabled false)
    (var-set total-weights-sum u0)
    (var-set weights-computed-count u0)
    (var-set participants-rewarded-count u0)

    (var-set current-snapshot-bitcoin-block-height
      (var-get current-cycle-bitcoin-block-height)
    )
    (var-set current-snapshot-stacks-block-height
      (var-get current-cycle-stacks-block-height)
    )

    (map-set snapshot-aggregate-data {
      cycle-id: (var-get cycle-id),
      rollback-id: (var-get current-cycle-rollback-id),
      snapshot-index: u0,
    } {
      stacks-block-height: (var-get current-cycle-stacks-block-height),
      bitcoin-block-height: (var-get current-cycle-bitcoin-block-height),
      total-sbtc-wallet: u0,
      total-sbtc-defi: u0,
      total-stx-stacked: u0,
    })

    (print {
      bitcoin-block-height: burn-block-height,
      cycle-id: (var-get cycle-id),
      rollback-id: (var-get current-cycle-rollback-id),
      function-name: "trigger-full-cycle-rollback",
    })
    (ok true)
  )
)

(define-public (capture-snapshot-balances (principals (list 900 principal)))
  (let ((stx-id-header-hash (unwrap!
      (get-stacks-block-info? id-header-hash
        (var-get current-snapshot-stacks-block-height)
      )
      ERR_STX_BLOCK_IN_FUTURE
    )))
    (asserts! (var-get is-contract-active) ERR_CONTRACT_NOT_ACTIVE)
    (var-set snapshot-block-hash stx-id-header-hash)
    (map capture-participant-balances principals)
    (ok true)
  )
)

(define-private (capture-participant-balances (enrolled-address principal))
  (let (
      (cycle-id-current (var-get cycle-id))
      (current-snapshot-index-value (var-get current-snapshot-index))
      (arkadiko (is-defi-protocol-healthy ARKADIKO cycle-id-current
        current-snapshot-index-value
      ))
      (based-dollar (is-defi-protocol-healthy BASED_DOLLAR cycle-id-current
        current-snapshot-index-value
      ))
      (bitflow (is-defi-protocol-healthy BITFLOW cycle-id-current
        current-snapshot-index-value
      ))
      (granite (is-defi-protocol-healthy GRANITE cycle-id-current
        current-snapshot-index-value
      ))
      (velar (is-defi-protocol-healthy VELAR cycle-id-current
        current-snapshot-index-value
      ))
      (zest (is-defi-protocol-healthy ZEST cycle-id-current
        current-snapshot-index-value
      ))
    )
    (capture-participant-snapshot enrolled-address arkadiko
      based-dollar bitflow granite velar zest
    )
  )
)

(define-public (capture-snapshot-balances-optimizer (principals (list
  900
  {
    address: principal,
    arkadiko: bool,
    based-dollar: bool,
    bitflow: bool,
    granite: bool,
    velar: bool,
    zest: bool,
  }
)))
  (let ((stx-id-header-hash (unwrap!
      (get-stacks-block-info? id-header-hash
        (var-get current-snapshot-stacks-block-height)
      )
      ERR_STX_BLOCK_IN_FUTURE
    )))
    (asserts! (var-get is-contract-active) ERR_CONTRACT_NOT_ACTIVE)
    (asserts!
      (is-some (map-get? optimized-snapshot-operators { operator-address: contract-caller }))
      ERR_NOT_OPTIMIZED_OPERATOR
    )
    (var-set snapshot-block-hash stx-id-header-hash)
    (map capture-participant-balances-optimizer principals)
    (ok true)
  )
)

(define-private (capture-participant-balances-optimizer (user {
  address: principal,
  arkadiko: bool,
  based-dollar: bool,
  bitflow: bool,
  granite: bool,
  velar: bool,
  zest: bool,
}))
  (let (
      (enrolled-address (get address user))
      (cycle-id-current (var-get cycle-id))
      (current-snapshot-index-value (var-get current-snapshot-index))
      (arkadiko (and (get arkadiko user) (is-defi-protocol-healthy ARKADIKO cycle-id-current
        current-snapshot-index-value
      )))
      (based-dollar (and (get based-dollar user) (is-defi-protocol-healthy BASED_DOLLAR cycle-id-current
        current-snapshot-index-value
      )))
      (bitflow (and (get bitflow user) (is-defi-protocol-healthy BITFLOW cycle-id-current
        current-snapshot-index-value
      )))
      (granite (and (get granite user) (is-defi-protocol-healthy GRANITE cycle-id-current
        current-snapshot-index-value
      )))
      (velar (and (get velar user) (is-defi-protocol-healthy VELAR cycle-id-current
        current-snapshot-index-value
      )))
      (zest (and (get zest user) (is-defi-protocol-healthy ZEST cycle-id-current
        current-snapshot-index-value
      )))
    )
    (capture-participant-snapshot enrolled-address arkadiko
      based-dollar bitflow granite velar zest
    )
  )
)

(define-private (capture-participant-snapshot
    (enrolled-address principal)
    (arkadiko bool)
    (based-dollar bool)
    (bitflow bool)
    (granite bool)
    (velar bool)
    (zest bool)
  )
  (let (
      (cycle-id-current (var-get cycle-id))
      (current-snapshot-index-value (var-get current-snapshot-index))
      (rollback-id-current (var-get current-cycle-rollback-id))
      (participant-data (at-block (var-get current-cycle-stacks-block-hash)
        (map-get? participants { address: enrolled-address })
      ))
      (participant-holding-data (map-get? participant-holdings-per-cycle {
        cycle-id: cycle-id-current,
        rollback-id: rollback-id-current,
        participant-address: enrolled-address,
      }))
      (sbtc-wallet-balance (at-block (var-get snapshot-block-hash)
        (get-wallet-sbtc-balance enrolled-address)
      ))
      (sbtc-defi-balances (at-block (var-get snapshot-block-hash)
        (get-defi-sbtc-balance {
          address: enrolled-address,
          arkadiko: arkadiko,
          based-dollar: based-dollar,
          bitflow: bitflow,
          granite: granite,
          velar: velar,
          zest: zest,
        })
      ))
      (sbtc-arkadiko-amount (get arkadiko sbtc-defi-balances))
      (sbtc-based-dollar-amount (get based-dollar sbtc-defi-balances))
      (sbtc-bitflow-amount (get bitflow sbtc-defi-balances))
      (sbtc-granite-amount (get granite sbtc-defi-balances))
      (sbtc-velar-amount (get velar sbtc-defi-balances))
      (sbtc-zest-amount (get zest sbtc-defi-balances))
      (sbtc-total-defi-amount (get total sbtc-defi-balances))
    )
    (if (or
        (is-none participant-data)
        (and (is-some participant-data) (is-eq
          (default-to SNAPSHOT_NOT_TAKEN_MARKER
            (get last-snapshot-index participant-holding-data)
          )
          current-snapshot-index-value
        ))
      )
      true
      (let (
          (participant-stacking-address (unwrap-panic (get stacking-address participant-data)))
          (stacking-holding-data (map-get? stx-stacked-by-stacking-address {
            cycle-id: cycle-id-current,
            rollback-id: rollback-id-current,
            stacking-address: participant-stacking-address,
          }))
          (participant-tracking-address (unwrap-panic (get tracking-address participant-data)))
          (tracking-holding-data (map-get? sbtc-holdings-by-tracking-address {
            cycle-id: cycle-id-current,
            rollback-id: rollback-id-current,
            tracking-address: participant-tracking-address,
          }))
          (stx-stacked-amount (get-amount-stacked-at-block-height
            participant-stacking-address
            (var-get current-snapshot-stacks-block-height)
          ))
        )
        (var-set current-snapshot-total-sbtc
          (+ (var-get current-snapshot-total-sbtc) sbtc-wallet-balance)
        )
        (var-set current-snapshot-count
          (+ (var-get current-snapshot-count) u1)
        )
        (var-set current-snapshot-total-stx
          (+ (var-get current-snapshot-total-stx) stx-stacked-amount)
        )
        (map-set participant-holdings-per-cycle {
          cycle-id: cycle-id-current,
          rollback-id: rollback-id-current,
          participant-address: enrolled-address,
        } {
          sbtc-wallet-amount: (+ sbtc-wallet-balance
            (default-to u0
              (get sbtc-wallet-amount participant-holding-data)
            )),
          sbtc-defi-amount: (+ sbtc-total-defi-amount
            (default-to u0
              (get sbtc-defi-amount participant-holding-data)
            )),
          stx-stacked-amount: (+ stx-stacked-amount
            (default-to u0
              (get stx-stacked-amount participant-holding-data)
            )),
          last-snapshot-index: current-snapshot-index-value,
          has-been-rewarded: false,
          reward-amount: u0,
        })
        (map-set sbtc-holdings-by-tracking-address {
          cycle-id: cycle-id-current,
          rollback-id: rollback-id-current,
          tracking-address: participant-tracking-address,
        } {
          sbtc-wallet-amount: (+ sbtc-wallet-balance
            (default-to u0
              (get sbtc-wallet-amount tracking-holding-data)
            )),
          sbtc-defi-amount: (+ sbtc-total-defi-amount
            (default-to u0 (get sbtc-defi-amount tracking-holding-data))
          ),
          has-been-rewarded: false,
        })
        (if (is-some (map-get? snapshot-processed-stacking-addresses {
            cycle-id: cycle-id-current,
            rollback-id: rollback-id-current,
            snapshot-index: current-snapshot-index-value,
            stacking-address: participant-stacking-address,
          }))
          true
          (begin
            (map-set stx-stacked-by-stacking-address {
              cycle-id: cycle-id-current,
              rollback-id: rollback-id-current,
              stacking-address: participant-stacking-address,
            } { stx-amount: (+ stx-stacked-amount
              (default-to u0 (get stx-amount stacking-holding-data))
            ) }
            )
            (map-set snapshot-processed-stacking-addresses {
              cycle-id: cycle-id-current,
              rollback-id: rollback-id-current,
              snapshot-index: current-snapshot-index-value,
              stacking-address: participant-stacking-address,
            } { has-been-processed: true }
            )
          )
        )
        (var-set current-snapshot-total-sbtc-in-defis
          (+ (var-get current-snapshot-total-sbtc-in-defis)
            sbtc-total-defi-amount
          ))
        (print {
          cycle-id: cycle-id-current,
          snapshot-index: current-snapshot-index-value,
          rollback-id: rollback-id-current,
          enrolled-address: enrolled-address,
          tracking-address: participant-tracking-address,
          stacking-address: participant-stacking-address,
          sbtc-wallet-balance: sbtc-wallet-balance,
          sbtc-total-defi-balance: sbtc-total-defi-amount,
          sbtc-arkadiko: sbtc-arkadiko-amount,
          sbtc-based-dollar: sbtc-based-dollar-amount,
          sbtc-bitflow: sbtc-bitflow-amount,
          sbtc-granite: sbtc-granite-amount,
          sbtc-velar: sbtc-velar-amount,
          sbtc-zest: sbtc-zest-amount,
          stx-stacked: stx-stacked-amount,
          function-name: "compute-current-snapshot-balance",
        })
        true
      )
    )
  )
)

(define-public (advance-to-next-snapshot (new-stx-block-height uint))
  (let ((next-snapshot-bitcoin-block-height (+ (var-get current-snapshot-bitcoin-block-height)
      (var-get blocks-per-snapshot)
    )))
    (asserts! (var-get is-contract-active) ERR_CONTRACT_NOT_ACTIVE)
    (asserts! (>= burn-block-height next-snapshot-bitcoin-block-height)
      ERR_NOT_NEW_SNAPSHOT_YET
    )
    (asserts!
      (is-eq (var-get current-snapshot-count)
        (var-get current-cycle-participants-count)
      )
      ERR_NOT_SNAPSHOTTED_ALL_PARTICIPANTS
    )
    (asserts!
      (not (is-eq (var-get snapshots-per-cycle)
        (+ (var-get current-snapshot-index) u1)
      ))
      ERR_CYCLE_ENDED
    )
    (asserts!
      (< next-snapshot-bitcoin-block-height
        (var-get next-cycle-bitcoin-block-height)
      )
      ERR_CYCLE_ENDED_2
    )
    (asserts!
      (unwrap-panic (validate-bitcoin-block new-stx-block-height
        next-snapshot-bitcoin-block-height
      ))
      ERR_STX_BLOCK_NOT_MATCHING
    )

    (var-set current-snapshot-bitcoin-block-height
      next-snapshot-bitcoin-block-height
    )
    (var-set current-cycle-total-sbtc-in-wallet
      (+ (var-get current-cycle-total-sbtc-in-wallet)
        (var-get current-snapshot-total-sbtc)
      ))
    (var-set current-cycle-total-sbtc-in-defis
      (+ (var-get current-cycle-total-sbtc-in-defis)
        (var-get current-snapshot-total-sbtc-in-defis)
      ))
    (var-set current-cycle-total-stx
      (+ (var-get current-cycle-total-stx)
        (var-get current-snapshot-total-stx)
      ))
    (map-set snapshot-aggregate-data {
      cycle-id: (var-get cycle-id),
      rollback-id: (var-get current-cycle-rollback-id),
      snapshot-index: (var-get current-snapshot-index),
    }
      (merge
        (unwrap-panic (map-get? snapshot-aggregate-data {
          cycle-id: (var-get cycle-id),
          rollback-id: (var-get current-cycle-rollback-id),
          snapshot-index: (var-get current-snapshot-index),
        })) {
        total-sbtc-wallet: (var-get current-cycle-total-sbtc-in-wallet),
        total-sbtc-defi: (var-get current-cycle-total-sbtc-in-defis),
        total-stx-stacked: (var-get current-cycle-total-stx),
      })
    )
    (var-set current-snapshot-total-sbtc u0)
    (var-set current-snapshot-total-sbtc-in-defis u0)
    (var-set current-snapshot-total-stx u0)
    (var-set current-snapshot-count u0)
    (var-set current-snapshot-index
      (+ (var-get current-snapshot-index) u1)
    )
    (map-set snapshot-aggregate-data {
      cycle-id: (var-get cycle-id),
      rollback-id: (var-get current-cycle-rollback-id),
      snapshot-index: (var-get current-snapshot-index),
    } {
      stacks-block-height: new-stx-block-height,
      bitcoin-block-height: next-snapshot-bitcoin-block-height,
      total-sbtc-wallet: u0,
      total-sbtc-defi: u0,
      total-stx-stacked: u0,
    })
    (ok (var-set current-snapshot-stacks-block-height new-stx-block-height))
  )
)

(define-public (start-buffer-period)
  (begin
    (asserts! (var-get is-contract-active) ERR_CONTRACT_NOT_ACTIVE)
    (asserts! (not (var-get is-buffer-set)) ERR_BUFFER_ALREADY_SET)
    (asserts!
      (is-eq (+ (var-get current-snapshot-index) u1)
        (var-get snapshots-per-cycle)
      )
      ERR_NOT_ALL_SNAPSHOTS
    )
    (asserts!
      (is-eq (var-get current-snapshot-count)
        (var-get current-cycle-participants-count)
      )
      ERR_NOT_SNAPSHOTTED_ALL_PARTICIPANTS
    )
    (var-set is-buffer-set true)
    (var-set current-cycle-total-sbtc-in-wallet
      (+ (var-get current-cycle-total-sbtc-in-wallet)
        (var-get current-snapshot-total-sbtc)
      ))
    (var-set current-cycle-total-sbtc-in-defis
      (+ (var-get current-cycle-total-sbtc-in-defis)
        (var-get current-snapshot-total-sbtc-in-defis)
      ))
    (var-set current-cycle-total-stx
      (+ (var-get current-cycle-total-stx)
        (var-get current-snapshot-total-stx)
      ))
    (map-set snapshot-aggregate-data {
      cycle-id: (var-get cycle-id),
      rollback-id: (var-get current-cycle-rollback-id),
      snapshot-index: (var-get current-snapshot-index),
    }
      (merge
        (unwrap-panic (map-get? snapshot-aggregate-data {
          cycle-id: (var-get cycle-id),
          rollback-id: (var-get current-cycle-rollback-id),
          snapshot-index: (var-get current-snapshot-index),
        })) {
        total-sbtc-wallet: (var-get current-cycle-total-sbtc-in-wallet),
        total-sbtc-defi: (var-get current-cycle-total-sbtc-in-defis),
        total-stx-stacked: (var-get current-cycle-total-stx),
      })
    )
    (print {
      cycle-id: (var-get cycle-id),
      current-cycle-total-sbtc-in-wallet: (var-get current-cycle-total-sbtc-in-wallet),
      current-cycle-total-sbtc-in-defis: (var-get current-cycle-total-sbtc-in-defis),
      current-cycle-total-stx: (var-get current-cycle-total-stx),
      function-name: "conclude-cycle-snapshots",
    })
    (var-set last-operation-done u1)
    (ok true)
  )
)

(define-public (finalize-snapshots)
  (begin
    (asserts! (var-get is-contract-active) ERR_CONTRACT_NOT_ACTIVE)
    (asserts! (not (var-get are-snapshots-finalized))
      ERR_SNAPSHOTS_ALREADY_CONCLUDED
    )
    (asserts! (var-get is-buffer-set) ERR_BUFFER_NOT_ACTIVATED)
    (asserts!
      (>= burn-block-height
        (+ (var-get buffer-period-start-block)
          (var-get buffer-blocks-per-cycle)
        ))
      ERR_BUFFER_PERIOD_NOT_PASSED
    )
    (var-set last-operation-done u2)
    (ok (var-set are-snapshots-finalized true))
  )
)

(define-public (propose-golden-ratio (ratio uint))
  (let (
      (cycle-id-current (var-get cycle-id))
      (rollback-id-current (var-get current-cycle-rollback-id))
    )
    (asserts! (var-get are-snapshots-finalized)
      ERR_SNAPSHOTS_NOT_CONCLUDED
    )
    (asserts!
      (is-none (map-get? validated-golden-ratio-per-cycle { cycle-id: cycle-id-current }))
      ERR_ALREADY_VALIDATED_RATIO
    )
    (asserts!
      (is-none (map-get? golden-ratio-proposals {
        cycle-id: cycle-id-current,
        proposer-address: contract-caller,
      }))
      ERR_ALREADY_PROPOSED_RATIO
    )
    (map-set golden-ratio-proposals {
      cycle-id: cycle-id-current,
      proposer-address: contract-caller,
    } {
      proposed-golden-ratio: ratio,
      participants-tallied: u0,
      sbtc-below-ratio: u0,
      sbtc-above-ratio: u0,
      sbtc-equal-ratio: u0,
    })
    (print {
      cycle-id: cycle-id-current,
      proposed-address: contract-caller,
      function-name: "propose-golden-ratio",
    })
    (ok true)
  )
)

(define-public (change-proposed-golden-ratio (ratio uint))
  (let (
      (cycle-id-current (var-get cycle-id))
      (rollback-id-current (var-get current-cycle-rollback-id))
    )
    (asserts!
      (is-some (map-get? golden-ratio-proposals {
        cycle-id: cycle-id-current,
        proposer-address: contract-caller,
      }))
      ERR_RATIO_NOT_PROPOSED
    )
    (asserts!
      (is-none (map-get? validated-golden-ratio-per-cycle { cycle-id: cycle-id-current }))
      ERR_ALREADY_VALIDATED_RATIO
    )
    (map-set golden-ratio-proposals {
      cycle-id: cycle-id-current,
      proposer-address: contract-caller,
    } {
      proposed-golden-ratio: ratio,
      participants-tallied: u0,
      sbtc-below-ratio: u0,
      sbtc-above-ratio: u0,
      sbtc-equal-ratio: u0,
    })
    (ok true)
  )
)

(define-public (tally-participant-ratios (principals (list 900 principal)))
  (let (
      (cycle-id-current (var-get cycle-id))
      (rollback-id-current (var-get current-cycle-rollback-id))
      (golden-ratio-proposals-map (unwrap!
        (map-get? golden-ratio-proposals {
          cycle-id: cycle-id-current,
          proposer-address: contract-caller,
        })
        ERR_RATIO_NOT_PROPOSED
      ))
      (golden-ratio (get proposed-golden-ratio golden-ratio-proposals-map))
      (participants-count (get participants-tallied golden-ratio-proposals-map))
    )
    (asserts!
      (is-none (map-get? validated-golden-ratio-per-cycle { cycle-id: cycle-id-current }))
      ERR_ALREADY_VALIDATED_RATIO
    )
    (asserts!
      (< participants-count (var-get current-cycle-participants-count))
      ERR_COMPUTED_RATIO_ALL_PARTICIPANTS
    )
    (var-set ratio-being-tallied golden-ratio)
    (map tally-user-ratio principals)
    (ok true)
  )
)

(define-private (tally-user-ratio (address principal))
  (let (
      (current-cycle-id (var-get cycle-id))
      (current-rollback-id (var-get current-cycle-rollback-id))
      (participant-state (unwrap-panic (at-block (var-get current-cycle-stacks-block-hash)
        (map-get? participants { address: address })
      )))
      (stacking-address (get stacking-address participant-state))
      (stacking-state (unwrap-panic (map-get? stx-stacked-by-stacking-address {
        stacking-address: stacking-address,
        cycle-id: current-cycle-id,
        rollback-id: current-rollback-id,
      })))
      (stx-user-amount (get stx-amount stacking-state))
      (tracking-address (get tracking-address participant-state))
      (tracking-state (unwrap-panic (map-get? sbtc-holdings-by-tracking-address {
        tracking-address: tracking-address,
        cycle-id: current-cycle-id,
        rollback-id: current-rollback-id,
      })))
      (sbtc-user-amount (get sbtc-wallet-amount tracking-state))
      (sbtc-user-amount-defis (get sbtc-defi-amount tracking-state))
      (current-golden-ratio-proposals (var-get ratio-being-tallied))
      (golden-ratio-proposals-map (unwrap-panic (map-get? golden-ratio-proposals {
        cycle-id: current-cycle-id,
        proposer-address: contract-caller,
      })))
      (proposed-participants-counted (get participants-tallied golden-ratio-proposals-map))
    )
    (if (is-some (map-get? participant-ratio-computation-status {
        cycle-id: current-cycle-id,
        proposer-address: contract-caller,
        ratio-value: current-golden-ratio-proposals,
        participant-address: address,
      }))
      true
      (begin
        (print {
          cycle-id: current-cycle-id,
          enrolled-address: address,
          stacking-address: stacking-address,
          tracking-address: tracking-address,
          function-name: "count-golden-ratio",
          stx-user-amount: stx-user-amount,
          sbtc-user-amount: sbtc-user-amount,
          sbtc-user-amount-defis: sbtc-user-amount-defis,
          reward-mechanism: (var-get reward-calculation-mechanism),
          contract-caller: contract-caller,
        })
        (map-set participant-ratio-computation-status {
          cycle-id: current-cycle-id,
          proposer-address: contract-caller,
          ratio-value: current-golden-ratio-proposals,
          participant-address: address,
        } { has-been-computed: true }
        )
        (map-set golden-ratio-proposals {
          cycle-id: current-cycle-id,
          proposer-address: contract-caller,
        }
          (merge golden-ratio-proposals-map { participants-tallied: (+ proposed-participants-counted u1) })
        )
        (if (or
            (is-eq sbtc-user-amount u0)
            (is-some (map-get? tracking-address-ratio-computation-status {
              cycle-id: current-cycle-id,
              proposer-address: contract-caller,
              ratio-value: current-golden-ratio-proposals,
              tracking-address: tracking-address,
            }))
          )
          true
          (let (
              (mechanism (var-get reward-calculation-mechanism))
              (sbtc-for-ratio sbtc-user-amount)
              (golden-ratio-proposals-map-updated (unwrap-panic (map-get? golden-ratio-proposals {
                cycle-id: current-cycle-id,
                proposer-address: contract-caller,
              })))
              (sbtc-below (get sbtc-below-ratio golden-ratio-proposals-map))
              (sbtc-above (get sbtc-above-ratio golden-ratio-proposals-map))
              (sbtc-equal (get sbtc-equal-ratio golden-ratio-proposals-map))
              (user-ratio (/ (* stx-user-amount RATIO_SCALE_FACTOR) sbtc-for-ratio))
            )
            (map-set tracking-address-ratio-computation-status {
              cycle-id: current-cycle-id,
              proposer-address: contract-caller,
              ratio-value: current-golden-ratio-proposals,
              tracking-address: tracking-address,
            } { has-been-computed: true }
            )
            (if (< user-ratio current-golden-ratio-proposals)
              (begin
                (print {
                  user-address: address,
                  user-ratio: user-ratio,
                  action: "below",
                  user-amount: sbtc-for-ratio,
                  mechanism: mechanism,
                })
                (map-set golden-ratio-proposals {
                  cycle-id: current-cycle-id,
                  proposer-address: contract-caller,
                }
                  (merge golden-ratio-proposals-map-updated { sbtc-below-ratio: (+ sbtc-below sbtc-for-ratio) })
                )
              )
              (if (is-eq user-ratio current-golden-ratio-proposals)
                (begin
                  (print {
                    user-address: address,
                    user-ratio: user-ratio,
                    action: "equal",
                    user-amount: sbtc-for-ratio,
                    mechanism: mechanism,
                  })
                  (map-set golden-ratio-proposals {
                    cycle-id: current-cycle-id,
                    proposer-address: contract-caller,
                  }
                    (merge golden-ratio-proposals-map-updated { sbtc-equal-ratio: (+ sbtc-equal sbtc-for-ratio) })
                  )
                )
                (begin
                  (print {
                    user-address: address,
                    user-ratio: user-ratio,
                    action: "above",
                    user-amount: sbtc-for-ratio,
                    mechanism: mechanism,
                  })
                  (map-set golden-ratio-proposals {
                    cycle-id: current-cycle-id,
                    proposer-address: contract-caller,
                  }
                    (merge golden-ratio-proposals-map-updated { sbtc-above-ratio: (+ sbtc-above sbtc-for-ratio) })
                  )
                )
              )
            )
            true
          )
        )
      )
    )
  )
)

(define-public (set-max-percentage-above-golden-ratio (new-max-percentage-above-golden-ratio uint))
  (begin
    (asserts! (is-eq contract-caller (var-get admin)) ERR_NOT_ADMIN)
    (ok (var-set max-percentage-above-golden-ratio
      new-max-percentage-above-golden-ratio
    ))
  )
)

(define-public (validate-ratio)
  (let (
      (cycle-id-current (var-get cycle-id))
      (rollback-id-current (var-get current-cycle-rollback-id))
      (golden-ratio-proposals-map (unwrap!
        (map-get? golden-ratio-proposals {
          cycle-id: cycle-id-current,
          proposer-address: contract-caller,
        })
        ERR_RATIO_NOT_PROPOSED
      ))
      (golden-ratio (get proposed-golden-ratio golden-ratio-proposals-map))
      (participants-count (get participants-tallied golden-ratio-proposals-map))
      (sbtc-below (get sbtc-below-ratio golden-ratio-proposals-map))
      (sbtc-above (get sbtc-above-ratio golden-ratio-proposals-map))
      (sbtc-equal (get sbtc-equal-ratio golden-ratio-proposals-map))
      (max-sbtc-allowed-above-ratio (/
        (* (var-get max-percentage-above-golden-ratio)
          (var-get current-cycle-total-sbtc-in-wallet)
        )
        PERCENTAGE_PRECISION_FACTOR
      ))
      (is-above-within-threshold (<= (* u100 sbtc-above) max-sbtc-allowed-above-ratio))
      (is-above-plus-equal-within-threshold (>= (* u100 (+ sbtc-above sbtc-equal))
        max-sbtc-allowed-above-ratio
      ))
      (total-stx (var-get current-cycle-total-stx))
      (all-stx-is-zero (is-eq total-stx u0))
    )
    (print {
      sbtc-above: sbtc-above,
      sbtc-below: sbtc-below,
      sbtc-equal: sbtc-equal,
      sbtc-total: (+ (var-get current-cycle-total-sbtc-in-wallet)
        (var-get current-cycle-total-sbtc-in-defis)
      ),
    })
    (asserts!
      (is-none (map-get? validated-golden-ratio-per-cycle { cycle-id: cycle-id-current }))
      ERR_ALREADY_VALIDATED_RATIO
    )
    (asserts!
      (is-eq participants-count
        (var-get current-cycle-participants-count)
      )
      ERR_COMPUTE_RATIO_FOR_ALL_PARTICIPANTS_FIRST
    )

    (asserts!
      (or (not all-stx-is-zero) (is-eq golden-ratio RATIO_SCALE_FACTOR))
      ERR_INVALID_RATIO_FOR_ZERO_STX
    )

    (if (not all-stx-is-zero)
      (begin
        (asserts! is-above-within-threshold ERR_RATIO_TOO_LOW)
        (asserts! is-above-plus-equal-within-threshold
          ERR_RATIO_TOO_HIGH
        )
        false
      )
      false
    )

    (var-set is-ratio-validated true)
    (map-set validated-golden-ratio-per-cycle { cycle-id: cycle-id-current } { golden-ratio: golden-ratio })
    (var-set last-operation-done u3)
    (ok true)
  )
)

(define-read-only (get-ratio-data)
  (let (
      (cycle-id-current (var-get cycle-id))
      (golden-ratio-proposals-map (unwrap!
        (map-get? golden-ratio-proposals {
          cycle-id: cycle-id-current,
          proposer-address: contract-caller,
        })
        ERR_RATIO_NOT_PROPOSED
      ))
    )
    (ok {
      sbtc-total-totals: (+ (var-get current-cycle-total-sbtc-in-wallet)
        (var-get current-cycle-total-sbtc-in-defis)
      ),
      nr-snapshots: (var-get snapshots-per-cycle),
      sbtc-below: (get sbtc-below-ratio golden-ratio-proposals-map),
      sbtc-above: (get sbtc-above-ratio golden-ratio-proposals-map),
    })
  )
)

(define-public (calculate-participant-weights (principals (list 900 principal)))
  (begin
    (asserts! (var-get is-ratio-validated) ERR_RATIOS_NOT_CONCLUDED)
    (ok (map calculate-participant-weight principals))
  )
)

(define-private (calculate-participant-weight (enrolled-address principal))
  (let (
      (cycle-id-current (var-get cycle-id))
      (rollback-id-current (var-get current-cycle-rollback-id))
      (participant-state (unwrap-panic (at-block (var-get current-cycle-stacks-block-hash)
        (map-get? participants { address: enrolled-address })
      )))
      (participant-stacking-address (get stacking-address participant-state))
      (participant-tracking-address (get tracking-address participant-state))
      (stacking-state (unwrap-panic (map-get? stx-stacked-by-stacking-address {
        stacking-address: participant-stacking-address,
        cycle-id: cycle-id-current,
        rollback-id: rollback-id-current,
      })))
      (tracking-state (unwrap-panic (map-get? sbtc-holdings-by-tracking-address {
        tracking-address: participant-tracking-address,
        cycle-id: cycle-id-current,
        rollback-id: rollback-id-current,
      })))
      (stx-stacked-amount (get stx-amount stacking-state))
      (sbtc-wallet-amount (get sbtc-wallet-amount tracking-state))
      (sbtc-defi-amount (get sbtc-defi-amount tracking-state))
      (boost-multiplier (var-get yield-boost-multiplier))
      (golden-ratio-data (unwrap-panic (map-get? validated-golden-ratio-per-cycle { cycle-id: cycle-id-current })))
      (D-raw (get golden-ratio golden-ratio-data))
      (golden-ratio (if (> D-raw u0)
        D-raw
        MIN_GOLDEN_RATIO
      ))
    )
    (if (is-some (map-get? participant-weight-computation-status {
        cycle-id: cycle-id-current,
        participant-address: enrolled-address,
      }))
      true
      (if (is-some (map-get? participant-weights-by-tracking-address {
          cycle-id: cycle-id-current,
          tracking-address: participant-tracking-address,
        }))
        (begin
          (map-set participant-weight-computation-status {
            cycle-id: cycle-id-current,
            participant-address: enrolled-address,
          } { has-been-computed: true }
          )
          (var-set weights-computed-count
            (+ (var-get weights-computed-count) u1)
          )
          (print {
            cycle-id: cycle-id-current,
            enrolled-address: enrolled-address,
            tracking-address: participant-tracking-address,
            sbtc-wallet-amount: sbtc-wallet-amount,
            sbtc-defi-amount: sbtc-defi-amount,
            stx-stacked-amount: stx-stacked-amount,
            golden-ratio: golden-ratio,
            note: "weight-already-exists",
            function-name: "compute-weight",
          })
          true
        )
        (let (
            (mechanism (var-get reward-calculation-mechanism))
            (snapshots-count (var-get snapshots-per-cycle))
            (weight-data (let (
                (user-ratio-wallet (if (> sbtc-wallet-amount u0)
                  (/ (* stx-stacked-amount RATIO_SCALE_FACTOR)
                    sbtc-wallet-amount
                  )
                  u0
                ))
                (boost-ratio-wallet (if (is-eq sbtc-wallet-amount u0)
                  u0
                  (if (< golden-ratio MIN_GOLDEN_RATIO)
                    u0
                    (if (> user-ratio-wallet golden-ratio)
                      RATIO_SCALE_FACTOR
                      (/ (* user-ratio-wallet RATIO_SCALE_FACTOR)
                        golden-ratio
                      )
                    )
                  )
                ))
                (boost-ratio-defi (if (is-eq sbtc-defi-amount u0)
                  u0
                  RATIO_SCALE_FACTOR
                ))
                (sqrt-boost-ratio-wallet (sqrti boost-ratio-wallet))
                (sqrt-boost-ratio-defi (sqrti boost-ratio-defi))
                (w-wallet (if (is-eq sbtc-wallet-amount u0)
                  u0
                  (/
                    (* sbtc-wallet-amount
                      (+ RATIO_SCALE_FACTOR
                        (* boost-multiplier sqrt-boost-ratio-wallet
                          SQRT_RATIO_SCALE_FACTOR
                        ))
                    )
                    (* RATIO_SCALE_FACTOR snapshots-count)
                  )
                ))
                (w-defi (if (is-eq sbtc-defi-amount u0)
                  u0
                  (/
                    (* sbtc-defi-amount
                      (+ RATIO_SCALE_FACTOR
                        (* boost-multiplier sqrt-boost-ratio-defi
                          SQRT_RATIO_SCALE_FACTOR
                        ))
                    )
                    (* RATIO_SCALE_FACTOR snapshots-count)
                  )
                ))
              )
              {
                user-ratio-wallet: user-ratio-wallet,
                boost-ratio-wallet: boost-ratio-wallet,
                boost-ratio-defi: boost-ratio-defi,
                weight-wallet: w-wallet,
                weight-defi: w-defi,
              }
            ))
            (user-ratio-wallet (get user-ratio-wallet weight-data))
            (boost-ratio-wallet (get boost-ratio-wallet weight-data))
            (boost-ratio-defi (get boost-ratio-defi weight-data))
            (weight-wallet (get weight-wallet weight-data))
            (weight-defi (get weight-defi weight-data))
            (total-weight (+ weight-wallet weight-defi))
          )
          (map-set participant-weights-by-tracking-address {
            cycle-id: cycle-id-current,
            tracking-address: participant-tracking-address,
          } {
            weight-wallet: weight-wallet,
            weight-defi: weight-defi,
            weight-total: total-weight,
          })
          (map-set participant-weight-computation-status {
            cycle-id: cycle-id-current,
            participant-address: enrolled-address,
          } { has-been-computed: true }
          )
          (var-set weights-computed-count
            (+ (var-get weights-computed-count) u1)
          )
          (print {
            cycle-id: cycle-id-current,
            enrolled-address: enrolled-address,
            tracking-address: participant-tracking-address,
            stx-stacked-amount: stx-stacked-amount,
            sbtc-wallet-amount: sbtc-wallet-amount,
            sbtc-defi-amount: sbtc-defi-amount,
            user-ratio-wallet: user-ratio-wallet,
            golden-ratio: golden-ratio,
            boost-ratio-wallet: boost-ratio-wallet,
            boost-ratio-defi: boost-ratio-defi,
            weight-wallet: weight-wallet,
            weight-defi: weight-defi,
            total-weight: total-weight,
            reward-mechanism: (var-get reward-calculation-mechanism),
            defi-multiplier: DECIMAL_PRECISION_8,
            function-name: "compute-weight",
          })
          (var-set total-weights-sum
            (+ (var-get total-weights-sum) total-weight)
          )
          true
        )
      )
    )
  )
)

(define-public (finalize-weight-computation)
  (let ((cycle-id-current (var-get cycle-id)))
    (asserts! (var-get is-ratio-validated) ERR_RATIOS_NOT_CONCLUDED)
    (asserts! (not (var-get are-weights-computed))
      ERR_WEIGHTS_ALREADY_COMPUTED
    )
    (asserts!
      (is-eq (var-get weights-computed-count)
        (var-get current-cycle-participants-count)
      )
      ERR_NOT_ALL_WEIGHTS_COMPUTED
    )
    (var-set are-weights-computed true)
    (print {
      cycle-id: cycle-id-current,
      total-weights-sum: (var-get total-weights-sum),
      function-name: "finalize-weights",
    })
    (var-set last-operation-done u4)
    (ok true)
  )
)

(define-read-only (get-weight-computation-status)
  {
    are-weights-computed: (var-get are-weights-computed),
    total-weights-sum: (var-get total-weights-sum),
    cycle-id: (var-get cycle-id),
  }
)

(define-read-only (get-participant-weight
    (cycle uint)
    (tracking-addr principal)
  )
  (map-get? participant-weights-by-tracking-address {
    cycle-id: cycle,
    tracking-address: tracking-addr,
  })
)

(define-public (set-is-distribution-enabled)
  (begin
    (asserts! (var-get is-contract-active) ERR_CONTRACT_NOT_ACTIVE)
    (asserts! (not (var-get is-distribution-enabled))
      ERR_SET_CAN_DISTRIBUTE_ALREADY_CALLED
    )
    (asserts! (var-get are-weights-computed) ERR_WEIGHTS_NOT_COMPUTED)
    (let (
        (pool-rewards (get-wallet-sbtc-balance current-contract))
        (max-cap-rewards (/ (* (cycle-percentage-rate) (var-get total-weights-sum))
          (+ (var-get yield-boost-multiplier) u1)
        ))
        (local-rewards-to-distribute (if (< (* DECIMAL_PRECISION_8 pool-rewards) max-cap-rewards)
          (* DECIMAL_PRECISION_8 pool-rewards)
          max-cap-rewards
        ))
      )
      (var-set rewards-to-distribute local-rewards-to-distribute)
      (var-set last-operation-done u5)
      (ok (var-set is-distribution-enabled true))
    )
  )
)

(define-public (distribute-rewards (principals (list 900 principal)))
  (begin
    (asserts! (var-get is-distribution-enabled)
      ERR_CANNOT_DISTRIBUTE_REWARDS
    )
    (if (is-eq
        (+ (var-get current-cycle-total-sbtc-in-wallet)
          (var-get current-cycle-total-sbtc-in-defis)
        )
        u0
      )
      (begin
        (var-set participants-rewarded-count
          (var-get current-cycle-participants-count)
        )
        (ok (list))
      )
      (ok (map distribute-reward-user principals))
    )
  )
)

(define-private (distribute-reward-user (user principal))
  (let (
      (cycle-id-current (var-get cycle-id))
      (rollback-id-current (var-get current-cycle-rollback-id))
      (holding-state (unwrap!
        (map-get? participant-holdings-per-cycle {
          participant-address: user,
          cycle-id: cycle-id-current,
          rollback-id: rollback-id-current,
        })
        ERR_NOT_ENROLLED
      ))
      (participant-state (unwrap-panic (at-block (var-get current-cycle-stacks-block-hash)
        (map-get? participants { address: user })
      )))
      (participant-state-now (map-get? participants { address: user }))
      (stacking-address (get stacking-address participant-state))
      (stacking-state (unwrap!
        (map-get? stx-stacked-by-stacking-address {
          stacking-address: stacking-address,
          cycle-id: cycle-id-current,
          rollback-id: rollback-id-current,
        })
        ERR_NOT_ENROLLED
      ))
      (tracking-address (get tracking-address participant-state))
      (tracking-state (unwrap!
        (map-get? sbtc-holdings-by-tracking-address {
          tracking-address: tracking-address,
          cycle-id: cycle-id-current,
          rollback-id: rollback-id-current,
        })
        ERR_NOT_ENROLLED
      ))
      (rewarded-address (if (is-some participant-state-now)
        (unwrap-panic (get rewarded-address participant-state-now))
        (get rewarded-address participant-state)
      ))
      (weight-data (unwrap!
        (map-get? participant-weights-by-tracking-address {
          cycle-id: cycle-id-current,
          tracking-address: tracking-address,
        })
        ERR_WEIGHTS_NOT_COMPUTED
      ))
      (user-weight-wallet (get weight-wallet weight-data))
      (user-weight-defi (get weight-defi weight-data))
      (user-weight-total (get weight-total weight-data))
      (total-weight (var-get total-weights-sum))
      (stx-user-amount (get stx-amount stacking-state))
      (sbtc-user-amount (get sbtc-wallet-amount tracking-state))
      (user-theoretical-ratio (if (is-eq sbtc-user-amount u0)
        u0
        (/ (* stx-user-amount RATIO_SCALE_FACTOR) sbtc-user-amount)
      ))
      (golden-ratio (unwrap!
        (get golden-ratio
          (map-get? validated-golden-ratio-per-cycle { cycle-id: cycle-id-current })
        )
        ERR_RATIOS_NOT_CONCLUDED
      ))
      (user-ratio (if (> user-theoretical-ratio golden-ratio)
        golden-ratio
        user-theoretical-ratio
      ))
      (reward-amount-wallet (if (is-eq total-weight u0)
        u0
        (/ (* user-weight-wallet (var-get rewards-to-distribute))
          (* total-weight DECIMAL_PRECISION_8)
        )
      ))
      (reward-amount-defi (if (is-eq total-weight u0)
        u0
        (/ (* user-weight-defi (var-get rewards-to-distribute))
          (* total-weight DECIMAL_PRECISION_8)
        )
      ))
      (reward-amount-total (+ reward-amount-wallet reward-amount-defi))
    )
    (if (get has-been-rewarded holding-state)
      ERR_ALREADY_REWARDED
      (begin
        (var-set participants-rewarded-count
          (+ (var-get participants-rewarded-count) u1)
        )
        (map-set participant-holdings-per-cycle {
          participant-address: user,
          cycle-id: cycle-id-current,
          rollback-id: rollback-id-current,
        }
          (merge holding-state {
            has-been-rewarded: true,
            reward-amount: reward-amount-total,
          })
        )
        (if (not (get has-been-rewarded tracking-state))
          (begin
            (map-set rewards-by-rewarded-address {
              rewarded-address: rewarded-address,
              cycle-id: cycle-id-current,
            } { reward-amount: reward-amount-total }
            )
            (map-set sbtc-holdings-by-tracking-address {
              tracking-address: tracking-address,
              cycle-id: cycle-id-current,
              rollback-id: rollback-id-current,
            }
              (merge tracking-state { has-been-rewarded: true })
            )
            (print {
              cycle-id: cycle-id-current,
              enrolled-address: user,
              reward-address: rewarded-address,
              stacking-address: stacking-address,
              tracking-address: tracking-address,
              reward-amount-wallet: reward-amount-wallet,
              reward-amount-defi: reward-amount-defi,
              reward-amount-total: reward-amount-total,
              weight-wallet: user-weight-wallet,
              weight-defi: user-weight-defi,
              weight-total: user-weight-total,
              ratio: user-ratio,
              function-name: "distribute-rewards",
            })
            (if (> reward-amount-total u0)
              (try! (transfer-sbtc-from-contract reward-amount-total
                rewarded-address
              ))
              false
            )
          )
          (begin
            (print {
              cycle-id: cycle-id-current,
              enrolled-address: user,
              reward-address: rewarded-address,
              stacking-address: stacking-address,
              tracking-address: tracking-address,
              reward-amount-wallet: u0,
              reward-amount-defi: u0,
              reward-amount-total: u0,
              weight-wallet: u0,
              weight-defi: u0,
              weight-total: u0,
              ratio: u0,
              function-name: "distribute-rewards",
            })
            false
          )
        )
        (ok true)
      )
    )
  )
)

(define-public (finalize-reward-distribution)
  (begin
    (asserts! (var-get is-contract-active) ERR_CONTRACT_NOT_ACTIVE)
    (asserts!
      (is-eq (var-get current-cycle-participants-count)
        (var-get participants-rewarded-count)
      )
      ERR_NOT_REWARDED_ALL
    )
    (asserts! (var-get is-distribution-enabled) ERR_CANNOT_FINALIZE)
    (asserts!
      (is-none (map-get? cycle-finalization-block-heights { cycle-id: (var-get cycle-id) }))
      ERR_ALREADY_FINALIZED
    )

    (print {
      bitcoin-block-height: burn-block-height,
      cycle-id: (var-get cycle-id),
      function-name: "finalize-reward-distribution",
    })
    (var-set last-operation-done u6)
    (ok (map-set cycle-finalization-block-heights { cycle-id: (var-get cycle-id) } { stacks-block-height-at-finalization: stacks-block-height }))
  )
)

(define-public (advance-to-next-cycle (stx-block-height uint))
  (begin
    (asserts! (var-get is-contract-active) ERR_CONTRACT_NOT_ACTIVE)
    (asserts!
      (>= burn-block-height (var-get next-cycle-bitcoin-block-height))
      ERR_NOT_NEW_CYCLE_YET
    )
    (asserts!
      (is-eq (var-get current-cycle-participants-count)
        (var-get participants-rewarded-count)
      )
      ERR_NOT_REWARDED_ALL
    )
    (asserts!
      (is-some (map-get? cycle-finalization-block-heights { cycle-id: (var-get cycle-id) }))
      ERR_REWARDS_NOT_SENT_YET
    )
    (asserts!
      (unwrap-panic (validate-bitcoin-block stx-block-height
        (var-get next-cycle-bitcoin-block-height)
      ))
      ERR_STX_BLOCK_NOT_MATCHING
    )

    (var-set current-cycle-bitcoin-block-height
      (+ (var-get current-cycle-bitcoin-block-height)
        (+
          (* (var-get blocks-per-snapshot)
            (var-get snapshots-per-cycle)
          )
          (var-get buffer-blocks-per-cycle)
        ))
    )
    (var-set cycle-id (+ (var-get cycle-id) u1))
    (reset-state-for-cycle stx-block-height)
    (ok true)
  )
)

(define-read-only (get-current-cycle-id)
  (var-get cycle-id)
)

(define-read-only (cycle-data)
  {
    cycle-id: (var-get cycle-id),
    current-cycle-bitcoin-block-height: (var-get current-cycle-bitcoin-block-height),
    next-cycle-bitcoin-block-height: (var-get next-cycle-bitcoin-block-height),
    current-cycle-stacks-block-height: (var-get current-cycle-stacks-block-height),
    current-cycle-stacks-block-hash: (var-get current-cycle-stacks-block-hash),
    participants-count: (var-get current-cycle-participants-count),
    snapshots-per-cycle: (var-get snapshots-per-cycle),
    reward-mechanism: (var-get reward-calculation-mechanism),
    blocks-per-snapshot: (var-get blocks-per-snapshot),
    buffer-blocks-per-cycle: (var-get buffer-blocks-per-cycle),
    buffer-period-start-block: (var-get buffer-period-start-block),
    current-snapshot-index: (var-get current-snapshot-index),
    defi-multiplier: DECIMAL_PRECISION_8,
  }
)

(define-read-only (get-cycle-current-state)
  {
    cycle-id: (var-get cycle-id),
    first-bitcoin-block: (var-get current-cycle-bitcoin-block-height),
    last-bitcoin-block: (- (var-get next-cycle-bitcoin-block-height) u1),
  }
)

(define-read-only (current-overview-data)
  {
    cycle-id: (var-get cycle-id),
    snapshot-index: (var-get current-snapshot-index),
    snapshots-per-cycle: (var-get snapshots-per-cycle),
  }
)

(define-read-only (get-yield-cycle-data (cycle uint))
  (map-get? yield-cycles-data { cycle-id: cycle })
)

(define-read-only (snapshot-data)
  {
    current-snapshot-bitcoin-block-height: (var-get current-snapshot-bitcoin-block-height),
    current-snapshot-stacks-block-height: (var-get current-snapshot-stacks-block-height),
    current-snapshot-count: (var-get current-snapshot-count),
    current-snapshot-total-sbtc: (var-get current-snapshot-total-sbtc),
    current-snapshot-total-sbtc-in-defis: (var-get current-snapshot-total-sbtc-in-defis),
    current-snapshot-total-stx: (var-get current-snapshot-total-stx),
    current-snapshot-index: (var-get current-snapshot-index),
    blocks-per-snapshot: (var-get blocks-per-snapshot),
  }
)

(define-read-only (get-snapshot-data
    (checked-cycle-id uint)
    (checked-rollback-id uint)
    (checked-snapshot-id uint)
  )
  (map-get? snapshot-aggregate-data {
    cycle-id: checked-cycle-id,
    rollback-id: checked-rollback-id,
    snapshot-index: checked-snapshot-id,
  })
)

(define-read-only (get-stacks-block-height-for-cycle-snapshot
    (checked-cycle-id uint)
    (checked-rollback-id uint)
    (checked-snapshot-id uint)
  )
  (get stacks-block-height
    (get-snapshot-data checked-cycle-id checked-rollback-id
      checked-snapshot-id
    ))
)

(define-read-only (get-bitcoin-block-height-for-cycle-snapshot
    (checked-cycle-id uint)
    (checked-rollback-id uint)
    (checked-snapshot-id uint)
  )
  (get bitcoin-block-height
    (get-snapshot-data checked-cycle-id checked-rollback-id
      checked-snapshot-id
    ))
)

(define-read-only (get-reward-distribution-status)
  {
    participants-rewarded-count: (var-get participants-rewarded-count),
    is-distribution-enabled: (var-get is-distribution-enabled),
  }
)

(define-read-only (is-distribution-ready)
  (var-get is-distribution-enabled)
)

(define-read-only (reward-amount-for-cycle-and-address
    (wanted-cycle-id uint)
    (wanted-rollback-id uint)
    (address principal)
  )
  (get reward-amount
    (map-get? participant-holdings-per-cycle {
      cycle-id: wanted-cycle-id,
      rollback-id: wanted-rollback-id,
      participant-address: address,
    })
  )
)

(define-read-only (reward-amount-for-cycle-and-reward-address
    (wanted-cycle-id uint)
    (reward-address principal)
  )
  (get reward-amount
    (map-get? rewards-by-rewarded-address {
      cycle-id: wanted-cycle-id,
      rewarded-address: reward-address,
    })
  )
)

(define-read-only (is-distribution-finalized-for-current-cycle)
  (is-some (map-get? cycle-finalization-block-heights { cycle-id: (var-get cycle-id) }))
)

(define-read-only (get-distribution-finalized-at-height
    (wanted-cycle-id uint)
    (wanted-rollback-id uint)
  )
  (map-get? cycle-finalization-block-heights { cycle-id: wanted-cycle-id })
)

(define-read-only (get-buffer-end-block)
  (+ (var-get buffer-period-start-block)
    (var-get buffer-blocks-per-cycle)
  )
)

(define-read-only (is-buffer-period-passed)
  (>= burn-block-height (get-buffer-end-block))
)

(define-read-only (get-last-operation-state)
  (var-get last-operation-done)
)

(define-read-only (get-admin)
  (var-get admin)
)

(define-read-only (get-is-contract-active)
  (var-get is-contract-active)
)

(define-read-only (get-current-bitcoin-block-height)
  burn-block-height
)

(define-read-only (get-minimum-enrollment-amount)
  (var-get min-sbtc-hold-required-for-enrollment)
)

(define-read-only (get-next-action-bitcoin-height)
  (if (var-get is-contract-active)
    (+ (var-get current-snapshot-bitcoin-block-height)
      (var-get blocks-per-snapshot)
    )
    (var-get current-cycle-bitcoin-block-height)
  )
)

(define-read-only (is-enrolled-in-next-cycle (address principal))
  (is-some (map-get? participants { address: address }))
)

(define-read-only (is-enrolled-this-cycle (address principal))
  (is-some (at-block (var-get current-cycle-stacks-block-hash)
    (map-get? participants { address: address })
  ))
)

(define-read-only (get-is-blacklisted (address principal))
  (is-some (map-get? blacklist { address: address }))
)

(define-read-only (get-is-blacklisted-list (addresses (list 900 principal)))
  (map is-blacklisted addresses)
)

(define-private (is-blacklisted (address principal))
  (is-some (map-get? blacklist { address: address }))
)

(define-read-only (get-latest-reward-address (address principal))
  (get rewarded-address (map-get? participants { address: address }))
)

(define-read-only (get-participant-cycle-info
    (address principal)
    (cycle uint)
    (rollback uint)
  )
  (let (
      (participant-info (at-block
        (unwrap-panic (get-stacks-block-info? id-header-hash
          (unwrap!
            (get start-stx-block-height
              (map-get? yield-cycles-data { cycle-id: cycle })
            )
            ERR_CYCLE_IN_FUTURE
          )))
        (map-get? participants { address: address })
      ))
      (tracking-address (unwrap! (get tracking-address participant-info) ERR_NOT_ENROLLED))
      (stacking-address (unwrap! (get stacking-address participant-info) ERR_NOT_ENROLLED))
    )
    (ok {
      participant-data: participant-info,
      holding-data: (map-get? participant-holdings-per-cycle {
        cycle-id: cycle,
        rollback-id: rollback,
        participant-address: address,
      }),
      tracking-data: (map-get? sbtc-holdings-by-tracking-address {
        cycle-id: cycle,
        rollback-id: rollback,
        tracking-address: tracking-address,
      }),
      stacking-data: (map-get? stx-stacked-by-stacking-address {
        cycle-id: cycle,
        rollback-id: rollback,
        stacking-address: stacking-address,
      }),
    })
  )
)

(define-read-only (nr-cycles-year)
  (/ (* DECIMAL_PRECISION_8 (var-get bitcoin-blocks-per-year))
    (+ (* (var-get blocks-per-snapshot) (var-get snapshots-per-cycle))
      (var-get buffer-blocks-per-cycle)
    ))
)

(define-read-only (cycle-percentage-rate)
  (/ (* DECIMAL_PRECISION_8 (var-get annual-percentage-rate))
    (nr-cycles-year)
  )
)

(define-read-only (get-amount-stx-stacked (address principal))
  (get locked (stx-account address))
)

(define-read-only (get-amount-stx-stacked-at-block-height
    (address principal)
    (stx-block-height uint)
  )
  (at-block
    (unwrap-panic (get-stacks-block-info? id-header-hash stx-block-height))
    (get locked (stx-account address))
  )
)

(define-read-only (get-amount-stacked-at-block-height
    (address principal)
    (stx-block-height uint)
  )
  (if (var-get is-liquid-stacking-enabled)
    (+
      (contract-call? .liquid-stacking-v2
        get-user-liquid-stx-stacked-at-block-height address
        stx-block-height
      )
      (get-amount-stx-stacked-at-block-height address stx-block-height)
    )
    (get-amount-stx-stacked-at-block-height address stx-block-height)
  )
)

(define-read-only (get-amount-stacked-now (address principal))
  (get-amount-stacked-at-block-height address
    (- stacks-block-height u1)
  )
)

(define-read-only (get-apr-data)
  {
    MULTIPLIER: (+ (var-get yield-boost-multiplier) u1),
    MAX_APR: (var-get annual-percentage-rate),
    MIN_APR: (/ (var-get annual-percentage-rate)
      (+ (var-get yield-boost-multiplier) u1)
    ),
  }
)

(define-read-only (meets-enrollment-minimum (user {
  address: principal,
  arkadiko: bool,
  based-dollar: bool,
  bitflow: bool,
  granite: bool,
  velar: bool,
  zest: bool,
}))
  (>=
    (get-wallet-sbtc-balance (get address user))
    (var-get min-sbtc-hold-required-for-enrollment)
  )
)

(define-read-only (get-wallet-sbtc-balance (address principal))
  (unwrap-panic (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
    get-balance-available address
  ))
)

(define-read-only (get-defi-sbtc-balance (user {
  address: principal,
  arkadiko: bool,
  based-dollar: bool,
  bitflow: bool,
  granite: bool,
  velar: bool,
  zest: bool,
}))
  (contract-call? .sbtc-holdings-defi
    get-user-individual-sBTC-in-DeFIs user
  )
)

(define-read-only (get-defi-sbtc-balance-now (address principal))
  (let (
      (cycle-id-current (var-get cycle-id))
      (current-snapshot-index-value (var-get current-snapshot-index))
      (arkadiko (is-defi-protocol-healthy ARKADIKO cycle-id-current
        current-snapshot-index-value
      ))
      (based-dollar (is-defi-protocol-healthy BASED_DOLLAR cycle-id-current
        current-snapshot-index-value
      ))
      (bitflow (is-defi-protocol-healthy BITFLOW cycle-id-current
        current-snapshot-index-value
      ))
      (granite (is-defi-protocol-healthy GRANITE cycle-id-current
        current-snapshot-index-value
      ))
      (velar (is-defi-protocol-healthy VELAR cycle-id-current
        current-snapshot-index-value
      ))
      (zest (is-defi-protocol-healthy ZEST cycle-id-current
        current-snapshot-index-value
      ))
    )
    (contract-call? .sbtc-holdings-defi
      get-user-individual-sBTC-in-DeFIs {
      address: address,
      arkadiko: arkadiko,
      based-dollar: based-dollar,
      bitflow: bitflow,
      granite: granite,
      velar: velar,
      zest: zest,
    })
  )
)

(define-public (validate-bitcoin-block
    (stx-block-height-proposed uint)
    (btc-block-related uint)
  )
  (contract-call? .bitcoin-block-buffer-v2
    validate-stx-block-brackets-btc-block stx-block-height-proposed
    btc-block-related
  )
)

(define-private (transfer-sbtc-from-contract
    (amount uint)
    (recipient principal)
  )
  (as-contract?
    ((with-ft 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
      "sbtc-token" amount
    ))
    (unwrap-panic (contract-call?
      'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token transfer
      amount tx-sender recipient none
    ))
  )
)

```
