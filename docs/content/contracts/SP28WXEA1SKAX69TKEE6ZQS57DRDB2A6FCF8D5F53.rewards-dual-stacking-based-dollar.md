---
title: "Contract rewards-dual-stacking-based-dollar"
draft: true
---
Deployer: SP28WXEA1SKAX69TKEE6ZQS57DRDB2A6FCF8D5F53


 



Block height: 5018850 (2025-11-28T14:42:15.000Z)

Source code: {{<contractref "rewards-dual-stacking-based-dollar" SP28WXEA1SKAX69TKEE6ZQS57DRDB2A6FCF8D5F53 rewards-dual-stacking-based-dollar>}}

Functions:

* calculate-user-sbtc-equivalent-balance _private_
* compute-and-update-balances-one-user _private_
* distribute-reward-user _private_
* reset-state-for-cycle _private_
* update-snapshot-for-new-cycle _private_
* compute-current-snapshot-balances _public_
* conclude-cycle-snapshots _public_
* distribute-rewards _public_
* extract-funds-safety _public_
* head-to-next-cycle _public_
* head-to-next-snapshot _public_
* initialize-contract _public_
* set-is-distribution-enabled _public_
* set-snapshot-participants-count _public_
* can-call-set-is-distribution-enabled _read_only_
* can-call-set-snapshot-participants-count _read_only_
* can-head-to-next-cycle-or-snapshot _read_only_
* current-overview-data _read_only_
* cycle-data _read_only_
* get-admin _read_only_
* get-bitcoin-block-height-for-cycle-snapshot _read_only_
* get-is-contract-active _read_only_
* get-is-yield-active _read_only_
* get-stacks-block-height-for-cycle-snapshot _read_only_
* get-total-balance-at-stacks-block _read_only_
* get-user-total-sBTC-balance _read_only_
* is-distribution-ready _read_only_
* rewarded-data _read_only_
* snapshot-data _read_only_
* state-last-operation _read_only_
* stx-block-height-distribution-finalized _read_only_
* stx-block-height-distribution-finalized-for-wanted-cycle _read_only_
* yield-contract-blocks-per-snapshot _read_only_
* yield-contract-current-cycle-stacks-block-height _read_only_
* yield-contract-cycle-id _read_only_
* yield-contract-snapshot-index _read_only_
* yield-contract-snapshots-per-cycle _read_only_
