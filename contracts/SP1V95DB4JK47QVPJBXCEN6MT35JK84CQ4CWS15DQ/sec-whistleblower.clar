(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)

(define-map sec-tips uint {hash: (buff 32), violation-type: (string-ascii 50), potential-recovery: uint, timestamp: uint, reward-eligible: bool, status: (string-ascii 20)})
(define-map whistleblowers principal {verified: bool, tip-count: uint, total-rewards: uint})
(define-map reward-claims {tip-id: uint, whistleblower: principal} {amount: uint, approved: bool, paid: bool})
(define-data-var tip-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-sec-tip (tip-id uint))
  (map-get? sec-tips tip-id))

(define-read-only (get-whistleblower (whistleblower-id principal))
  (map-get? whistleblowers whistleblower-id))

(define-read-only (get-reward-claim (tip-id uint) (whistleblower principal))
  (map-get? reward-claims {tip-id: tip-id, whistleblower: whistleblower}))

(define-public (submit-sec-tip (content-hash (buff 32)) (violation-type (string-ascii 50)) (potential-recovery uint))
  (let ((tip-id (+ (var-get tip-count) u1))
        (whistleblower-data (default-to {verified: false, tip-count: u0, total-rewards: u0} (map-get? whistleblowers tx-sender))))
    (map-set sec-tips tip-id {hash: content-hash, violation-type: violation-type, potential-recovery: potential-recovery, timestamp: stacks-block-height, reward-eligible: true, status: "submitted"})
    (map-set whistleblowers tx-sender (merge whistleblower-data {tip-count: (+ (get tip-count whistleblower-data) u1)}))
    (var-set tip-count tip-id)
    (ok tip-id)))

(define-public (verify-whistleblower (whistleblower principal))
  (let ((whistleblower-data (default-to {verified: false, tip-count: u0, total-rewards: u0} (map-get? whistleblowers whistleblower))))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set whistleblowers whistleblower (merge whistleblower-data {verified: true})))))

(define-public (update-tip-status (tip-id uint) (new-status (string-ascii 20)))
  (let ((tip (unwrap! (map-get? sec-tips tip-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set sec-tips tip-id (merge tip {status: new-status})))))

(define-public (approve-reward (tip-id uint) (whistleblower principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? sec-tips tip-id)) ERR_NOT_FOUND)
    (asserts! (> amount u0) ERR_INVALID_PARAMS)
    (ok (map-set reward-claims {tip-id: tip-id, whistleblower: whistleblower} {amount: amount, approved: true, paid: false}))))

(define-public (claim-reward (tip-id uint))
  (let ((claim (unwrap! (map-get? reward-claims {tip-id: tip-id, whistleblower: tx-sender}) ERR_NOT_FOUND))
        (whistleblower-data (unwrap! (map-get? whistleblowers tx-sender) ERR_NOT_FOUND)))
    (asserts! (get approved claim) ERR_UNAUTHORIZED)
    (asserts! (not (get paid claim)) ERR_ALREADY_EXISTS)
    (map-set reward-claims {tip-id: tip-id, whistleblower: tx-sender} (merge claim {paid: true}))
    (ok (map-set whistleblowers tx-sender (merge whistleblower-data {total-rewards: (+ (get total-rewards whistleblower-data) (get amount claim))})))))

(define-public (set-reward-eligibility (tip-id uint) (eligible bool))
  (let ((tip (unwrap! (map-get? sec-tips tip-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set sec-tips tip-id (merge tip {reward-eligible: eligible})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
