(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-invalid-amount (err u102))

(define-fungible-token liquid-stx)

(define-data-var total-staked uint u0)
(define-data-var total-rewards uint u0)
(define-data-var exchange-rate uint u1000000)

(define-map staker-info principal {staked: uint, rewards: uint})

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance liquid-stx account)))

(define-read-only (get-total-staked)
  (ok (var-get total-staked)))

(define-read-only (get-exchange-rate)
  (ok (var-get exchange-rate)))

(define-read-only (get-staker-info (staker principal))
  (ok (map-get? staker-info staker)))

(define-public (stake (amount uint))
  (let ((lstx-amount (/ (* amount u1000000) (var-get exchange-rate))))
    (asserts! (> amount u0) err-invalid-amount)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (try! (ft-mint? liquid-stx lstx-amount tx-sender))
    (var-set total-staked (+ (var-get total-staked) amount))
    (ok lstx-amount)))

(define-public (unstake (lstx-amount uint))
  (let ((stx-amount (/ (* lstx-amount (var-get exchange-rate)) u1000000)))
    (asserts! (> lstx-amount u0) err-invalid-amount)
    (try! (ft-burn? liquid-stx lstx-amount tx-sender))
    (try! (stx-transfer? stx-amount tx-sender (as-contract tx-sender)))
    (var-set total-staked (- (var-get total-staked) stx-amount))
    (ok stx-amount)))

(define-public (distribute-rewards (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set total-rewards (+ (var-get total-rewards) amount))
    (var-set exchange-rate
      (/ (* (+ (var-get total-staked) (var-get total-rewards)) u1000000)
         (var-get total-staked)))
    (ok true)))

(define-public (claim-rewards)
  (let ((info (default-to {staked: u0, rewards: u0} (map-get? staker-info tx-sender))))
    (asserts! (> (get rewards info) u0) err-insufficient-balance)
    (try! (as-contract (stx-transfer? (get rewards info) tx-sender tx-sender)))
    (ok (map-set staker-info tx-sender (merge info {rewards: u0})))))
