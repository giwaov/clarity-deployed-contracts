---
title: "Trait ip-registry"
draft: true
---
```
;; IP Registry - Clarity 4
;; Register and license intellectual property

(define-constant contract-owner tx-sender)
(define-constant err-already-registered (err u8000))
(define-constant err-not-found (err u8001))
(define-constant err-unauthorized (err u8002))

(define-data-var ip-nonce uint u0)

(define-map intellectual-property
    uint
    {
        creator: principal,
        title: (string-utf8 100),
        description: (string-utf8 500),
        ipfs-hash: (string-ascii 64),
        registered-at: uint,
        license-type: (string-ascii 20),
        royalty-percent: uint
    }
)

(define-map ip-licenses
    {ip-id: uint, licensee: principal}
    {granted-at: uint, expires-at: uint, fee-paid: uint}
)

(define-map creator-ips principal (list 50 uint))

(define-read-only (get-ip (ip-id uint))
    (map-get? intellectual-property ip-id)
)

(define-read-only (get-license (ip-id uint) (licensee principal))
    (map-get? ip-licenses {ip-id: ip-id, licensee: licensee})
)

(define-read-only (has-valid-license (ip-id uint) (licensee principal))
    (match (get-license ip-id licensee)
        license
        (>= (get expires-at license) stacks-block-height)
        false
    )
)

(define-public (register-ip
    (title (string-utf8 100))
    (description (string-utf8 500))
    (ipfs-hash (string-ascii 64))
    (license-type (string-ascii 20))
    (royalty-percent uint)
)
    (let (
        (ip-id (var-get ip-nonce))
        (creator-list (default-to (list) (map-get? creator-ips tx-sender)))
    )
        (map-set intellectual-property ip-id {
            creator: tx-sender,
            title: title,
            description: description,
            ipfs-hash: ipfs-hash,
            registered-at: stacks-block-height,
            license-type: license-type,
            royalty-percent: royalty-percent
        })
        
        (map-set creator-ips tx-sender
            (unwrap-panic (as-max-len? (append creator-list ip-id) u50))
        )
        (var-set ip-nonce (+ ip-id u1))
        (ok ip-id)
    )
)

(define-public (purchase-license (ip-id uint) (duration-blocks uint))
    (let (
        (ip (unwrap! (get-ip ip-id) err-not-found))
        (license-fee u1000000) ;; 1 STX base
        (royalty (/ (* license-fee (get royalty-percent ip)) u100))
    )
        (try! (stx-transfer? license-fee tx-sender (get creator ip)))
        
        (ok (map-set ip-licenses {ip-id: ip-id, licensee: tx-sender}
            {
                granted-at: stacks-block-height,
                expires-at: (+ stacks-block-height duration-blocks),
                fee-paid: license-fee
            }
        ))
    )
)

(define-public (transfer-ownership (ip-id uint) (new-owner principal))
    (let (
        (ip (unwrap! (get-ip ip-id) err-not-found))
    )
        (asserts! (is-eq tx-sender (get creator ip)) err-unauthorized)
        (ok (map-set intellectual-property ip-id 
            (merge ip {creator: new-owner})
        ))
    )
)

```
