(define-constant CONTRACT_OWNER tx-sender)

(define-constant ERR_NOT_AUTHORIZED (err u1001))
(define-constant ERR_FACET_NOT_FOUND (err u1002))
(define-constant ERR_SELECTOR_EXISTS (err u1003))
(define-constant ERR_SELECTOR_NOT_FOUND (err u1004))
(define-constant ERR_INVALID_ACTION (err u1005))
(define-constant ERR_IMMUTABLE_FUNCTION (err u1006))
(define-constant ERR_INVALID_FACET (err u1007))
(define-constant ERR_ASSET_RESTRICTED (err u1008))
(define-constant ERR_INVALID_SIGNATURE (err u1009))
(define-constant ERR_DIAMOND_FROZEN (err u1010))

(define-constant ACTION_ADD u0)
(define-constant ACTION_REPLACE u1)
(define-constant ACTION_REMOVE u2)

(define-data-var diamond-owner principal CONTRACT_OWNER)
(define-data-var is-frozen bool false)
(define-data-var assets-restricted bool false)
(define-data-var facet-count uint u0)
(define-data-var selector-count uint u0)
(define-data-var cut-nonce uint u0)

(define-map facets
  principal
  {
    selector-count: uint,
    is-active: bool,
    added-at: uint,
    code-hash: (response (buff 32) uint)
  }
)

(define-map selectors
  (buff 4)
  {
    facet: principal,
    is-immutable: bool,
    added-at: uint
  }
)

(define-map facet-selectors
  { facet: principal, index: uint }
  (buff 4)
)

(define-map immutable-selectors (buff 4) bool)

(define-map pending-cuts
  (buff 32)
  {
    proposer: principal,
    proposed-at: uint,
    executed: bool,
    action: uint,
    facet: principal
  }
)

(define-map authorized-signers principal bool)

(define-private (is-owner)
  (is-eq tx-sender (var-get diamond-owner))
)

(define-private (emit-diamond-cut (action uint) (facet principal) (sel (buff 4)))
  (print { 
    event: "DiamondCut", 
    action: action, 
    facet: facet, 
    selector: sel,
    timestamp: stacks-block-time 
  })
)

(define-read-only (get-facet (facet-addr principal))
  (map-get? facets facet-addr)
)

(define-read-only (get-selector-facet (sel (buff 4)))
  (match (map-get? selectors sel) data (some (get facet data)) none)
)

(define-read-only (facet-address (sel (buff 4)))
  (get-selector-facet sel)
)

(define-read-only (facet-addresses)
  (var-get facet-count)
)

(define-read-only (get-facet-selector (facet principal) (index uint))
  (map-get? facet-selectors { facet: facet, index: index })
)

(define-read-only (is-selector-immutable (sel (buff 4)))
  (default-to false (map-get? immutable-selectors sel))
)

(define-read-only (get-diamond-owner)
  (var-get diamond-owner)
)

(define-read-only (is-diamond-frozen)
  (var-get is-frozen)
)

(define-read-only (get-cut-nonce)
  (var-get cut-nonce)
)

(define-read-only (get-contract-hash)
  (contract-hash? tx-sender)
)

(define-read-only (get-current-time)
  stacks-block-time
)

(define-read-only (check-restrictions)
  (var-get assets-restricted)
)

(define-read-only (verify-cut-signature 
  (cut-hash (buff 32))
  (sig (buff 64))
  (pub-key (buff 33)))
  (secp256r1-verify cut-hash sig pub-key)
)

(define-public (add-facet 
  (facet-addr principal) 
  (sel (buff 4)) 
  (is-immutable bool))
  (begin
    (asserts! (is-owner) ERR_NOT_AUTHORIZED)
    (asserts! (not (var-get is-frozen)) ERR_DIAMOND_FROZEN)
    (asserts! (not (var-get assets-restricted)) ERR_ASSET_RESTRICTED)
    (asserts! (is-none (map-get? selectors sel)) ERR_SELECTOR_EXISTS)
    (match (map-get? facets facet-addr)
      existing
      (map-set facets facet-addr (merge existing { 
        selector-count: (+ (get selector-count existing) u1) 
      }))
      (begin
        (map-set facets facet-addr {
          selector-count: u1,
          is-active: true,
          added-at: stacks-block-time,
          code-hash: (contract-hash? facet-addr)
        })
        (var-set facet-count (+ (var-get facet-count) u1))
      )
    )
    (map-set selectors sel {
      facet: facet-addr,
      is-immutable: is-immutable,
      added-at: stacks-block-time
    })
    (if is-immutable
      (map-set immutable-selectors sel true)
      true
    )
    (var-set selector-count (+ (var-get selector-count) u1))
    (var-set cut-nonce (+ (var-get cut-nonce) u1))
    (emit-diamond-cut ACTION_ADD facet-addr sel)
    (ok true)
  )
)

(define-public (replace-facet 
  (sel (buff 4)) 
  (new-facet principal))
  (let ((selector-data (unwrap! (map-get? selectors sel) ERR_SELECTOR_NOT_FOUND)))
    (asserts! (is-owner) ERR_NOT_AUTHORIZED)
    (asserts! (not (var-get is-frozen)) ERR_DIAMOND_FROZEN)
    (asserts! (not (get is-immutable selector-data)) ERR_IMMUTABLE_FUNCTION)
    (asserts! (not (is-eq (get facet selector-data) new-facet)) ERR_INVALID_FACET)
    (match (map-get? facets new-facet)
      existing
      (map-set facets new-facet (merge existing { 
        selector-count: (+ (get selector-count existing) u1) 
      }))
      (begin
        (map-set facets new-facet {
          selector-count: u1,
          is-active: true,
          added-at: stacks-block-time,
          code-hash: (contract-hash? new-facet)
        })
        (var-set facet-count (+ (var-get facet-count) u1))
      )
    )
    (map-set selectors sel (merge selector-data { 
      facet: new-facet,
      added-at: stacks-block-time
    }))
    (var-set cut-nonce (+ (var-get cut-nonce) u1))
    (emit-diamond-cut ACTION_REPLACE new-facet sel)
    (ok true)
  )
)

(define-public (remove-facet (sel (buff 4)))
  (let ((selector-data (unwrap! (map-get? selectors sel) ERR_SELECTOR_NOT_FOUND)))
    (asserts! (is-owner) ERR_NOT_AUTHORIZED)
    (asserts! (not (var-get is-frozen)) ERR_DIAMOND_FROZEN)
    (asserts! (not (get is-immutable selector-data)) ERR_IMMUTABLE_FUNCTION)
    (map-delete selectors sel)
    (var-set selector-count (- (var-get selector-count) u1))
    (var-set cut-nonce (+ (var-get cut-nonce) u1))
    (emit-diamond-cut ACTION_REMOVE (get facet selector-data) sel)
    (ok true)
  )
)

(define-public (diamond-cut-with-sig
  (action uint)
  (facet-addr principal)
  (sel (buff 4))
  (sig (buff 64))
  (pub-key (buff 33)))
  (let (
    (nonce (var-get cut-nonce))
    (cut-hash (keccak256 (concat (concat sel (unwrap-panic (to-consensus-buff? facet-addr))) (unwrap-panic (to-consensus-buff? nonce)))))
  )
    (asserts! (default-to false (map-get? authorized-signers tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (secp256r1-verify cut-hash sig pub-key) ERR_INVALID_SIGNATURE)
    (if (is-eq action ACTION_ADD)
      (add-facet facet-addr sel false)
      (if (is-eq action ACTION_REPLACE)
        (replace-facet sel facet-addr)
        (if (is-eq action ACTION_REMOVE)
          (remove-facet sel)
          ERR_INVALID_ACTION
        )
      )
    )
  )
)

(define-public (authorize-signer (signer principal))
  (begin
    (asserts! (is-owner) ERR_NOT_AUTHORIZED)
    (map-set authorized-signers signer true)
    (ok true)
  )
)

(define-public (revoke-signer (signer principal))
  (begin
    (asserts! (is-owner) ERR_NOT_AUTHORIZED)
    (map-delete authorized-signers signer)
    (ok true)
  )
)

(define-public (freeze-diamond)
  (begin
    (asserts! (is-owner) ERR_NOT_AUTHORIZED)
    (var-set is-frozen true)
    (print { event: "DiamondFrozen", timestamp: stacks-block-time })
    (ok true)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-owner) ERR_NOT_AUTHORIZED)
    (var-set diamond-owner new-owner)
    (print { event: "OwnershipTransferred", new-owner: new-owner, timestamp: stacks-block-time })
    (ok true)
  )
)

(define-public (set-asset-restriction (restricted bool))
  (begin
    (asserts! (is-owner) ERR_NOT_AUTHORIZED)
    (var-set assets-restricted restricted)
    (ok true)
  )
)

(define-read-only (loupe-facets)
  (var-get facet-count)
)

(define-read-only (loupe-facet-function-selectors (facet-addr principal))
  (match (map-get? facets facet-addr) data (get selector-count data) u0)
)

(define-read-only (supports-interface (interface-id (buff 4)))
  (or 
    (is-eq interface-id 0x1f931c1c)
    (is-eq interface-id 0x48e2b093)
    (is-eq interface-id 0x01ffc9a7)
  )
)

(define-read-only (get-selector-info (sel (buff 4)))
  (map-get? selectors sel)
)

(define-read-only (selector-to-ascii (sel (buff 4)))
  (to-ascii? sel)
)
