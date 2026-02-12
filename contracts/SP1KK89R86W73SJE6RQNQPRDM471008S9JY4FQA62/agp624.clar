;; SPDX-License-Identifier: BUSL-1.1

(impl-trait 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.proposal-trait.proposal-trait)
(use-trait ft-trait 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.trait-sip-010.sip-010-trait)

(define-public (execute (sender principal))
	(let (
		;; Get balance from legacy treasury-grant
		(legacy-balance (unwrap-panic (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex get-balance-fixed 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.treasury-grant)))
		;; Get balance from treasury-grant-v3
		(v3-balance (unwrap-panic (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex get-balance-fixed 'SP1E0XBN9T4B10E9QMR7XMFJPMA19D77WY3KP2QKC.treasury-grant-v3))))
		
		;; Transfer from legacy treasury-grant if balance > 0
		(if (> legacy-balance u0)
			(try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.treasury-grant transfer-fixed 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex legacy-balance tx-sender))
			true)
		
		;; Transfer from treasury-grant-v3 if balance > 0
		(if (> v3-balance u0)
			(try! (contract-call? 'SP1E0XBN9T4B10E9QMR7XMFJPMA19D77WY3KP2QKC.treasury-grant-v3 transfer-token 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex v3-balance tx-sender))
			true)
		
		;; Get the ALEX balance of tx-sender after receiving from both contracts
		(let (
			(final-balance (unwrap-panic (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex get-balance-fixed tx-sender))))
			
			;; Transfer the entire balance to the final recipient
			(if (> final-balance u0)
				(try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex transfer-fixed final-balance tx-sender 'SPPGQ7VHF8XEZC2SPZ2KW11KNN19W9G2RX38Y2XE none))
				true)
			
			(print { 
				notification: "agp624-executed",
				legacy-balance: legacy-balance,
				v3-balance: v3-balance,
				total-collected: (+ legacy-balance v3-balance),
				final-balance: final-balance,
				final-recipient: 'SPPGQ7VHF8XEZC2SPZ2KW11KNN19W9G2RX38Y2XE
			})
			
			(ok true))))

