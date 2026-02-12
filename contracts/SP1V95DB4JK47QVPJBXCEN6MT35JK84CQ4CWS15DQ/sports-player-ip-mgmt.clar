(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-IP-NOT-FOUND (err u101))
(define-constant ERR-LICENSE-NOT-FOUND (err u102))

(define-map player-ip-rights
  { ip-id: uint }
  {
    player-name: (string-ascii 100),
    sport: (string-ascii 30),
    ip-type: (string-ascii 50),
    description: (string-ascii 200),
    owner: principal,
    registered-at: uint,
    active: bool
  }
)

(define-map ip-licenses
  { license-id: uint }
  {
    ip-id: uint,
    licensee: principal,
    license-type: (string-ascii 50),
    royalty-rate: uint,
    start-date: uint,
    end-date: uint,
    active: bool
  }
)

(define-map royalty-payments
  { ip-id: uint, payment-id: uint }
  {
    licensee: principal,
    amount: uint,
    payment-date: uint
  }
)

(define-data-var ip-nonce uint u0)
(define-data-var license-nonce uint u0)

(define-public (register-ip
  (player-name (string-ascii 100))
  (sport (string-ascii 30))
  (ip-type (string-ascii 50))
  (description (string-ascii 200))
)
  (let ((ip-id (var-get ip-nonce)))
    (map-set player-ip-rights
      { ip-id: ip-id }
      {
        player-name: player-name,
        sport: sport,
        ip-type: ip-type,
        description: description,
        owner: tx-sender,
        registered-at: stacks-block-height,
        active: true
      }
    )
    (var-set ip-nonce (+ ip-id u1))
    (ok ip-id)
  )
)

(define-public (grant-license
  (ip-id uint)
  (licensee principal)
  (license-type (string-ascii 50))
  (royalty-rate uint)
  (duration uint)
)
  (let (
    (ip (unwrap! (map-get? player-ip-rights { ip-id: ip-id }) ERR-IP-NOT-FOUND))
    (license-id (var-get license-nonce))
  )
    (asserts! (is-eq tx-sender (get owner ip)) ERR-NOT-AUTHORIZED)
    (map-set ip-licenses
      { license-id: license-id }
      {
        ip-id: ip-id,
        licensee: licensee,
        license-type: license-type,
        royalty-rate: royalty-rate,
        start-date: stacks-block-height,
        end-date: (+ stacks-block-height duration),
        active: true
      }
    )
    (var-set license-nonce (+ license-id u1))
    (ok license-id)
  )
)

(define-public (record-royalty-payment (ip-id uint) (payment-id uint) (licensee principal) (amount uint))
  (let ((ip (unwrap! (map-get? player-ip-rights { ip-id: ip-id }) ERR-IP-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get owner ip)) ERR-NOT-AUTHORIZED)
    (ok (map-set royalty-payments
      { ip-id: ip-id, payment-id: payment-id }
      {
        licensee: licensee,
        amount: amount,
        payment-date: stacks-block-height
      }
    ))
  )
)

(define-public (revoke-license (license-id uint))
  (let (
    (license (unwrap! (map-get? ip-licenses { license-id: license-id }) ERR-LICENSE-NOT-FOUND))
    (ip (unwrap! (map-get? player-ip-rights { ip-id: (get ip-id license) }) ERR-IP-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get owner ip)) ERR-NOT-AUTHORIZED)
    (ok (map-set ip-licenses
      { license-id: license-id }
      (merge license { active: false })
    ))
  )
)

(define-read-only (get-ip-info (ip-id uint))
  (map-get? player-ip-rights { ip-id: ip-id })
)

(define-read-only (get-license-info (license-id uint))
  (map-get? ip-licenses { license-id: license-id })
)

(define-read-only (get-royalty-payment (ip-id uint) (payment-id uint))
  (map-get? royalty-payments { ip-id: ip-id, payment-id: payment-id })
)
