---
title: "Trait name-registry"
draft: true
---
```
;; Stacks Name Service (SNS)
;; Decentralized naming system for Stacks - register .stx domains

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-name-taken (err u101))
(define-constant err-name-not-found (err u102))
(define-constant err-not-name-owner (err u103))
(define-constant err-name-expired (err u104))
(define-constant err-invalid-name (err u105))
(define-constant err-insufficient-payment (err u106))
(define-constant err-name-too-short (err u107))
(define-constant err-name-too-long (err u108))

;; Pricing (in microSTX)
(define-constant price-1-char u100000000000) ;; 100000 STX for 1 char
(define-constant price-2-char u10000000000)  ;; 10000 STX for 2 chars
(define-constant price-3-char u1000000000)   ;; 1000 STX for 3 chars
(define-constant price-4-char u100000000)    ;; 100 STX for 4 chars
(define-constant price-5-plus u10000000)     ;; 10 STX for 5+ chars

;; Registration period: ~1 year in blocks (assuming 10 min blocks)
(define-constant registration-period u52560)

;; Treasury
(define-constant treasury 'SP2PEBKJ2W1ZDDF2QQ6Y4FXKZEDPT9J9R2NKD9WJB)

;; Data Variables
(define-data-var total-registrations uint u0)
(define-data-var total-revenue uint u0)

;; Name Registry
(define-map names (string-ascii 64)
  {
    owner: principal,
    resolver: principal,
    registered-at: uint,
    expires-at: uint,
    records: (optional (string-utf8 256))
  }
)

;; Reverse lookup: principal -> primary name
(define-map primary-names principal (string-ascii 64))

;; Name ownership count
(define-map name-counts principal uint)

;; Read-only functions
(define-read-only (get-name-info (name (string-ascii 64)))
  (map-get? names name)
)

(define-read-only (get-owner (name (string-ascii 64)))
  (match (map-get? names name)
    info (some (get owner info))
    none
  )
)

(define-read-only (get-resolver (name (string-ascii 64)))
  (match (map-get? names name)
    info (some (get resolver info))
    none
  )
)

(define-read-only (is-available (name (string-ascii 64)))
  (match (map-get? names name)
    info (> stacks-block-height (get expires-at info))
    true
  )
)

(define-read-only (get-primary-name (owner principal))
  (map-get? primary-names owner)
)

(define-read-only (get-name-count (owner principal))
  (default-to u0 (map-get? name-counts owner))
)

(define-read-only (get-price (name (string-ascii 64)))
  (let ((len (len name)))
    (if (is-eq len u1) price-1-char
      (if (is-eq len u2) price-2-char
        (if (is-eq len u3) price-3-char
          (if (is-eq len u4) price-4-char
            price-5-plus
          )
        )
      )
    )
  )
)

(define-read-only (get-expiry (name (string-ascii 64)))
  (match (map-get? names name)
    info (some (get expires-at info))
    none
  )
)

(define-read-only (is-expired (name (string-ascii 64)))
  (match (map-get? names name)
    info (> stacks-block-height (get expires-at info))
    true
  )
)

(define-read-only (get-stats)
  {
    total-registrations: (var-get total-registrations),
    total-revenue: (var-get total-revenue),
    current-block: stacks-block-height
  }
)

;; Public functions

;; Register a new name
(define-public (register (name (string-ascii 64)))
  (let (
    (price (get-price name))
    (name-len (len name))
  )
    ;; Validate name
    (asserts! (>= name-len u1) err-name-too-short)
    (asserts! (<= name-len u64) err-name-too-long)
    (asserts! (is-available name) err-name-taken)
    (asserts! (>= (stx-get-balance tx-sender) price) err-insufficient-payment)
    
    ;; Transfer payment
    (try! (stx-transfer? price tx-sender treasury))
    
    ;; Register name
    (map-set names name {
      owner: tx-sender,
      resolver: tx-sender,
      registered-at: stacks-block-height,
      expires-at: (+ stacks-block-height registration-period),
      records: none
    })
    
    ;; Update primary name if first name
    (if (is-eq (get-name-count tx-sender) u0)
      (map-set primary-names tx-sender name)
      true
    )
    
    ;; Update counts
    (map-set name-counts tx-sender (+ (get-name-count tx-sender) u1))
    (var-set total-registrations (+ (var-get total-registrations) u1))
    (var-set total-revenue (+ (var-get total-revenue) price))
    
    (ok { name: name, expires-at: (+ stacks-block-height registration-period), price: price })
  )
)

;; Renew a name
(define-public (renew (name (string-ascii 64)))
  (match (map-get? names name)
    info
    (let ((price (get-price name)))
      (asserts! (is-eq (get owner info) tx-sender) err-not-name-owner)
      (asserts! (>= (stx-get-balance tx-sender) price) err-insufficient-payment)
      
      ;; Transfer payment
      (try! (stx-transfer? price tx-sender treasury))
      
      ;; Extend expiry
      (map-set names name 
        (merge info { expires-at: (+ (get expires-at info) registration-period) })
      )
      
      (var-set total-revenue (+ (var-get total-revenue) price))
      
      (ok { name: name, new-expiry: (+ (get expires-at info) registration-period) })
    )
    err-name-not-found
  )
)

;; Transfer name to new owner
(define-public (transfer (name (string-ascii 64)) (new-owner principal))
  (match (map-get? names name)
    info
    (begin
      (asserts! (is-eq (get owner info) tx-sender) err-not-name-owner)
      (asserts! (not (is-expired name)) err-name-expired)
      
      ;; Update ownership
      (map-set names name (merge info { owner: new-owner }))
      
      ;; Update name counts
      (map-set name-counts tx-sender (- (get-name-count tx-sender) u1))
      (map-set name-counts new-owner (+ (get-name-count new-owner) u1))
      
      ;; Update primary name for new owner if they don't have one
      (if (is-eq (get-name-count new-owner) u1)
        (map-set primary-names new-owner name)
        true
      )
      
      ;; Clear primary name if it was transferred
      (match (map-get? primary-names tx-sender)
        primary (if (is-eq primary name) (map-delete primary-names tx-sender) false)
        false
      )
      
      (ok { name: name, new-owner: new-owner })
    )
    err-name-not-found
  )
)

;; Set resolver address
(define-public (set-resolver (name (string-ascii 64)) (resolver principal))
  (match (map-get? names name)
    info
    (begin
      (asserts! (is-eq (get owner info) tx-sender) err-not-name-owner)
      (asserts! (not (is-expired name)) err-name-expired)
      
      (map-set names name (merge info { resolver: resolver }))
      (ok true)
    )
    err-name-not-found
  )
)

;; Set records (IPFS hash, website, etc.)
(define-public (set-records (name (string-ascii 64)) (records (string-utf8 256)))
  (match (map-get? names name)
    info
    (begin
      (asserts! (is-eq (get owner info) tx-sender) err-not-name-owner)
      (asserts! (not (is-expired name)) err-name-expired)
      
      (map-set names name (merge info { records: (some records) }))
      (ok true)
    )
    err-name-not-found
  )
)

;; Set primary name
(define-public (set-primary-name (name (string-ascii 64)))
  (match (map-get? names name)
    info
    (begin
      (asserts! (is-eq (get owner info) tx-sender) err-not-name-owner)
      (asserts! (not (is-expired name)) err-name-expired)
      
      (map-set primary-names tx-sender name)
      (ok true)
    )
    err-name-not-found
  )
)


```
