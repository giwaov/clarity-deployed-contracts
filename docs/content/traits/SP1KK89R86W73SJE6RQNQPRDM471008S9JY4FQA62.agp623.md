---
title: "Trait agp623"
draft: true
---
```
;; SPDX-License-Identifier: BUSL-1.1
(impl-trait 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.proposal-trait.proposal-trait)
(use-trait ft-trait 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.trait-sip-010.sip-010-trait)

;; Main execute function
(define-public (execute (sender principal))
  (begin
    ;; Finalise migrate for the following addresses
    (try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.migrate-legacy-v2-wl finalise-migrate 'SP1N4RJNMF1ZW1PSDCNNV37GPX2GA2ZEZF5ZMSSTX))
    (try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.migrate-legacy-v2-wl finalise-migrate 'SP14T4K2XF0RPHJEE6BBB15T0Q96V19HC2KBVJ7RR))
    (try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.migrate-legacy-v2-wl finalise-migrate 'SP32RC56M7E6029NVFV1ED114ASYA1Y0WRMSTQ6ZW))
    (try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.migrate-legacy-v2-wl finalise-migrate 'SP1M6P3BJ7PC9Q64VPYZXJAE87YBMR1EM2QY8AQJR))
    (try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.migrate-legacy-v2-wl finalise-migrate 'SP3YXRZYQZYJ7T8SFJ52YXNSEW7JFSGP6FDMCGCDP))
    (try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.migrate-legacy-v2-wl finalise-migrate 'SP3J74X9NVB4FRG1KQJBCZWCEY0JNJJD61G66M30Q))
    (try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.migrate-legacy-v2-wl finalise-migrate 'SP21F9X20AXC2KFVSGXHZVZHQ1T7PR2P7WAYYB78E))
    
    (ok true)
  )
)


```
