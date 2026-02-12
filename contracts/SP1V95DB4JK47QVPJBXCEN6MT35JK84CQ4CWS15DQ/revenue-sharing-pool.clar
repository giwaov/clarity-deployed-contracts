(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u1300))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1301))
(define-constant ERR_ZERO_AMOUNT (err u1302))

(define-fungible-token revenue-share-token)

(define-data-var total-revenue uint u0)
(define-data-var total-snapshots uint u0)
(define-data-var last-snapshot-time uint u0)

(define-map snapshot-revenue
  uint
  uint
)

(define-map snapshot-supply
  uint
  uint
)

(define-map user-claimed-snapshots
  {user: principal, snapshot-id: uint}
  bool
)

(define-map user-balances-at-snapshot
  {user: principal, snapshot-id: uint}
  uint
)

(define-read-only (get-contract-hash)
  (contract-hash? .revenue-sharing-pool)
)

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance revenue-share-token account))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply revenue-share-token))
)

(define-read-only (get-claimable-revenue (account principal))
  (let
    (
      (snapshot-id (var-get total-snapshots))
      (balance-at-snapshot (default-to u0 (map-get? user-balances-at-snapshot {user: account, snapshot-id: snapshot-id})))
      (total-supply-at-snapshot (default-to u1 (map-get? snapshot-supply snapshot-id)))
      (revenue-at-snapshot (default-to u0 (map-get? snapshot-revenue snapshot-id)))
    )
    (if (and (> balance-at-snapshot u0) (> total-supply-at-snapshot u0))
      (ok (/ (* revenue-at-snapshot balance-at-snapshot) total-supply-at-snapshot))
      (ok u0)
    )
  )
)

(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (ft-mint? revenue-share-token amount recipient)
  )
)

(define-public (transfer (amount uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_NOT_AUTHORIZED)
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (ft-transfer? revenue-share-token amount sender recipient)
  )
)

(define-public (burn (amount uint))
  (begin
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (ft-burn? revenue-share-token amount tx-sender)
  )
)

(define-public (add-revenue (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (var-set total-revenue (+ (var-get total-revenue) amount))
    (ok true)
  )
)

(define-public (snapshot)
  (let
    (
      (snapshot-id (+ (var-get total-snapshots) u1))
      (current-supply (ft-get-supply revenue-share-token))
      (current-revenue (var-get total-revenue))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set snapshot-revenue snapshot-id current-revenue)
    (map-set snapshot-supply snapshot-id current-supply)
    (var-set total-snapshots snapshot-id)
    (var-set last-snapshot-time stacks-block-time)
    (ok snapshot-id)
  )
)

(define-public (claim (snapshot-id uint))
  (let
    (
      (already-claimed (default-to false (map-get? user-claimed-snapshots {user: tx-sender, snapshot-id: snapshot-id})))
      (balance-at-snapshot (default-to u0 (map-get? user-balances-at-snapshot {user: tx-sender, snapshot-id: snapshot-id})))
      (total-supply-at-snapshot (default-to u1 (map-get? snapshot-supply snapshot-id)))
      (revenue-at-snapshot (default-to u0 (map-get? snapshot-revenue snapshot-id)))
      (claimable (if (> balance-at-snapshot u0)
        (/ (* revenue-at-snapshot balance-at-snapshot) total-supply-at-snapshot)
        u0))
    )
    (asserts! (not already-claimed) ERR_NOT_AUTHORIZED)
    (asserts! (> claimable u0) ERR_ZERO_AMOUNT)
    (map-set user-claimed-snapshots {user: tx-sender, snapshot-id: snapshot-id} true)
    (try! (stx-transfer? claimable CONTRACT_OWNER tx-sender))
    (ok claimable)
  )
)

(define-public (record-balance-at-snapshot (user principal) (snapshot-id uint))
  (let
    (
      (balance (ft-get-balance revenue-share-token user))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set user-balances-at-snapshot {user: user, snapshot-id: snapshot-id} balance)
    (ok true)
  )
)

(define-read-only (redeemable-on-burn (amount uint))
  (let
    (
      (total-supply (ft-get-supply revenue-share-token))
      (total-rev (var-get total-revenue))
    )
    (if (> total-supply u0)
      (ok (/ (* total-rev amount) total-supply))
      (ok u0)
    )
  )
)

(define-read-only (verify-signature (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (ok (secp256r1-verify message signature public-key))
)

(define-read-only (get-time)
  stacks-block-time
)
