;; SPDX-License-Identifier: BUSL-1.1

(impl-trait 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.proposal-trait.proposal-trait)

(define-public (execute (sender principal))
  (begin
    ;; Finalise migration for the following addresses
    (try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.migrate-legacy-v2-wl finalise-migrate 'SP1N68Q6DTKMVDRG5F4Z9E0SX2QF192496J64CNSH))
    (try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.migrate-legacy-v2-wl finalise-migrate 'SP2JEJ2NREBJ1XNBKY0Z1NCY3RDEKFY7MP3QFW79X))
    (try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.migrate-legacy-v2-wl finalise-migrate 'SP2TDB7YB9F5C9EMRY8Y3PFPKSA71VW4Z8JW5XM89))
    (try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.migrate-legacy-v2-wl finalise-migrate 'SPY6NANZGZD8THNBGSQ2BN4EZM2Y25408X8249H))
    (try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.migrate-legacy-v2-wl finalise-migrate 'SP97YYKS6JW20A6RYKTNT3CTFCKX4NQYT6396039))
    (try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.migrate-legacy-v2-wl finalise-migrate 'SP2N4WGPGJ1KAR0TGB6XMGMDNM1274EPQEX48APKH))
    (try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.migrate-legacy-v2-wl finalise-migrate 'SPMMFD0R5BTH6P7YT9W8T8ZDAK6F9Q4G7XNGDK0C))
    (try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.migrate-legacy-v2-wl finalise-migrate 'SP2Q03CCZ5E0YQSH1FHMBR428638EPANZ1AHZ6D5Q))
    (try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.migrate-legacy-v2-wl finalise-migrate 'SPNVZTEEV6V02P6A9KF5N6S6NA7FXTX2BMRRTF9))
    
    (ok true)
  )
)

