;; ============================================
;; CONTRACT #2: ZERLIN TRANSACTION TEMPLATES
;; ============================================
;; Stores pre-calculated gas costs for common Stacks operations
;; Essential templates only for MVP

;; ============================================
;; ERROR CODES
;; ============================================
(define-constant ERR-UNAUTHORIZED (err u200))
(define-constant ERR-TEMPLATE-NOT-FOUND (err u201))
(define-constant ERR-INVALID-GAS (err u202))
(define-constant ERR-TEMPLATE-EXISTS (err u203))

;; ============================================
;; DATA VARIABLES
;; ============================================
(define-data-var contract-owner principal tx-sender)
(define-data-var fee-oracle-contract principal tx-sender)
(define-data-var total-templates uint u0)

;; ============================================
;; DATA MAPS
;; ============================================

(define-map transaction-templates
  { template-id: (string-ascii 30) }
  {
    avg-gas-units: uint,
    avg-size-bytes: uint,
    description: (string-ascii 100),
    category: (string-ascii 20),
    last-updated: uint,
    sample-count: uint
  }
)

(define-map category-counts
  { category: (string-ascii 20) }
  { count: uint }
)

;; ============================================
;; INITIALIZATION
;; ============================================

(define-public (initialize-templates)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    
    ;; Essential templates for MVP
    (let (
      (t1 (add-template "stx-transfer" u180 u1000 "Simple STX transfer" "transfer"))
      (t2 (add-template "stx-transfer-memo" u250 u1200 "STX transfer with memo" "transfer"))
      (t3 (add-template "ft-transfer" u300 u2500 "Fungible token transfer" "token"))
      (t4 (add-template "ft-mint" u500 u3000 "Mint FT" "token"))
      (t5 (add-template "ft-burn" u400 u2000 "Burn FT" "token"))
      (t6 (add-template "nft-mint" u450 u5500 "Mint NFT" "nft"))
      (t7 (add-template "nft-transfer" u400 u4000 "Transfer NFT" "nft"))
      (t8 (add-template "nft-mint-metadata" u800 u8000 "Mint NFT with metadata" "nft"))
      (t9 (add-template "nft-list-marketplace" u600 u5000 "List NFT on marketplace" "nft"))
      (t10 (add-template "dex-swap-alex" u500 u3950 "Token swap on ALEX" "dex"))
      (t11 (add-template "dex-swap-bitflow" u550 u4200 "Swap on Bitflow" "dex"))
      (t12 (add-template "dex-swap-velar" u500 u4000 "Swap on Velar" "dex"))
      (t13 (add-template "dex-add-liquidity" u600 u5000 "Add liquidity" "dex"))
      (t14 (add-template "dex-remove-liquidity" u550 u4500 "Remove liquidity" "dex"))
      (t15 (add-template "sbtc-peg-in" u700 u8000 "sBTC peg-in (BTC->sBTC)" "sbtc"))
      (t16 (add-template "sbtc-peg-out" u750 u8500 "sBTC peg-out (sBTC->BTC)" "sbtc"))
      (t17 (add-template "sbtc-transfer" u300 u2800 "Transfer sBTC" "sbtc"))
      (t18 (add-template "defi-lend" u600 u7000 "Lend assets" "defi"))
      (t19 (add-template "defi-borrow" u650 u7500 "Borrow assets" "defi"))
      (t20 (add-template "defi-repay" u550 u6500 "Repay loan" "defi"))
      (t21 (add-template "defi-stake" u450 u5000 "Stake tokens" "defi"))
      (t22 (add-template "defi-unstake" u450 u5000 "Unstake tokens" "defi"))
      (t23 (add-template "multisig-submit" u1000 u5000 "Submit multisig tx" "multisig"))
      (t24 (add-template "multisig-confirm" u500 u3000 "Confirm multisig tx" "multisig"))
      (t25 (add-template "multisig-revoke" u500 u3000 "Revoke multisig tx" "multisig"))
      (t26 (add-template "contract-deploy-small" u20000 u150000 "Deploy contract 1-10KB" "contract"))
      (t27 (add-template "contract-deploy-medium" u50000 u400000 "Deploy medium contract" "contract"))
      (t28 (add-template "bns-preorder" u300 u2000 "Preorder BNS name" "bns"))
      (t29 (add-template "bns-register" u400 u4000 "Register BNS name" "bns"))
      (t30 (add-template "bns-update" u300 u2000 "Update BNS name" "bns"))
      (t31 (add-template "pox-stack" u500 u6000 "Stack STX" "pox"))
    )
      (print { event: "templates-initialized", count: (var-get total-templates) })
      (ok true)
    )
  )
)

(define-private (add-template
  (template-id (string-ascii 30))
  (size-bytes uint)
  (gas-units uint)
  (description (string-ascii 100))
  (category (string-ascii 20))
)
  (begin
    (map-set transaction-templates
      { template-id: template-id }
      {
        avg-gas-units: gas-units,
        avg-size-bytes: size-bytes,
        description: description,
        category: category,
        last-updated: stacks-block-height,
        sample-count: u1
      }
    )
    (map-set category-counts
      { category: category }
      { count: (+ (default-to u0 (get count (map-get? category-counts { category: category }))) u1) }
    )
    (var-set total-templates (+ (var-get total-templates) u1))
    true
  )
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

(define-read-only (get-template (template-id (string-ascii 30)))
  (map-get? transaction-templates { template-id: template-id })
)

(define-read-only (get-template-gas (template-id (string-ascii 30)))
  (match (get-template template-id)
    template-data (ok (get avg-gas-units template-data))
    ERR-TEMPLATE-NOT-FOUND
  )
)

(define-read-only (get-template-size (template-id (string-ascii 30)))
  (match (get-template template-id)
    template-data (ok (get avg-size-bytes template-data))
    ERR-TEMPLATE-NOT-FOUND
  )
)

(define-read-only (estimate-fee-for-template 
  (template-id (string-ascii 30))
  (fee-rate-per-byte uint)
)
  (match (get-template template-id)
    template-data (ok (* (get avg-size-bytes template-data) fee-rate-per-byte))
    ERR-TEMPLATE-NOT-FOUND
  )
)

(define-read-only (get-full-estimate (template-id (string-ascii 30)))
  (match (get-template template-id)
    template-data 
      (ok {
        template: template-id,
        gas-units: (get avg-gas-units template-data),
        size-bytes: (get avg-size-bytes template-data),
        description: (get description template-data),
        category: (get category template-data),
        estimated-fee-micro-stx: (* (get avg-size-bytes template-data) u2)
      })
    ERR-TEMPLATE-NOT-FOUND
  )
)

(define-read-only (get-total-templates)
  (ok (var-get total-templates))
)

;; ============================================
;; WRITE FUNCTIONS
;; ============================================

(define-public (update-template
  (template-id (string-ascii 30))
  (new-size-bytes uint)
  (new-gas-units uint)
)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (> new-gas-units u0) ERR-INVALID-GAS)
    (asserts! (> new-size-bytes u0) ERR-INVALID-GAS)
    
    (match (get-template template-id)
      existing (let (
        (old-gas (get avg-gas-units existing))
        (old-size (get avg-size-bytes existing))
        (old-count (get sample-count existing))
        (new-count (+ old-count u1))
        (new-avg-gas (/ (+ (* old-gas old-count) new-gas-units) new-count))
        (new-avg-size (/ (+ (* old-size old-count) new-size-bytes) new-count))
      )
        (map-set transaction-templates
          { template-id: template-id }
          {
            avg-gas-units: new-avg-gas,
            avg-size-bytes: new-avg-size,
            description: (get description existing),
            category: (get category existing),
            last-updated: stacks-block-height,
            sample-count: new-count
          }
        )
        (print { event: "template-updated", template: template-id, samples: new-count })
        (ok true)
      )
      ERR-TEMPLATE-NOT-FOUND
    )
  )
)

(define-public (create-template
  (template-id (string-ascii 30))
  (size-bytes uint)
  (gas-units uint)
  (description (string-ascii 100))
  (category (string-ascii 20))
)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (> gas-units u0) ERR-INVALID-GAS)
    (asserts! (> size-bytes u0) ERR-INVALID-GAS)
    (asserts! (is-none (get-template template-id)) ERR-TEMPLATE-EXISTS)
    
    (map-set transaction-templates
      { template-id: template-id }
      {
        avg-gas-units: gas-units,
        avg-size-bytes: size-bytes,
        description: description,
        category: category,
        last-updated: stacks-block-height,
        sample-count: u1
      }
    )
    
    (map-set category-counts
      { category: category }
      { count: (+ (default-to u0 (get count (map-get? category-counts { category: category }))) u1) }
    )

    (var-set total-templates (+ (var-get total-templates) u1))
    (print { event: "template-created", template: template-id })
    (ok true)
  )
)

;; ============================================
;; ADMIN FUNCTIONS
;; ============================================

(define-public (set-fee-oracle (oracle-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (var-set fee-oracle-contract oracle-address)
    (print { event: "fee-oracle-set", oracle: oracle-address })
    (ok true)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (print { event: "ownership-transferred", new-owner: new-owner })
    (ok true)
  )
)

;; ============================================
;; BATCH & UTILITY FUNCTIONS
;; ============================================

(define-read-only (get-category-count (category (string-ascii 20)))
  (ok (default-to u0 (get count (map-get? category-counts { category: category }))))
)

(define-private (batch-update-helper (update (tuple (template-id (string-ascii 30)) (size-bytes uint) (gas-units uint))))
  (match (update-template (get template-id update) (get size-bytes update) (get gas-units update))
    success true
    error false
  )
)

(define-public (batch-update-templates (updates (list 10 (tuple (template-id (string-ascii 30)) (size-bytes uint) (gas-units uint)))))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (ok (map batch-update-helper updates))
  )
)

(define-read-only (compare-templates (t1-id (string-ascii 30)) (t2-id (string-ascii 30)))
  (let (
    (t1 (unwrap! (get-template t1-id) ERR-TEMPLATE-NOT-FOUND))
    (t2 (unwrap! (get-template t2-id) ERR-TEMPLATE-NOT-FOUND))
    (g1 (get avg-gas-units t1))
    (g2 (get avg-gas-units t2))
    (s1 (get avg-size-bytes t1))
    (s2 (get avg-size-bytes t2))
  )
    (ok {
      template-1: t1-id,
      gas-1: g1,
      size-1: s1,
      template-2: t2-id,
      gas-2: g2,
      size-2: s2,
      cheaper: (if (< g1 g2) t1-id t2-id)
    })
  )
)

(define-read-only (get-cheapest-dex-swap)
  (let (
    (alex (get-template-gas "dex-swap-alex"))
    (bitflow (get-template-gas "dex-swap-bitflow"))
    (g-alex (match alex val val err u99999999))
    (g-bitflow (match bitflow val val err u99999999))
  )
    (if (< g-alex g-bitflow)
      (ok "dex-swap-alex")
      (ok "dex-swap-bitflow")
    )
  )
)

(define-read-only (get-sbtc-operations)
  (ok {
    peg-in: (get-template "sbtc-peg-in"),
    peg-out: (get-template "sbtc-peg-out"),
    transfer: (get-template "sbtc-transfer")
  })
)

(define-read-only (get-defi-lending-operations)
  (ok {
    lend: (get-template "defi-lend"),
    borrow: (get-template "defi-borrow"),
    repay: (get-template "defi-repay")
  })
)
