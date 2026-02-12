(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))

(define-data-var registry-nonce uint u0)

(define-map ip-registrations
  uint
  {
    owner: principal,
    ip-category: (string-ascii 30),
    content-fingerprint: (buff 32),
    metadata-uri: (string-ascii 100),
    registration-timestamp: uint,
    verified: bool,
    transferable: bool
  }
)

(define-map ip-ownership-history
  {ip-id: uint, transfer-id: uint}
  {
    from: principal,
    to: principal,
    transfer-block: uint,
    price: uint
  }
)

(define-map ip-usage-rights
  {ip-id: uint, licensee: principal}
  {
    usage-scope: (string-ascii 50),
    granted-at: uint,
    expires-at: uint,
    fee-paid: uint,
    active: bool
  }
)

(define-map owner-ips principal (list 100 uint))
(define-map transfer-count uint uint)

(define-public (register-ip (ip-category (string-ascii 30)) (content-fingerprint (buff 32)) (metadata-uri (string-ascii 100)) (transferable bool))
  (let
    (
      (ip-id (+ (var-get registry-nonce) u1))
    )
    (map-set ip-registrations ip-id
      {
        owner: tx-sender,
        ip-category: ip-category,
        content-fingerprint: content-fingerprint,
        metadata-uri: metadata-uri,
        registration-timestamp: stacks-block-height,
        verified: false,
        transferable: transferable
      }
    )
    (map-set transfer-count ip-id u0)
    (map-set owner-ips tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? owner-ips tx-sender)) ip-id) u100)))
    (var-set registry-nonce ip-id)
    (ok ip-id)
  )
)

(define-public (transfer-ip (ip-id uint) (new-owner principal) (price uint))
  (let
    (
      (ip (unwrap! (map-get? ip-registrations ip-id) err-not-found))
      (transfer-id (+ (default-to u0 (map-get? transfer-count ip-id)) u1))
    )
    (asserts! (is-eq tx-sender (get owner ip)) err-unauthorized)
    (asserts! (get transferable ip) err-unauthorized)
    (asserts! (> price u0) err-invalid-amount)
    (try! (stx-transfer? price new-owner tx-sender))
    (map-set ip-registrations ip-id (merge ip {owner: new-owner}))
    (map-set ip-ownership-history {ip-id: ip-id, transfer-id: transfer-id}
      {
        from: tx-sender,
        to: new-owner,
        transfer-block: stacks-block-height,
        price: price
      }
    )
    (map-set transfer-count ip-id transfer-id)
    (map-set owner-ips new-owner
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? owner-ips new-owner)) ip-id) u100)))
    (ok true)
  )
)

(define-public (grant-usage-rights (ip-id uint) (licensee principal) (usage-scope (string-ascii 50)) (duration-blocks uint) (fee uint))
  (let
    (
      (ip (unwrap! (map-get? ip-registrations ip-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get owner ip)) err-unauthorized)
    (asserts! (> fee u0) err-invalid-amount)
    (asserts! (is-none (map-get? ip-usage-rights {ip-id: ip-id, licensee: licensee})) err-already-exists)
    (try! (stx-transfer? fee licensee tx-sender))
    (map-set ip-usage-rights {ip-id: ip-id, licensee: licensee}
      {
        usage-scope: usage-scope,
        granted-at: stacks-block-height,
        expires-at: (+ stacks-block-height duration-blocks),
        fee-paid: fee,
        active: true
      }
    )
    (ok true)
  )
)

(define-public (revoke-usage-rights (ip-id uint) (licensee principal))
  (let
    (
      (ip (unwrap! (map-get? ip-registrations ip-id) err-not-found))
      (rights (unwrap! (map-get? ip-usage-rights {ip-id: ip-id, licensee: licensee}) err-not-found))
    )
    (asserts! (is-eq tx-sender (get owner ip)) err-unauthorized)
    (map-set ip-usage-rights {ip-id: ip-id, licensee: licensee} (merge rights {active: false}))
    (ok true)
  )
)

(define-public (verify-ip (ip-id uint))
  (let
    (
      (ip (unwrap! (map-get? ip-registrations ip-id) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set ip-registrations ip-id (merge ip {verified: true}))
    (ok true)
  )
)

(define-read-only (get-ip (ip-id uint))
  (ok (map-get? ip-registrations ip-id))
)

(define-read-only (get-ownership-history (ip-id uint) (transfer-id uint))
  (ok (map-get? ip-ownership-history {ip-id: ip-id, transfer-id: transfer-id}))
)

(define-read-only (get-usage-rights (ip-id uint) (licensee principal))
  (ok (map-get? ip-usage-rights {ip-id: ip-id, licensee: licensee}))
)

(define-read-only (get-owner-ips (owner principal))
  (ok (map-get? owner-ips owner))
)
