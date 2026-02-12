---
title: "Trait ata-v1-authorization"
draft: true
---
```
(contract-call? 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-ft-v0
  remove-authorized-to-mint-contract
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.ata-v1
)
(contract-call? 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-ft-v0
  add-authorized-to-mint-contract
  'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-v1
)

(contract-call? 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-store-v0
  remove-authorized-caller 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.ata-v1
)
(contract-call? 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-store-v0
  add-authorized-caller 'SP1EF9EHG1JNX84RGA8Z8F8HYTSCAHWE21273RCJ4.ata-v1
)
```
