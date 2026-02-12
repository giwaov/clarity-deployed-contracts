(define-fungible-token interoperable-security-token)

(define-data-var total-supply uint u0)

(define-map balances {account: principal, partition-id: uint} uint)
(define-map locked-balances {account: principal, partition-id: uint} {amount: uint, release-time: uint})
(define-map transfer-restrictions {partition-id: uint} bool)
(define-map frozen-addresses principal bool)

(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-frozen (err u101))
(define-constant err-restricted (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-locked (err u104))

(define-read-only (get-balance (account principal) (partition-id uint))
  (default-to u0 (map-get? balances {account: account, partition-id: partition-id})))

(define-read-only (transferable-balance (account principal) (partition-id uint))
  (let ((total (get-balance account partition-id))
        (locked-info (map-get? locked-balances {account: account, partition-id: partition-id})))
    (match locked-info
      info (if (>= stacks-block-time (get release-time info))
             total
             (- total (get amount info)))
      total)))

(define-read-only (locked-balance-of (account principal) (partition-id uint))
  (match (map-get? locked-balances {account: account, partition-id: partition-id})
    info (if (< stacks-block-time (get release-time info))
           (get amount info)
           u0)
    u0))

(define-read-only (can-transfer (from principal) (to principal) (partition-id uint) (amount uint))
  (and (not (is-frozen from))
       (not (is-frozen to))
       (not (is-restricted partition-id))
       (>= (transferable-balance from partition-id) amount)))

(define-read-only (is-frozen (account principal))
  (default-to false (map-get? frozen-addresses account)))

(define-read-only (is-restricted (partition-id uint))
  (default-to false (map-get? transfer-restrictions {partition-id: partition-id})))

(define-public (mint (account principal) (partition-id uint) (amount uint))
  (let ((current-balance (get-balance account partition-id)))
    (asserts! (is-eq tx-sender contract-owner) err-not-owner)
    (try! (ft-mint? interoperable-security-token amount account))
    (map-set balances {account: account, partition-id: partition-id} (+ current-balance amount))
    (var-set total-supply (+ (var-get total-supply) amount))
    (ok true)))

(define-public (transfer (amount uint) (sender principal) (recipient principal) (partition-id uint))
  (let ((sender-balance (get-balance sender partition-id))
        (recipient-balance (get-balance recipient partition-id)))
    (asserts! (is-eq tx-sender sender) err-not-owner)
    (asserts! (can-transfer sender recipient partition-id amount) err-restricted)
    (asserts! (>= (transferable-balance sender partition-id) amount) err-locked)
    (try! (ft-transfer? interoperable-security-token amount sender recipient))
    (map-set balances {account: sender, partition-id: partition-id} (- sender-balance amount))
    (map-set balances {account: recipient, partition-id: partition-id} (+ recipient-balance amount))
    (ok true)))

(define-public (lock-tokens (account principal) (partition-id uint) (amount uint) (release-time uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-owner)
    (map-set locked-balances {account: account, partition-id: partition-id} 
      {amount: amount, release-time: release-time})
    (ok true)))

(define-public (restrict-transfer (partition-id uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-owner)
    (map-set transfer-restrictions {partition-id: partition-id} true)
    (ok true)))

(define-public (remove-restriction (partition-id uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-owner)
    (map-set transfer-restrictions {partition-id: partition-id} false)
    (ok true)))

(define-public (freeze-address (account principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-owner)
    (map-set frozen-addresses account true)
    (ok true)))

(define-public (unfreeze-address (account principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-owner)
    (map-set frozen-addresses account false)
    (ok true)))

(define-public (forced-transfer (from principal) (to principal) (partition-id uint) (amount uint))
  (let ((from-balance (get-balance from partition-id))
        (to-balance (get-balance to partition-id)))
    (asserts! (is-eq tx-sender contract-owner) err-not-owner)
    (try! (ft-transfer? interoperable-security-token amount from to))
    (map-set balances {account: from, partition-id: partition-id} (- from-balance amount))
    (map-set balances {account: to, partition-id: partition-id} (+ to-balance amount))
    (ok true)))

(define-read-only (get-total-supply)
  (ok (var-get total-supply)))

(define-read-only (get-contract-hash)
  (contract-hash? .interoperable-security-token))

(define-read-only (get-block-time)
  stacks-block-time)
