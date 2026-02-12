---
title: "Trait runes-capsule"
draft: true
---
```
;; runes-capsule.clar
;; Trustless bridge for Runes deposits TO SIP-10 minting ~ Square Runes tokens
;; Verifies BTC deposits to multisig capsules and mints wrapped tokens

;; ============================================
;; TRAITS
;; ============================================
;; create a square runes trait with burn and mint functions
(use-trait sr-trait .square-runes-trait.square-runes-trait) ;; 'SP3XXMS38VTAWTVPE5682XSBFXPTH7XCPEBTX8AN2.faktory-trait-v1.sip-010-trait) 
;; ============================================
;; ERROR CODES
;; ============================================
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-CAPSULE-NOT-FOUND (err u402))
(define-constant ERR-DEPOSIT-ALREADY-PROCESSED (err u403))
(define-constant ERR-RUNE-NOT-SUPPORTED (err u404))
(define-constant ERR-MULTISIG-NOT-FOUND (err u405))
(define-constant ERR-INVALID-AMOUNT (err u406))
(define-constant ERR-MINT-FAILED (err u407))
(define-constant ERR-PARSE-FAILED (err u408))
(define-constant ERR-WRONG-OUTPUT (err u409))
(define-constant ERR-TX-NOT-MINED (err u410))
(define-constant ERR-MULTISIG-VERIFICATION-FAILED (err u411))
(define-constant ERR-MULTISIG-MISMATCH (err u412)) 
(define-constant ERR-PUBKEY-MISMATCH (err u413))

;; ============================================
;; CONSTANTS
;; ============================================
;; set of multiple operators decentralized for liveness and redundancy
(define-constant OPERATOR_PUBKEY 0x024289ad7d50c0be883566d38249d0d644ed0626ce52ea0e1e4a9bdafe6293bc21)

;; Multisig threshold (2-of-2)
(define-constant MULTISIG_THRESHOLD u2)

;; Expected output index for capsule deposits (output 1 = multisig)
(define-constant EXPECTED_MULTISIG_OUTPUT u1)

;; Contract deployer
(define-constant CONTRACT_DEPLOYER tx-sender)

;; ============================================
;; DATA VARS
;; ============================================
(define-data-var contract-owner principal tx-sender)
(define-data-var mom-token-contract principal .square-mom) ;; Set after MOM token deployment

(define-data-var processed-tx-count uint u1)

;; ============================================
;; DATA MAPS
;; ============================================

;; Maps supported Runes to their SIP-10 token contracts
;; Key: { block: uint, tx: uint } TO Value: token contract principal
(define-map supported-runes 
  { block: uint, tx: uint }
  { token-contract: principal, decimals: uint, name: (string-ascii 32) }
)

;; Maps capsule scriptPubKey to owner's Stacks address
;; Key: scriptPubKey (buff 34) TO Value: { owner: principal, registered-at: uint }
(define-map capsule-owners
  (buff 34)
  { owner: principal, registered-at: uint }
)

;; Tracks processed deposits to prevent double-minting
;; Key: btc-tx-id (buff 32) TO Value: deposit details
(define-map processed-btc-txs
  (buff 128)
  { 
    amount: uint,
    capsule-script-pubkey: (buff 34),
    stx-receiver: principal,
    edict-tag: (optional uint),
    edict-output: uint,
    pointer-output: (optional uint),
    rune-block: uint,
    rune-tx: uint,
    tx-number: uint,
    tag: uint,
    btc-height: uint
  }
)

;; ============================================
;; INITIALIZATION
;; ============================================
(begin
  ;; Register MOM's as first supported Rune
  (map-set supported-runes 
    { block: u922359, tx: u1350 }
    { 
      token-contract: .square-mom, 
      decimals: u0,
      name: "MOM"
    }
  )
)

;; ============================================
;; ADMIN FUNCTIONS
;; ============================================

;; no admins, use code-body instead
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (ok (var-set contract-owner new-owner))
  )
)

;; use code-body instead?
(define-public (add-supported-rune 
    (rune-block uint) 
    (rune-tx uint) 
    (token-contract principal)
    (decimals uint)
    (name (string-ascii 32))
  )
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (ok (map-set supported-runes 
      { block: rune-block, tx: rune-tx }
      { token-contract: token-contract, decimals: decimals, name: name }
    ))
  )
)

;; ============================================
;; CAPSULE REGISTRATION
;; ============================================

;; User registers their capsule by proving they control the multisig
;; user-pubkey: the user's compressed pubkey (derived from their Stacks address)
;; capsule-script: the P2WSH scriptPubKey (0x0020 + 32-byte witness program)
(define-public (register-capsule 
    (stx-receiver principal)
    (user-pubkey (buff 33)) 
    (capsule-script (buff 34))
    (is-segwit bool)
  )
  (begin 
      (asserts! (is-eq (principal-of? user-pubkey) (ok stx-receiver)) ERR-PUBKEY-MISMATCH)
        (let (
            ;; Build the pubkey list: [user-pubkey, operator-pubkey]
            (pubkeys (list OPERATOR_PUBKEY user-pubkey))  ;; OPERATOR first
            
            ;; Verify the multisig address matches
            (verification (unwrap! (contract-call? 
                .multisig-verify 
                verify-multisig-address
                pubkeys
                MULTISIG_THRESHOLD
                is-segwit
                (some capsule-script)
            ) ERR-MULTISIG-VERIFICATION-FAILED)))

            (asserts! verification ERR-MULTISIG-MISMATCH)
            ;; Map the capsule scriptPubKey to tx-sender
            (ok (map-set capsule-owners 
            capsule-script
            { owner: stx-receiver, registered-at: burn-block-height } ;; pubkey is not persisted
            ))
  )
))

;; ============================================
;; READ-ONLY HELPERS
;; ============================================

(define-read-only (get-capsule-owner (capsule-script (buff 34)))
  (map-get? capsule-owners capsule-script)
)

(define-read-only (get-supported-rune (rune-block uint) (rune-tx uint))
  (map-get? supported-runes { block: rune-block, tx: rune-tx })
)

(define-read-only (is-deposit-processed (btc-tx-id (buff 128)))
  (is-some (map-get? processed-btc-txs btc-tx-id))
)

(define-read-only (get-deposit-info (btc-tx-id (buff 128)))
  (map-get? processed-btc-txs btc-tx-id)
)

;; ============================================
;; CORE DEPOSIT PROCESSING
;; ============================================

;; Main entry point: Process a Runes deposit with full merkle proof verification
(define-public (process-deposit
    (height uint)
    (wtx {
      version: (buff 4),
      ins: (list 50 { outpoint: { hash: (buff 32), index: (buff 4) }, scriptSig: (buff 1376), sequence: (buff 4) }),
      outs: (list 50 { value: (buff 8), scriptPubKey: (buff 1376) }),
      locktime: (buff 4),
    })
    (witness-data (buff 1650))
    (header (buff 80))
    (tx-index uint)
    (tree-depth uint)
    (wproof (list 14 (buff 32)))
    (witness-merkle-root (buff 32))
    (witness-reserved-value (buff 32))
    (ctx (buff 4096))
    (cproof (list 14 (buff 32)))
    (mom-token <sr-trait>)
  )
  (let (
      ;; Build full tx buffer
      (tx-buff (contract-call?
        'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.bitcoin-helper-wtx-v2
        concat-wtx wtx witness-data
      ))
    )
    ;; Verify tx was mined on Bitcoin
    (match (contract-call?
      'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.clarity-bitcoin-lib-v7
      was-segwit-tx-mined-compact height tx-buff header tx-index tree-depth
      wproof witness-merkle-root witness-reserved-value ctx cproof
    )
      btc-tx-id (process-verified-deposit btc-tx-id tx-buff height mom-token)
      error (err (* error u1000)) ;; ERR-TX-NOT-MINED
    )
  )
)

;; Process deposit after BTC tx is verified as mined
(define-private (process-verified-deposit 
    (btc-tx-id (buff 128))
    (tx-buff (buff 4096))
    (btc-height uint)
    (sq-rune <sr-trait>)
  )
  (begin
    ;; Check not already processed
    (asserts! (is-none (map-get? processed-btc-txs btc-tx-id)) ERR-DEPOSIT-ALREADY-PROCESSED)
    
    ;; Parse the OP_RETURN to get Rune info
    (let (
        (parsed (unwrap! (parse-deposit-opreturn tx-buff) ERR-PARSE-FAILED))
        (amount (get amount parsed))
        (edict-output (unwrap! (get edict-output parsed) ERR-PARSE-FAILED))
        (edict-tag (get edict-tag parsed))
        (pointer-output (get pointer-output parsed))
        (rune-block (get rune-block parsed))
        (rune-tx (get rune-tx parsed))
        (tag (get tag parsed))
      )
      
      ;; Verify this is MOM's or another supported Rune
      (let (
          (rune-info (unwrap! (get-supported-rune rune-block rune-tx) ERR-RUNE-NOT-SUPPORTED))
        )
        
        ;; Verify the output points to the capsule multisig
        (let (
            (multisig-output (unwrap! (get-output-at-index tx-buff edict-output) ERR-MULTISIG-NOT-FOUND))
            (output-script (get scriptPubKey multisig-output))
          )
          
          ;; Get the capsule owner
          (let (
              (capsule-owner-info (unwrap! 
                (get-capsule-owner (unwrap! (as-max-len? output-script u34) ERR-CAPSULE-NOT-FOUND))
                ERR-CAPSULE-NOT-FOUND
              ))
              (owner (get owner capsule-owner-info))
              (current-count (var-get processed-tx-count))
            )
            
            ;; Record the deposit
            (map-set processed-btc-txs btc-tx-id {
              amount: amount,
              capsule-script-pubkey: (unwrap! (as-max-len? output-script u34) ERR-CAPSULE-NOT-FOUND),
              stx-receiver: owner,
              edict-output: edict-output,
              edict-tag: edict-tag,
              pointer-output: pointer-output,
              rune-block: rune-block,
              rune-tx: rune-tx,
              tag: tag,
              btc-height: btc-height,
              tx-number: current-count
            })

            (var-set processed-tx-count (+ current-count u1))

            ;; Mint tokens to the owner
            (try! (contract-call? sq-rune mint amount owner))
            
            ;; Emit event
            (print {
              type: "runes-deposit-processed",
              btc-tx-id: btc-tx-id,
              amount: amount,
              capsule-script-pubkey: (unwrap! (as-max-len? output-script u34) ERR-CAPSULE-NOT-FOUND),
              stx-receiver: owner,
              edict-output: edict-output,
              edict-tag: edict-tag,
              pointer-output: pointer-output,
              rune-block: rune-block,
              rune-tx: rune-tx,
              tag: tag,
              btc-height: btc-height,
              tx-number: current-count
            })
            
            (ok {
              btc-tx-id: btc-tx-id,
              owner: owner,
              amount: amount,
              rune: (get name rune-info)
            })
          )
        )
      )
    )
  )
)

;; ============================================
;; PARSING HELPERS (using runes-decoder)
;; ============================================

;; Parse OP_RETURN from tx buffer using the runes-decoder library
(define-read-only (parse-deposit-opreturn (tx-buff (buff 4096)))
  (let (
      (output0 (unwrap! (get-output-at-index tx-buff u0) (err u500)))
      (script (get scriptPubKey output0))
    )
    ;; decode-any-runestone is more generic - handles Tag 0, 11, 22
    (contract-call? .runes-decoder decode-any-runestone script)
  )
)

;; Get output at specific index from parsed tx
;; is this different for legacy Rafa?
(define-read-only (get-output-at-index (tx (buff 4096)) (index uint))
  (let (
      (parsed-tx (contract-call?
        'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.clarity-bitcoin-lib-v7
        parse-wtx tx false
      ))
    )
    (match parsed-tx
      result (let (
          (outs (get outs result))
          (out (unwrap! (element-at? outs index) (err u502)))
        )
        (ok {
          scriptPubKey: (get scriptPubKey out),
          value: (get value out)
        })
      )
      error (err u503) ;; missing
    )
  )
)

;; ============================================
;; TEST FUNCTION (no merkle proof required)
;; ============================================

;; For testing: process deposit without BTC mining verification
(define-public (test-process-deposit
    (wtx {
      version: (buff 4),
      ins: (list 50 { outpoint: { hash: (buff 32), index: (buff 4) }, scriptSig: (buff 1376), sequence: (buff 4) }),
      outs: (list 50 { value: (buff 8), scriptPubKey: (buff 1376) }),
      locktime: (buff 4),
    })
    (witness-data (buff 1650))
    (mock-btc-tx-id (buff 128))  
    (sq-rune <sr-trait>))    
  (let (
      (tx-buff (contract-call?
        'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.bitcoin-helper-wtx-v2
        concat-wtx wtx witness-data
      ))
    )
    (process-verified-deposit mock-btc-tx-id tx-buff u0 sq-rune)
  )
)

;; Simple test: just parse and log without minting
(define-read-only (test-parse-deposit (tx-buff (buff 4096)))
  (let (
      (parsed (parse-deposit-opreturn tx-buff))
      (output0 (get-output-at-index tx-buff u0))
      (output1 (get-output-at-index tx-buff u1))
    )
    {
      parsed-opreturn: parsed,
      output-0: output0,
      output-1: output1
    }
  )
)

```
