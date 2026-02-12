---
title: "Contract xtrata-v2-1-0"
draft: true
---
Deployer: SP3JNSEXAZP4BDSHV0DN3M8R3P0MY0EEBQQZX743X

Traits:
SIP-009 



Block height: 6403275 (2026-02-07T22:36:45.000Z)

Source code: {{<contractref "xtrata-v2-1-0" SP3JNSEXAZP4BDSHV0DN3M8R3P0MY0EEBQQZX743X xtrata-v2-1-0>}}

Functions:

* append-chunk-batch _private_
* assert-inscription-allowed _private_
* assert-not-expired _private_
* calc-batch-fee _private_
* collect-unique-hash _private_
* dep-exists? _private_
* hash-in-list-step _private_
* hash-in-list? _private_
* maybe-pay _private_
* num-batches _private_
* process-chunk _private_
* purge-expired-chunk _private_
* record-mint _private_
* seal-batch-item _private_
* seal-commit _private_
* seal-internal _private_
* seal-validate _private_
* upload-expired? _private_
* validate-batch-uniqueness _private_
* validate-dep _private_
* validate-dependencies _private_
* validate-purge-index _private_
* validate-purge-indexes _private_
* abandon-upload _public_
* add-chunk-batch _public_
* begin-inscription _public_
* begin-or-get _public_
* migrate-from-v1 _public_
* purge-expired-chunk-batch _public_
* seal-inscription _public_
* seal-inscription-batch _public_
* seal-recursive _public_
* set-allowed-caller _public_
* set-fee-unit _public_
* set-next-id _public_
* set-paused _public_
* set-royalty-recipient _public_
* transfer _public_
* transfer-contract-ownership _public_
* get-admin _read_only_
* get-chunk _read_only_
* get-chunk-batch _read_only_
* get-dependencies _read_only_
* get-fee-unit _read_only_
* get-id-by-hash _read_only_
* get-inscription-chunks _read_only_
* get-inscription-creator _read_only_
* get-inscription-hash _read_only_
* get-inscription-meta _read_only_
* get-inscription-size _read_only_
* get-last-token-id _read_only_
* get-minted-count _read_only_
* get-minted-id _read_only_
* get-next-token-id _read_only_
* get-owner _read_only_
* get-pending-chunk _read_only_
* get-royalty-recipient _read_only_
* get-svg _read_only_
* get-svg-data-uri _read_only_
* get-token-uri _read_only_
* get-token-uri-raw _read_only_
* get-upload-state _read_only_
* inscription-exists _read_only_
* is-allowed-caller _read_only_
* is-inscription-sealed _read_only_
* is-paused _read_only_
