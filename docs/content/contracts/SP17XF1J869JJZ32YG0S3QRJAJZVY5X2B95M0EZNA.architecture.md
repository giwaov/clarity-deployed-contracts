---
title: "Contract architecture"
draft: true
---
Deployer: SP17XF1J869JJZ32YG0S3QRJAJZVY5X2B95M0EZNA


 



Block height: 5579204 (2025-12-29T18:03:15.000Z)

Source code: {{<contractref "architecture" SP17XF1J869JJZ32YG0S3QRJAJZVY5X2B95M0EZNA architecture>}}

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
