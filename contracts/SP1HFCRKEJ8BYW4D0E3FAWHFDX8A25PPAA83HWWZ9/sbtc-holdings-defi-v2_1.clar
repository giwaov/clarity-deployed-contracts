;; Backend helper to identify which pools a user has funds in
(define-read-only (get-users-active-defis-at-stacks-block-height
    (stx-block-height uint)
    (user-addresses (list 900 principal))
  )
  (at-block
    (unwrap-panic (get-stacks-block-info? id-header-hash stx-block-height))
    (get-users-active-defis user-addresses)
  )
)

(define-read-only (get-users-active-defis (user-addresses (list 900 principal)))
  (map get-user-active-defis user-addresses)
)

(define-read-only (get-user-active-defis (user-address principal))
  (let (
      (arkadiko (not (is-eq (get-user-sBTC-arkadiko user-address) u0)))
      (based-dollar (not (is-eq (get-user-sBTC-based-dollar user-address) u0)))
      (bitflow (not (is-eq (get-user-sBTC-bitflow user-address) u0)))
      (granite (not (is-eq (get-user-sBTC-granite user-address) u0)))
      (velar (not (is-eq (get-user-sBTC-velar user-address) u0)))
      (zest (not (is-eq (get-user-sBTC-zest user-address) u0)))
    )
    {
      address: user-address,
      arkadiko: arkadiko,
      based: based-dollar,
      bitflow: bitflow,
      granite: granite,
      velar: velar,
      zest: zest,
    }
  )
)

;; Get user balances in all DeFi pools
(define-read-only (get-users-individual-sBTC-in-DeFIs-at-stacks-block-height
    (stx-block-height uint)
    (users (list
      900
      {
        address: principal,
        arkadiko: bool,
        based-dollar: bool,
        bitflow: bool,
        granite: bool,
        velar: bool,
        zest: bool,
      }
    ))
  )
  (at-block
    (unwrap-panic (get-stacks-block-info? id-header-hash stx-block-height))
    (get-users-individual-sBTC-in-DeFIs users)
  )
)

(define-read-only (get-users-individual-sBTC-in-DeFIs (users (list
  900
  {
    address: principal,
    arkadiko: bool,
    based-dollar: bool,
    bitflow: bool,
    granite: bool,
    velar: bool,
    zest: bool,
  }
)))
  (map get-user-individual-sBTC-in-DeFIs users)
)

(define-read-only (get-user-total-sBTC-in-DeFIs (user-address principal))
  (let (
      (arkadiko-sbtc (get-user-sBTC-arkadiko user-address))
      (based-dollar-sbtc (get-user-sBTC-based-dollar user-address))
      (bitflow-sbtc (get-user-sBTC-bitflow user-address))
      (granite-sbtc (get-user-sBTC-granite user-address))
      (velar-sbtc (get-user-sBTC-velar user-address))
      (zest-sbtc (get-user-sBTC-zest user-address))
      (total-sbtc (+ arkadiko-sbtc based-dollar-sbtc bitflow-sbtc granite-sbtc
        velar-sbtc zest-sbtc
      ))
    )
    total-sbtc
  )
)

(define-read-only (get-user-individual-sBTC-in-DeFIs (user {
  address: principal,
  arkadiko: bool,
  based-dollar: bool,
  bitflow: bool,
  granite: bool,
  velar: bool,
  zest: bool,
}))
  (let (
      (user-address (get address user))
      (arkadiko-sbtc (if (get arkadiko user)
        (get-user-sBTC-arkadiko user-address)
        u0
      ))
      (based-dollar-sbtc (if (get based-dollar user)
        (get-user-sBTC-based-dollar user-address)
        u0
      ))
      (bitflow-sbtc (if (get bitflow user)
        (get-user-sBTC-bitflow user-address)
        u0
      ))
      (granite-sbtc (if (get granite user)
        (get-user-sBTC-granite user-address)
        u0
      ))
      (velar-sbtc (if (get velar user)
        (get-user-sBTC-velar user-address)
        u0
      ))
      (zest-sbtc (if (get zest user)
        (get-user-sBTC-zest user-address)
        u0
      ))
      (total-sbtc (+ arkadiko-sbtc based-dollar-sbtc bitflow-sbtc granite-sbtc
        velar-sbtc zest-sbtc
      ))
    )
    {
      address: user-address,
      arkadiko: arkadiko-sbtc,
      based-dollar: based-dollar-sbtc,
      bitflow: bitflow-sbtc,
      granite: granite-sbtc,
      velar: velar-sbtc,
      zest: zest-sbtc,
      total: total-sbtc,
    }
  )
)

(define-read-only (get-user-sBTC-arkadiko (user principal))
  (let ((vault (unwrap!
      (contract-call?
        'SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.arkadiko-vaults-data-v1-1
        get-vault user
        'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
      )
      u0
    )))
    (get collateral vault)
  )
)

(define-read-only (get-user-sBTC-based-dollar (user principal))
  (let ((user-vaults (unwrap!
      (unwrap!
        (contract-call?
          'SPYY08XK8YG4W9B1WSYBM8HD0WBQ1E1WRXEGSENS.registry-v1-0
          get-vaults-by-principal user
        )
        u0
      )
      u0
    )))
    (unwrap!
      (fold calculate-user-sbtc-equivalent-balance-in-based-dollar
        user-vaults (ok u0)
      )
      u0
    )
  )
)

(define-private (calculate-user-sbtc-equivalent-balance-in-based-dollar
    (vault-id uint)
    (sbtc-response (response uint uint))
  )
  (match sbtc-response
    aggregate-sbtc (let (
        (vault-info (unwrap-panic (contract-call?
          'SPYY08XK8YG4W9B1WSYBM8HD0WBQ1E1WRXEGSENS.registry-v1-0
          get-vault-compounded-info vault-id u1
        )))
        (vault-total-sbtc (get vault-total-collateral vault-info))
      )
      (ok (+ aggregate-sbtc vault-total-sbtc))
    )
    err-resp (ok u0)
  )
)

(define-read-only (get-user-sBTC-bitflow (user principal))
  (+
    (unwrap!
      (contract-call?
        'SPQC38PW542EQJ5M11CR25P7BS1CA6QT4TBXGB3M.xyk-sbtc-reader-pool-21-v-1-2
        get-user-sbtc-balance user
      )
      u0
    )
    (unwrap!
      (contract-call?
        'SPQC38PW542EQJ5M11CR25P7BS1CA6QT4TBXGB3M.xyk-sbtc-reader-pool-22-v-1-2
        get-user-sbtc-balance user
      )
      u0
    )
    (unwrap!
      (contract-call?
        'SPQC38PW542EQJ5M11CR25P7BS1CA6QT4TBXGB3M.xyk-sbtc-reader-pool-23-v-1-2
        get-user-sbtc-balance user
      )
      u0
    )
    (unwrap!
      (contract-call?
        'SPQC38PW542EQJ5M11CR25P7BS1CA6QT4TBXGB3M.stableswap-sbtc-reader-pool-2-v-1-2
        get-user-sbtc-balance user
      )
      u0
    ))
)

(define-read-only (get-user-sBTC-granite (user principal))
  (default-to u0
    (get amount
      (contract-call?
        'SP35E2BBMDT2Y1HB0NTK139YBGYV3PAPK3WA8BRNA.state-v1
        get-user-collateral user
        'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
      ))
  )
)

;; TODO: add the logic when integrated
(define-read-only (get-user-sBTC-hermetica (user principal))
  u0
)

(define-read-only (get-user-sBTC-velar (user principal))
  (contract-call?
    'SPFAQ8JFM2GPQDJR1PARSMDSV4D46PSFPN1S53YJ.util-sbtc-wstx
    get-user-sBTC-balance user
    (get end
      (contract-call?
        'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-farming-core-v1_1_1-0070
        get-user-staked user
      ))
  )
)

(define-read-only (get-user-sBTC-zest (user principal))
  (get total
    (unwrap!
      (contract-call?
        'SP1A27KFY4XERQCCRCARCYD1CC5N7M6688BSYADJ7.protocol-data
        get-user-sbtc-balances user
      )
      u0
    )
  )
)
