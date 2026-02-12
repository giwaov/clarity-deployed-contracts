---
title: "Contract st-1-market"
draft: true
---
Deployer: SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM


 



Block height: 5468038 (2025-12-23T15:12:55.000Z)

Source code: {{<contractref "st-1-market" SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM st-1-market>}}

Functions:

* accrue-and-cache _private_
* accrue-collateral-asset _private_
* accrue-debt-asset _private_
* accrue-user-collateral _private_
* accrue-user-debts _private_
* calc-final-liquidation-amounts _private_
* calc-liq-collateral-repay _private_
* calc-liq-debt-repay _private_
* calc-liq-debt-repay-real _private_
* calc-liq-factor _private_
* calc-liq-factor-bound _private_
* calc-liq-factor-exp _private_
* calc-liquidation-params _private_
* calculate-asset-notional-value _private_
* call-dia _private_
* call-liquidate _private_
* call-pyth _private_
* check-confidence _private_
* check-dao-auth _private_
* convert-to-scaled-debt _private_
* div-bps-down _private_
* div-down _private_
* div-up _private_
* filter-out-debt-asset _private_
* find-and-resolve-asset-value _private_
* find-asset _private_
* find-collateral-amount _private_
* find-debt-scaled _private_
* get-account-scaled-debt _private_
* get-asset _private_
* get-asset-id _private_
* get-asset-value _private_
* get-assets _private_
* get-egroup _private_
* get-enabled-bitmap _private_
* get-full-position _private_
* get-liquidation-position _private_
* get-notional-evaluation _private_
* get-oracle _private_
* get-position _private_
* get-status-multi _private_
* is-healthy _private_
* is-healthy-with-mask _private_
* is-liquidation-paused _private_
* is-ztoken _private_
* iter-find-asset _private_
* iter-find-collateral _private_
* iter-find-debt _private_
* iter-price-multi _private_
* mask-shift-combine _private_
* mask-to-list-collateral _private_
* mask-to-list-internal _private_
* mask-to-list-iter _private_
* merge-price _private_
* min _private_
* mul-bps-down _private_
* mul-div-down _private_
* mul-div-up _private_
* normalize _private_
* normalize-pyth _private_
* oracle-price-legal _private_
* oracle-timestamp-fresh _private_
* price-multi-resolve _private_
* price-resolve _private_
* process-collateral-asset _private_
* process-debt-asset _private_
* remove-if-match _private_
* resolve-callcode _private_
* resolve-dia _private_
* resolve-price-feed _private_
* resolve-pyth _private_
* resolve-ststx _private_
* resolve-ztoken _private_
* scale-debt-for-liquidation _private_
* socialize-debt-asset _private_
* user-safe-mask _private_
* vault-accrue _private_
* vault-deposit _private_
* vault-redeem _private_
* vault-socialize-debt _private_
* vault-system-borrow _private_
* vault-system-repay _private_
* write-feed _private_
* write-feeds _private_
* borrow _public_
* call-ststx-ratio _public_
* collateral-add _public_
* collateral-remove _public_
* collateral-remove-redeem _public_
* liquidate _public_
* liquidate-multi _public_
* liquidate-redeem _public_
* repay _public_
* set-liquidation-grace-period _public_
* set-max-confidence-ratio _public_
* set-pause-liquidation _public_
* supply-collateral-add _public_
* get-cached-indexes _read_only_
* get-liquidation-grace-end _read_only_
* get-liquidation-grace-period-asset _read_only_
* get-max-confidence-ratio _read_only_
* get-pause-liquidation _read_only_
* oracle-last-update _read_only_
