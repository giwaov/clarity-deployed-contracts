;; title: cosmetics-v3
;; version: 1.0.0
;; summary: NFT cosmetics-v3 with limited drops tied to achievements.
;; clarity: 4

;; constants
(define-constant contract-version "1.0.0")
(define-constant category-coin u0)
(define-constant category-table u1)
(define-constant category-avatar u2)
(define-constant badge-none u0)
(define-constant status-active true)
(define-constant status-inactive false)
(define-constant min-supply u1)
(define-constant max-supply-limit u10000)
(define-constant err-not-admin (err u900))
(define-constant err-admin-unset (err u901))
(define-constant err-admin-set (err u902))
(define-constant err-paused (err u903))
(define-constant err-admin-locked (err u904))
(define-constant err-invalid-category (err u700))
(define-constant err-supply-low (err u701))
(define-constant err-supply-high (err u702))
(define-constant err-drop-not-found (err u703))
(define-constant err-drop-inactive (err u704))
(define-constant err-sold-out (err u705))
(define-constant err-already-claimed (err u706))
(define-constant err-badge-required (err u707))
(define-constant err-not-owner (err u708))
(define-constant err-insufficient-balance (err u709))
(define-constant err-token-not-found (err u710))
(define-constant err-mint-failed (err u711))
(define-constant err-transfer-failed (err u712))
(define-constant err-signer-unset (err u713))
(define-constant err-invalid-signature (err u714))
(define-constant err-permit-used (err u715))

;; sip-009
(impl-trait .sip009-nft-trait-v3.sip009-nft-trait)
(define-non-fungible-token cosmetic uint)

;; data vars
(define-data-var next-drop-id uint u0)
(define-data-var next-token-id uint u0)
(define-data-var admin (optional principal) none)
(define-data-var paused bool false)
(define-data-var admin-locked bool false)
(define-data-var claim-signer (optional (buff 33)) none)

;; data maps
(define-map drops
  {id: uint}
  {
    id: uint,
    category: uint,
    skin: uint,
    max-supply: uint,
    minted: uint,
    required-badge: uint,
    active: bool
  }
)

(define-map tokens
  {id: uint}
  {
    id: uint,
    owner: principal,
    drop-id: uint,
    category: uint,
    skin: uint
  }
)

(define-map drop-uris
  {drop-id: uint}
  {uri: (string-utf8 256)}
)

(define-map permit-used
  {player: principal, nonce: uint}
  {used: bool}
)

(define-map balances
  {owner: principal}
  {count: uint}
)

(define-map claims
  {drop-id: uint, player: principal}
  {claimed: bool}
)

(define-map badges
  {player: principal, badge: uint}
  {unlocked: bool}
)

;; private helpers
(define-private (assert-admin)
  (match (var-get admin)
    admin-principal (if (is-eq admin-principal tx-sender) (ok true) err-not-admin)
    err-admin-unset))

(define-private (assert-not-paused)
  (if (var-get paused) err-paused (ok true)))

(define-private (assert-category (category uint))
  (if (or (is-eq category category-coin) (is-eq category category-table) (is-eq category category-avatar))
      (ok true)
      err-invalid-category))

(define-private (add-balance (owner principal) (delta uint))
  (let ((current (default-to u0 (get count (map-get? balances {owner: owner})))))
    (map-set balances {owner: owner} {count: (+ current delta)})))

(define-private (sub-balance (owner principal) (delta uint))
  (let ((current (default-to u0 (get count (map-get? balances {owner: owner})))))
    (begin
      (asserts! (>= current delta) err-insufficient-balance)
      (map-set balances {owner: owner} {count: (- current delta)})
      (ok true))))

(define-private (mint-token (recipient principal) (drop-id uint) (drop-data {id: uint, category: uint, skin: uint, max-supply: uint, minted: uint, required-badge: uint, active: bool}))
  (let ((token-id (var-get next-token-id)))
    (begin
      (unwrap! (nft-mint? cosmetic token-id recipient) err-mint-failed)
      (map-set tokens {id: token-id}
        {
          id: token-id,
          owner: recipient,
          drop-id: drop-id,
          category: (get category drop-data),
          skin: (get skin drop-data)
        })
      (add-balance recipient u1)
      (map-set drops {id: drop-id} (merge drop-data {minted: (+ (get minted drop-data) u1)}))
      (var-set next-token-id (+ token-id u1))
      (ok token-id))))

(define-private (permit-hash (drop-id uint) (recipient principal) (nonce uint))
  (let ((payload (unwrap-panic (to-consensus-buff? {contract: (as-contract tx-sender), drop-id: drop-id, recipient: recipient, nonce: nonce}))))
    (sha256 payload)))

;; admin
(define-public (init-admin)
  (begin
    (asserts! (is-none (var-get admin)) err-admin-set)
    (var-set admin (some tx-sender))
    (ok true)))

(define-public (set-admin (new-admin principal))
  (begin
    (unwrap! (assert-admin) err-not-admin)
    (asserts! (not (var-get admin-locked)) err-admin-locked)
    (var-set admin (some new-admin))
    (ok true)))

(define-public (lock-admin)
  (begin
    (unwrap! (assert-admin) err-not-admin)
    (var-set admin-locked true)
    (ok true)))

(define-public (pause)
  (begin
    (unwrap! (assert-admin) err-not-admin)
    (var-set paused true)
    (ok true)))

(define-public (unpause)
  (begin
    (unwrap! (assert-admin) err-not-admin)
    (var-set paused false)
    (ok true)))

(define-public (set-claim-signer (pubkey (buff 33)))
  (begin
    (unwrap! (assert-admin) err-not-admin)
    (var-set claim-signer (some pubkey))
    (ok true)))

(define-public (grant-badge (player principal) (badge uint))
  (begin
    (unwrap! (assert-admin) err-not-admin)
    (map-set badges {player: player, badge: badge} {unlocked: true})
    (ok true)))

;; public functions
(define-public (create-drop (category uint) (skin uint) (max-supply-arg uint) (required-badge uint))
  (begin
    (unwrap! (assert-admin) err-not-admin)
    (unwrap! (assert-not-paused) err-paused)
    (unwrap! (assert-category category) err-invalid-category)
    (asserts! (>= max-supply-arg min-supply) err-supply-low)
    (asserts! (<= max-supply-arg max-supply-limit) err-supply-high)
    (let ((drop-id (var-get next-drop-id)))
      (begin
        (map-set drops {id: drop-id}
          {
            id: drop-id,
            category: category,
            skin: skin,
            max-supply: max-supply-arg,
            minted: u0,
            required-badge: required-badge,
            active: status-active
          })
        (var-set next-drop-id (+ drop-id u1))
        (ok drop-id)))))

(define-public (set-drop-active (drop-id uint) (active bool))
  (let ((drop-data (unwrap! (map-get? drops {id: drop-id}) err-drop-not-found)))
    (begin
      (unwrap! (assert-admin) err-not-admin)
      (map-set drops {id: drop-id} (merge drop-data {active: active}))
      (ok true))))

(define-public (set-drop-uri (drop-id uint) (uri (string-utf8 256)))
  (begin
    (unwrap! (assert-admin) err-not-admin)
    (unwrap! (map-get? drops {id: drop-id}) err-drop-not-found)
    (map-set drop-uris {drop-id: drop-id} {uri: uri})
    (ok true)))

(define-public (claim-drop (drop-id uint))
  (let ((drop-data (unwrap! (map-get? drops {id: drop-id}) err-drop-not-found)))
    (begin
      (unwrap! (assert-not-paused) err-paused)
      (asserts! (is-eq (get active drop-data) status-active) err-drop-inactive)
      (asserts! (< (get minted drop-data) (get max-supply drop-data)) err-sold-out)
      (asserts! (is-none (map-get? claims {drop-id: drop-id, player: tx-sender})) err-already-claimed)
      (if (is-eq (get required-badge drop-data) badge-none)
          true
          (asserts! (is-some (map-get? badges {player: tx-sender, badge: (get required-badge drop-data)})) err-badge-required))
      (map-set claims {drop-id: drop-id, player: tx-sender} {claimed: true})
      (mint-token tx-sender drop-id drop-data))))

(define-public (claim-with-permit (drop-id uint) (nonce uint) (signature (buff 65)))
  (let ((drop-data (unwrap! (map-get? drops {id: drop-id}) err-drop-not-found)))
    (begin
      (unwrap! (assert-not-paused) err-paused)
      (asserts! (is-eq (get active drop-data) status-active) err-drop-inactive)
      (asserts! (< (get minted drop-data) (get max-supply drop-data)) err-sold-out)
      (asserts! (is-none (map-get? claims {drop-id: drop-id, player: tx-sender})) err-already-claimed)
      (asserts! (is-none (map-get? permit-used {player: tx-sender, nonce: nonce})) err-permit-used)
      (let ((signer (var-get claim-signer)))
        (match signer
          pubkey
          (begin
            (asserts! (secp256k1-verify (permit-hash drop-id tx-sender nonce) signature pubkey) err-invalid-signature)
            (map-set permit-used {player: tx-sender, nonce: nonce} {used: true})
            (map-set claims {drop-id: drop-id, player: tx-sender} {claimed: true})
            (mint-token tx-sender drop-id drop-data))
          err-signer-unset)))))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq sender tx-sender) err-not-owner)
    (let ((owner (nft-get-owner? cosmetic token-id)))
      (match owner
        current
        (begin
          (asserts! (is-eq current sender) err-not-owner)
          (unwrap! (nft-transfer? cosmetic token-id sender recipient) err-transfer-failed)
          (unwrap! (sub-balance sender u1) err-insufficient-balance)
          (add-balance recipient u1)
          (let ((token (unwrap! (map-get? tokens {id: token-id}) err-token-not-found)))
            (map-set tokens {id: token-id} (merge token {owner: recipient})))
          (ok true))
        err-token-not-found))))

;; read only functions
(define-read-only (get-next-drop-id)
  (var-get next-drop-id))

(define-read-only (get-next-token-id)
  (var-get next-token-id))

(define-read-only (get-last-token-id)
  (let ((next (var-get next-token-id)))
    (if (is-eq next u0) (ok u0) (ok (- next u1)))))

(define-read-only (get-drop (drop-id uint))
  (map-get? drops {id: drop-id}))

(define-read-only (get-token (token-id uint))
  (map-get? tokens {id: token-id}))

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? cosmetic token-id)))

(define-read-only (get-token-uri (token-id uint))
  (let ((token (map-get? tokens {id: token-id})))
    (match token
      record
      (let ((uri (map-get? drop-uris {drop-id: (get drop-id record)})))
        (match uri
          entry (ok (some (get uri entry)))
          (ok none)))
      (ok none))))

(define-read-only (get-claim (drop-id uint) (player principal))
  (map-get? claims {drop-id: drop-id, player: player}))

(define-read-only (get-badge (player principal) (badge uint))
  (map-get? badges {player: player, badge: badge}))

(define-read-only (get-claim-signer)
  (var-get claim-signer))

(define-read-only (get-balance (owner principal))
  (default-to u0 (get count (map-get? balances {owner: owner}))))

(define-read-only (get-admin)
  (var-get admin))

(define-read-only (is-paused)
  (var-get paused))

(define-read-only (is-admin-locked)
  (var-get admin-locked))

(define-read-only (get-version)
  contract-version)
