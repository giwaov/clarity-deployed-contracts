---
title: "Trait biud-resolver-v3"
draft: true
---
```
;; =============================================================================
;; BiUD Sample Resolver Contract
;; =============================================================================
;;
;; This is an example resolver that can be used with BiUD names.
;; It implements the resolver-trait and stores simple address mappings.
;;
;; Usage:
;; 1. Deploy this contract
;; 2. Owner of a BiUD name calls set-resolver on biud-username to point here
;; 3. Anyone can then resolve the name to get the stored data
;;
;; =============================================================================

;; Import the resolver trait from the main contract
(impl-trait .biud-username-v3.resolver-trait)

;; =============================================================================
;; CONSTANTS
;; =============================================================================

(define-constant ERR_NOT_OWNER (err u2001))
(define-constant ERR_NOT_FOUND (err u2002))

;; =============================================================================
;; DATA MAPS
;; =============================================================================

;; Store address mappings for each label
;; The owner of a BiUD name can set their resolved address here
(define-map address-records
  { label: (string-utf8 32) }
  { 
    stx-address: (optional principal),
    btc-address: (optional (buff 64)),
    custom-data: (optional (buff 64))
  }
)

;; =============================================================================
;; PUBLIC FUNCTIONS
;; =============================================================================

;; Required by resolver-trait: resolve a label
;; Returns the BTC address or custom data as a buff
(define-public (resolve (label (string-utf8 32)) (name-owner principal))
  (let
    (
      (record (map-get? address-records { label: label }))
    )
    (match record
      data (ok (get btc-address data))
      (ok none)
    )
  )
)

;; Set the STX address for a name (only name owner can call)
(define-public (set-stx-address (label (string-utf8 32)) (address principal))
  (let
    (
      (name-owner (unwrap! (contract-call? .biud-username-v3 get-owner label) ERR_NOT_FOUND))
    )
    ;; Only the name owner can set records
    (asserts! (is-eq tx-sender name-owner) ERR_NOT_OWNER)
    
    (let
      (
        (existing (default-to 
          { stx-address: none, btc-address: none, custom-data: none }
          (map-get? address-records { label: label })
        ))
      )
      (map-set address-records
        { label: label }
        (merge existing { stx-address: (some address) })
      )
    )
    
    (ok true)
  )
)

;; Set the BTC address for a name (only name owner can call)
(define-public (set-btc-address (label (string-utf8 32)) (btc-addr (buff 64)))
  (let
    (
      (name-owner (unwrap! (contract-call? .biud-username-v3 get-owner label) ERR_NOT_FOUND))
    )
    ;; Only the name owner can set records
    (asserts! (is-eq tx-sender name-owner) ERR_NOT_OWNER)
    
    (let
      (
        (existing (default-to 
          { stx-address: none, btc-address: none, custom-data: none }
          (map-get? address-records { label: label })
        ))
      )
      (map-set address-records
        { label: label }
        (merge existing { btc-address: (some btc-addr) })
      )
    )
    
    (ok true)
  )
)

;; Set custom data for a name (only name owner can call)
(define-public (set-custom-data (label (string-utf8 32)) (data (buff 64)))
  (let
    (
      (name-owner (unwrap! (contract-call? .biud-username-v3 get-owner label) ERR_NOT_FOUND))
    )
    ;; Only the name owner can set records
    (asserts! (is-eq tx-sender name-owner) ERR_NOT_OWNER)
    
    (let
      (
        (existing (default-to 
          { stx-address: none, btc-address: none, custom-data: none }
          (map-get? address-records { label: label })
        ))
      )
      (map-set address-records
        { label: label }
        (merge existing { custom-data: (some data) })
      )
    )
    
    (ok true)
  )
)

;; Clear all records for a name (only name owner can call)
(define-public (clear-records (label (string-utf8 32)))
  (let
    (
      (name-owner (unwrap! (contract-call? .biud-username-v3 get-owner label) ERR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender name-owner) ERR_NOT_OWNER)
    
    (map-delete address-records { label: label })
    (ok true)
  )
)

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

;; Get all records for a label
(define-read-only (get-records (label (string-utf8 32)))
  (map-get? address-records { label: label })
)

;; Get STX address for a label
(define-read-only (get-stx-address (label (string-utf8 32)))
  (match (map-get? address-records { label: label })
    data (get stx-address data)
    none
  )
)

;; Get BTC address for a label
(define-read-only (get-btc-address (label (string-utf8 32)))
  (match (map-get? address-records { label: label })
    data (get btc-address data)
    none
  )
)

;; Get custom data for a label
(define-read-only (get-custom-data (label (string-utf8 32)))
  (match (map-get? address-records { label: label })
    data (get custom-data data)
    none
  )
)

```
