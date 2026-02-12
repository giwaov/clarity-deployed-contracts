---
title: "Contract dual-stacking-v2_0_3"
draft: true
---
Deployer: SP1HFCRKEJ8BYW4D0E3FAWHFDX8A25PPAA83HWWZ9


 



Block height: 6175888 (2026-01-28T17:33:48.000Z)

Source code: {{<contractref "dual-stacking-v2_0_3" SP1HFCRKEJ8BYW4D0E3FAWHFDX8A25PPAA83HWWZ9 dual-stacking-v2_0_3>}}

Functions:

* add-blacklisted _private_
* add-optimized-operator _private_
* calculate-participant-weight _private_
* capture-participant-balances _private_
* capture-participant-balances-optimizer _private_
* capture-participant-snapshot _private_
* change-addresses-defi-one _private_
* distribute-reward-user _private_
* enroll-defi _private_
* enroll-defi-one _private_
* is-blacklisted _private_
* opt-out-defi _private_
* remove-blacklisted _private_
* remove-optimized-operator _private_
* remove-participant _private_
* reset-state-for-cycle _private_
* tally-user-ratio _private_
* transfer-sbtc-from-contract _private_
* add-blacklisted-batch _public_
* add-optimized-operator-batch _public_
* advance-to-next-cycle _public_
* advance-to-next-snapshot _public_
* calculate-participant-weights _public_
* capture-snapshot-balances _public_
* capture-snapshot-balances-optimizer _public_
* change-addresses-defi-batch _public_
* change-proposed-golden-ratio _public_
* change-reward-address _public_
* distribute-rewards _public_
* emergency-withdraw-sbtc _public_
* enroll _public_
* enroll-defi-batch _public_
* finalize-reward-distribution _public_
* finalize-snapshots _public_
* finalize-weight-computation _public_
* initialize-contract _public_
* mark-defi-compromised _public_
* opt-out _public_
* opt-out-defi-batch _public_
* propose-golden-ratio _public_
* remove-blacklisted-batch _public_
* remove-optimized-operator-batch _public_
* restore-defi-protocol _public_
* set-is-distribution-enabled _public_
* set-liquid-stacking _public_
* set-max-percentage-above-golden-ratio _public_
* start-buffer-period _public_
* tally-participant-ratios _public_
* trigger-full-cycle-rollback _public_
* update-admin _public_
* update-apr _public_
* update-bitcoin-blocks-per-year _public_
* update-buffer-blocks _public_
* update-cycle-data _public_
* update-cycle-data-before-initialized _public_
* update-initialize-block _public_
* update-min-sbtc-hold-required-for-enrollment _public_
* update-snapshot-length _public_
* update-snapshots-per-cycle _public_
* update-yield-boost-multiplier _public_
* validate-bitcoin-block _public_
* validate-ratio _public_
* current-overview-data _read_only_
* cycle-data _read_only_
* cycle-percentage-rate _read_only_
* get-admin _read_only_
* get-amount-stacked-at-block-height _read_only_
* get-amount-stacked-now _read_only_
* get-amount-stx-stacked _read_only_
* get-amount-stx-stacked-at-block-height _read_only_
* get-apr-data _read_only_
* get-bitcoin-block-height-for-cycle-snapshot _read_only_
* get-buffer-end-block _read_only_
* get-current-bitcoin-block-height _read_only_
* get-current-cycle-id _read_only_
* get-cycle-current-state _read_only_
* get-defi-sbtc-balance _read_only_
* get-defi-sbtc-balance-now _read_only_
* get-distribution-finalized-at-height _read_only_
* get-is-blacklisted _read_only_
* get-is-blacklisted-list _read_only_
* get-is-contract-active _read_only_
* get-last-operation-state _read_only_
* get-latest-reward-address _read_only_
* get-minimum-enrollment-amount _read_only_
* get-next-action-bitcoin-height _read_only_
* get-participant-cycle-info _read_only_
* get-participant-weight _read_only_
* get-ratio-data _read_only_
* get-reward-distribution-status _read_only_
* get-snapshot-data _read_only_
* get-stacks-block-height-for-cycle-snapshot _read_only_
* get-wallet-sbtc-balance _read_only_
* get-weight-computation-status _read_only_
* get-yield-cycle-data _read_only_
* is-buffer-period-passed _read_only_
* is-defi-protocol-healthy _read_only_
* is-distribution-finalized-for-current-cycle _read_only_
* is-distribution-ready _read_only_
* is-enrolled-in-next-cycle _read_only_
* is-enrolled-this-cycle _read_only_
* meets-enrollment-minimum _read_only_
* nr-cycles-year _read_only_
* reward-amount-for-cycle-and-address _read_only_
* reward-amount-for-cycle-and-reward-address _read_only_
* snapshot-data _read_only_
