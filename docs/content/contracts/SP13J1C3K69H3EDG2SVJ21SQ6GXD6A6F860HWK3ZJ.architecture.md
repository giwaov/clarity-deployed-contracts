---
title: "Contract architecture"
draft: true
---
Deployer: SP13J1C3K69H3EDG2SVJ21SQ6GXD6A6F860HWK3ZJ


 



Block height: 5355195 (2025-12-17T18:24:25.000Z)

Source code: {{<contractref "architecture" SP13J1C3K69H3EDG2SVJ21SQ6GXD6A6F860HWK3ZJ architecture>}}

Functions:

* calculate-platform-fee _private_
* generate-invoice-id _private_
* generate-receipt-id _private_
* is-invoice-expired _private_
* validate-currency _private_
* validate-merchant _private_
* validate-principal _private_
* validate-webhook _private_
* create-invoice _public_
* expire-invoice _public_
* process-payment _public_
* register-merchant _public_
* set-paused _public_
* set-platform-fee-recipient _public_
* get-invoice _read_only_
* get-merchant _read_only_
* get-receipt _read_only_
* is-invoice-payable _read_only_
