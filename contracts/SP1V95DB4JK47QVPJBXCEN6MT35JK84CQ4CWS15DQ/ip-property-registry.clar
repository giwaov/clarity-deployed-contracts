(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))

(define-data-var ip-nonce uint u0)

(define-map intellectual-property
  uint
  {
    creator: principal,
    ip-type: (string-ascii 30),
    content-hash: (buff 32),
    metadata-hash: (buff 32),
    registration-block: uint,
    verified: bool,
    license-type: (string-ascii 20),
    royalty-rate: uint
  }
)

(define-map ip-licenses
  {ip-id: uint, licensee: principal}
  {
    license-start: uint,
    license-end: uint,
    license-fee: uint,
    active: bool
  }
)

(define-map ip-disputes
  {ip-id: uint, dispute-id: uint}
  {
    claimant: principal,
    dispute-reason: (string-ascii 60),
    evidence-hash: (buff 32),
    resolved: bool,
    resolution: (optional (string-ascii 20))
  }
)

(define-map creator-ips principal (list 100 uint))
(define-map ip-royalties uint uint)

(define-public (register-ip (ip-type (string-ascii 30)) (content-hash (buff 32)) (metadata-hash (buff 32)) (license-type (string-ascii 20)) (royalty-rate uint))
  (let
    (
      (ip-id (+ (var-get ip-nonce) u1))
    )
    (asserts! (<= royalty-rate u10000) err-invalid-amount)
    (map-set intellectual-property ip-id
      {
        creator: tx-sender,
        ip-type: ip-type,
        content-hash: content-hash,
        metadata-hash: metadata-hash,
        registration-block: stacks-block-height,
        verified: false,
        license-type: license-type,
        royalty-rate: royalty-rate
      }
    )
    (map-set ip-royalties ip-id u0)
    (map-set creator-ips tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? creator-ips tx-sender)) ip-id) u100)))
    (var-set ip-nonce ip-id)
    (ok ip-id)
  )
)

(define-public (purchase-license (ip-id uint) (duration-blocks uint) (license-fee uint))
  (let
    (
      (ip (unwrap! (map-get? intellectual-property ip-id) err-not-found))
    )
    (asserts! (get verified ip) err-not-found)
    (asserts! (> license-fee u0) err-invalid-amount)
    (asserts! (is-none (map-get? ip-licenses {ip-id: ip-id, licensee: tx-sender})) err-already-exists)
    (try! (stx-transfer? license-fee tx-sender (get creator ip)))
    (map-set ip-licenses {ip-id: ip-id, licensee: tx-sender}
      {
        license-start: stacks-block-height,
        license-end: (+ stacks-block-height duration-blocks),
        license-fee: license-fee,
        active: true
      }
    )
    (map-set ip-royalties ip-id
      (+ (default-to u0 (map-get? ip-royalties ip-id)) license-fee))
    (ok true)
  )
)

(define-public (verify-ip (ip-id uint))
  (let
    (
      (ip (unwrap! (map-get? intellectual-property ip-id) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set intellectual-property ip-id (merge ip {verified: true}))
    (ok true)
  )
)

(define-public (revoke-license (ip-id uint) (licensee principal))
  (let
    (
      (ip (unwrap! (map-get? intellectual-property ip-id) err-not-found))
      (license (unwrap! (map-get? ip-licenses {ip-id: ip-id, licensee: licensee}) err-not-found))
    )
    (asserts! (is-eq tx-sender (get creator ip)) err-unauthorized)
    (map-set ip-licenses {ip-id: ip-id, licensee: licensee} (merge license {active: false}))
    (ok true)
  )
)

(define-read-only (get-ip (ip-id uint))
  (ok (map-get? intellectual-property ip-id))
)

(define-read-only (get-license (ip-id uint) (licensee principal))
  (ok (map-get? ip-licenses {ip-id: ip-id, licensee: licensee}))
)

(define-read-only (get-creator-ips (creator principal))
  (ok (map-get? creator-ips creator))
)

(define-read-only (get-ip-royalties (ip-id uint))
  (ok (map-get? ip-royalties ip-id))
)
