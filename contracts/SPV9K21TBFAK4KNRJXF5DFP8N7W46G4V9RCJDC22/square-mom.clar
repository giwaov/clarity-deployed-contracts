;; 2a0e98cfc781129d295c8a7106b37e6e171c23c39cb144bc2c8dd0ce9eb95ee6
;; MOM Powered By Faktory.fun v1.0 
;; square-mom.clar

(impl-trait 'SP3XXMS38VTAWTVPE5682XSBFXPTH7XCPEBTX8AN2.faktory-trait-v1.sip-010-trait)

(define-constant ERR-NOT-AUTHORIZED u401)
(define-constant ERR-NOT-OWNER u402)
(define-constant ERR-SUPPLY-EXCEEDED (err u403))
(define-constant ERR-INSUFFICIENT-BALANCE (err u404))
(define-constant PRECISION u10000)
(define-constant CAPSULE-TREASURY tx-sender) ;; this can be a contract where we swap the asset for sbtc as soon as accumulate amount reaches a treshold?

(define-fungible-token MOM MAX)
(define-constant MAX u1600000000000000000)
(define-data-var contract-owner principal 'SP2Z94F6QX847PMXTPJJ2ZCCN79JZDW3PJ4E6ZABY.fake-token-owner)
(define-data-var token-uri (optional (string-utf8 256)) (some u"https://mkkhfmcrbwyuutcvtier.supabase.co/storage/v1/object/public/tokens//251.json"))

;; Track total burned for withdrawal accounting
(define-data-var total-burned uint u0)
;; U25 can be a var bounded perhaps?

;; SIP-10 Functions
;; Add business model FEE
(define-private (is-contract (addr principal))
  (is-some (get name (unwrap-panic (principal-destruct? addr))))
)

;; Fee only when sending to contracts (DEXes)
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR-NOT-AUTHORIZED))
    (if (is-contract recipient)
      ;; Contract recipient then charge fee
      (let ((capsule-royalty (/ (* u25 amount) PRECISION)))
        (try! (ft-transfer? MOM capsule-royalty sender CAPSULE-TREASURY))
        (match (ft-transfer? MOM (- amount capsule-royalty) sender recipient)
          response (begin (print memo) (ok response))
          error (err error)
        )
      )
      ;; Wallet recipient then no fee
      (match (ft-transfer? MOM amount sender recipient)
        response (begin (print memo) (ok response))
        error (err error)
      )
    )
  )
)

(define-public (set-token-uri (value (string-utf8 256)))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
        (var-set token-uri (some value))
        (ok (print {
              notification: "token-metadata-update",
              payload: {
                contract-id: (as-contract tx-sender),
                token-class: "ft"
              }
            })
        )
    )
)

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance MOM account))
)

(define-read-only (get-name)
  (ok "MOM")
)

(define-read-only (get-symbol)
  (ok "MOM")
)

(define-read-only (get-decimals)
  (ok u0)
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply MOM))
)

(define-read-only (get-token-uri)
    (ok (var-get token-uri))
)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (print {new-owner: new-owner})
    (ok (var-set contract-owner new-owner))
  )
)

;; ---------------------------------------------------------

(define-public (send-many (recipients (list 200 { to: principal, amount: uint, memo: (optional (buff 34)) })))
  (fold check-err (map send-token recipients) (ok true))
)

(define-private (check-err (result (response bool uint)) (prior (response bool uint)))
  (match prior ok-value result err-value (err err-value))
)

(define-private (send-token (recipient { to: principal, amount: uint, memo: (optional (buff 34)) }))
  (send-token-with-memo (get amount recipient) (get to recipient) (get memo recipient))
)

(define-private (send-token-with-memo (amount uint) (to principal) (memo (optional (buff 34))))
  (let ((transferOk (try! (transfer amount tx-sender to memo))))
    (ok transferOk)
  )
)

;; ---------------------------------------------------------

;; (begin 
;;     ;; ft distribution
;;     (try! (ft-mint? MOM (/ (* MAX u80) u100) 'SP2Z94F6QX847PMXTPJJ2ZCCN79JZDW3PJ4E6ZABY.fake-treasury)) ;; 80% treasury
;;     (try! (ft-mint? MOM (/ (* MAX u16) u100) 'SP2Z94F6QX847PMXTPJJ2ZCCN79JZDW3PJ4E6ZABY.fake-faktory-dex))
;;     (try! (ft-mint? MOM (/ (* MAX u4) u100) 'SP2Z94F6QX847PMXTPJJ2ZCCN79JZDW3PJ4E6ZABY.fake-pre-faktory))

;;     (print { 
;;         type: "faktory-trait-v1", 
;;         name: "MOM",
;;         symbol: "MOM",
;;         token-uri: u"https://mkkhfmcrbwyuutcvtier.supabase.co/storage/v1/object/public/tokens//251.json", 
;;         tokenContract: (as-contract tx-sender),
;;         supply: MAX, 
;;         decimals: u8, 
;;         targetStx: u5000000,
;;         tokenToDex: (/ (* MAX u16) u100),
;;         tokenToDeployer: (/ (* MAX u4) u100),
;;         stxToDex: u250000,
;;         stxBuyFirstFee: u150000,
;;     })
;; )

;; ============================================
;; MINT FUNCTION (called by runes-capsule-core)
;; ============================================

(define-public (mint (amount uint) (recipient principal))
  (begin
    ;; Only the Clarity oracle white Owl minter (runes-capsule-core) can mint
    (is-eq contract-caller .runes-capsule)
    
    ;; Check we won't exceed max supply
    (asserts! (<= (+ (ft-get-supply MOM) amount) MAX) ERR-SUPPLY-EXCEEDED)
    
    ;; Mint tokens
    (try! (ft-mint? MOM amount recipient))
    
    (print {
      event: "mint",
      recipient: recipient,
      amount: amount,
      total-supply: (ft-get-supply MOM)
    })
    
    (ok amount)
  )
)

;; ============================================
;; BURN FUNCTION (user signals L1 withdrawal)
;; ============================================

;; User burns tokens to signal withdrawal back to L1
;; The destination-address is the Bitcoin address to receive Runes
(define-public (burn (amount uint) (destination-address (optional (buff 64))))
  (begin
    ;; Must have sufficient balance
    (asserts! (>= (ft-get-balance MOM tx-sender) amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Burn the tokens
    (try! (ft-burn? MOM amount tx-sender))
    
    ;; Track total burned
    (var-set total-burned (+ (var-get total-burned) amount))
    
    ;; Emit withdrawal request event (backend monitors this)
    (print {
      event: "withdrawal-request",
      type: "runes-withdrawal",
      sender: tx-sender,
      amount: amount,
      destination-address: destination-address,
      burn-block: burn-block-height
    })
    
    (ok {
      sender: tx-sender,
      amount: amount,
      destination: destination-address,
      burn-block: burn-block-height
    })
  )
)

;; ============================================
;; INITIALIZATION
;; ============================================
(begin
  (print {
    type: "square-deployment",
    name: "Squared MOMs",
    symbol: "sMOM",
    decimals: u0,
    max-supply: MAX,
    contract: (as-contract tx-sender),
    owls-soul: "S.... Raphael"
  })
)