(impl-trait .sip-010-trait.sip-010-trait)

;; Defines the hBTC token according to the SIP010 Standard
(define-fungible-token st-hBTC-v6)

(define-constant ERR_NOT_AUTHORIZED (err u4))
(define-constant token-decimals u8)

;;-------------------------------------
;; Const and vars
;;-------------------------------------

(define-constant token-symbol "hBTC")

(define-data-var token-name (string-ascii 32) "hBTC alpha")
(define-data-var token-uri (string-utf8 256) u"https://assets.hermetica.fi/hbtc_alpha.json")
(define-data-var blacklist-enabled bool false)

;;-------------------------------------
;; SIP-010
;;-------------------------------------

(define-read-only (get-total-supply)
  (ok (ft-get-supply st-hBTC-v6))
)

(define-read-only (get-name)
  (ok (var-get token-name))
)

(define-read-only (get-symbol)
  (ok token-symbol)
)

(define-read-only (get-decimals)
  (ok token-decimals)
)

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance st-hBTC-v6 account))
)

(define-read-only (get-token-uri)
  (ok (some (var-get token-uri)))
)

(define-read-only (get-blacklist-enabled)
  (var-get blacklist-enabled)
)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (or (is-eq sender tx-sender) (is-eq sender contract-caller)) ERR_NOT_AUTHORIZED)

    (if (var-get blacklist-enabled)
      (try! (contract-call? .test-blacklist-vaults-v7 check-is-not-full-two sender recipient))
      true
    )

    (try! (ft-transfer? st-hBTC-v6 amount sender recipient))
    (match memo val (print val) 0x)
    (print { action: "transfer", data: { sender: sender, recipient: recipient, amount: amount, block-height: stacks-block-height } })
    (ok true)
  )
)

;;-------------------------------------
;; Admin
;;-------------------------------------

(define-public (set-token-name (value (string-ascii 32)))
  (begin
    (try! (contract-call? .test-hq-vaults-v7 check-is-owner contract-caller))
    (ok (var-set token-name value))
  )
)

(define-public (set-token-uri (value (string-utf8 256)))
  (begin
    (try! (contract-call? .test-hq-vaults-v7 check-is-owner contract-caller))
    (ok (var-set token-uri value))
  )
)

(define-public (set-blacklist-enabled (enabled bool))
  (begin
    (try! (contract-call? .test-hq-vaults-v7 check-is-owner contract-caller))
    (print { action: "set-blacklist-enabled", user: contract-caller, data: { old: (get-blacklist-enabled), new: enabled } })
    (ok (var-set blacklist-enabled enabled))
  )
)

;;-------------------------------------
;; Mint / Burn
;;-------------------------------------

;; Mint method
(define-public (mint-for-protocol (amount uint) (recipient principal))
  (begin
    (try! (contract-call? .test-hq-vaults-v7 check-is-protocol contract-caller))
    (ft-mint? st-hBTC-v6 amount recipient)
  )
)

;; Burn method
(define-public (burn-for-protocol (amount uint) (sender principal))
  (begin
    (try! (contract-call? .test-hq-vaults-v7 check-is-protocol contract-caller))
    (ft-burn? st-hBTC-v6 amount sender)
  )
)

;;-------------------------------------
;; Initialization
;;-------------------------------------

;; Initialize token distribution at deployment
(ft-mint? st-hBTC-v6 u188921 'SP3BJG7SYZ8PEYGC6FCKMCMMW1CRRE3PBY2JV04C7)
(ft-mint? st-hBTC-v6 u116051 'SP6XGBDAD800GGY6XF48AC27467W9PEHA6EPBGKJ)
(ft-mint? st-hBTC-v6 u72651 'SP35SFZ11SRC9TB8PN8T1EQS4KT78BD4CBW27TMKG)
(ft-mint? st-hBTC-v6 u31870 'SP20JY0K64XFTAE7XZK2ZEFEA28EP249EM9VZEMP7)
(ft-mint? st-hBTC-v6 u2802 'SP3PVW0VNNFPBTT76MPJHC4AM175EZ0XBFAAPBQ1Y)
(ft-mint? st-hBTC-v6 u1997 'SP3DYSKV87G6X8VXQ1E2C2TBED5NBK89K1NYAF3PS)
(ft-mint? st-hBTC-v6 u999 'SP3RY185H0R8TNX4PGRYFZ07AV001N23N1FJX9MEE)
(ft-mint? st-hBTC-v6 u100 'SP2WS9QFNR8VMJZY6VWWFZNPKN7ZTVP746BMXJF7A)
(ft-mint? st-hBTC-v6 u100 'SP3TB3AJ0XMZ9S6CGY2CQ6R06H1Z6DJQ1SH15ZP2H)