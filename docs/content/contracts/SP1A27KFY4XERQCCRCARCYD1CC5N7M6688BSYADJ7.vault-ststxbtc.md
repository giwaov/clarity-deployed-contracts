---
title: "Contract vault-ststxbtc"
draft: true
---
Deployer: SP1A27KFY4XERQCCRCARCYD1CC5N7M6688BSYADJ7

Traits:
 SIP-0010



Block height: 5869771 (2026-01-14T01:34:33.000Z)

Source code: {{<contractref "vault-ststxbtc" SP1A27KFY4XERQCCRCARCYD1CC5N7M6688BSYADJ7 vault-ststxbtc>}}

Functions:

* calc-cumulative-debt _private_
* calc-index-next _private_
* calc-liquidity-rate _private_
* calc-multiplier-delta _private_
* calc-principal-ratio-reduction _private_
* calc-treasury-lp-preview _private_
* calc-utilization _private_
* check-caller-auth _private_
* check-dao-auth _private_
* combine-elements _private_
* convert-to-assets-preview _private_
* convert-to-shares-preview _private_
* debt-preview _private_
* get-balance-internal _private_
* interest-rate _private_
* interpolate-rate _private_
* iter-pack-u16 _private_
* iter-unpack-u16 _private_
* linear-interpolate _private_
* max _private_
* min _private_
* mul-bps-down _private_
* mul-div-down _private_
* mul-div-up _private_
* next-index _private_
* next-liquidity-index _private_
* pack-u16 _private_
* principal-ratio-reduction _private_
* receive-underlying _private_
* resolve-and-interpolate _private_
* resolve-interpolation-points _private_
* send-underlying _private_
* set-permission-single _private_
* total-assets _private_
* total-assets-preview _private_
* total-debt _private_
* total-supply _private_
* total-supply-preview _private_
* ubalance _private_
* unpack-u16 _private_
* unpack-u16-at _private_
* utilization _private_
* zip _private_
* accrue _public_
* deposit _public_
* flashloan _public_
* initialize _public_
* redeem _public_
* set-authorized-contract _public_
* set-cap-debt _public_
* set-cap-supply _public_
* set-default-flashloan-permissions _public_
* set-fee-flash _public_
* set-fee-reserve _public_
* set-flashloan-permissions _public_
* set-flashloan-permissions-many _public_
* set-pause-states _public_
* set-points-rate _public_
* set-points-util _public_
* set-token-uri _public_
* socialize-debt _public_
* system-borrow _public_
* system-repay _public_
* transfer _public_
* convert-to-assets _read_only_
* convert-to-shares _read_only_
* get-assets _read_only_
* get-available-assets _read_only_
* get-balance _read_only_
* get-cap-debt _read_only_
* get-cap-supply _read_only_
* get-debt _read_only_
* get-decimals _read_only_
* get-default-flashloan-permissions _read_only_
* get-fee-flash _read_only_
* get-fee-reserve _read_only_
* get-flashloan-permissions _read_only_
* get-index _read_only_
* get-interest-rate _read_only_
* get-last-update _read_only_
* get-liquidity-index _read_only_
* get-name _read_only_
* get-next-index _read_only_
* get-pause-states _read_only_
* get-points-rate _read_only_
* get-points-util _read_only_
* get-principal-ratio-reduction _read_only_
* get-principal-scaled _read_only_
* get-symbol _read_only_
* get-token-uri _read_only_
* get-total-assets _read_only_
* get-total-supply _read_only_
* get-underlying _read_only_
* get-utilization _read_only_
* is-authorized-contract _read_only_
