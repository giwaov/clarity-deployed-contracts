(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)

(define-map cftc-reports uint {hash: (buff 32), fraud-type: (string-ascii 50), market: (string-ascii 30), potential-fine: uint, timestamp: uint, status: (string-ascii 20)})
(define-map tipsters principal {verified: bool, reports-filed: uint, rewards-earned: uint})
(define-map monetary-sanctions {report-id: uint, tipster: principal} {sanction-amount: uint, reward-percentage: uint, disbursed: bool})
(define-data-var cftc-report-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-cftc-report (report-id uint))
  (map-get? cftc-reports report-id))

(define-read-only (get-tipster (tipster-id principal))
  (map-get? tipsters tipster-id))

(define-read-only (get-monetary-sanction (report-id uint) (tipster principal))
  (map-get? monetary-sanctions {report-id: report-id, tipster: tipster}))

(define-public (file-cftc-report (content-hash (buff 32)) (fraud-type (string-ascii 50)) (market (string-ascii 30)) (potential-fine uint))
  (let ((report-id (+ (var-get cftc-report-count) u1))
        (tipster-data (default-to {verified: false, reports-filed: u0, rewards-earned: u0} (map-get? tipsters tx-sender))))
    (map-set cftc-reports report-id {hash: content-hash, fraud-type: fraud-type, market: market, potential-fine: potential-fine, timestamp: stacks-block-height, status: "filed"})
    (map-set tipsters tx-sender (merge tipster-data {reports-filed: (+ (get reports-filed tipster-data) u1)}))
    (var-set cftc-report-count report-id)
    (ok report-id)))

(define-public (verify-tipster (tipster principal))
  (let ((tipster-data (default-to {verified: false, reports-filed: u0, rewards-earned: u0} (map-get? tipsters tipster))))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set tipsters tipster (merge tipster-data {verified: true})))))

(define-public (update-report-status (report-id uint) (new-status (string-ascii 20)))
  (let ((report (unwrap! (map-get? cftc-reports report-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set cftc-reports report-id (merge report {status: new-status})))))

(define-public (record-monetary-sanction (report-id uint) (tipster principal) (sanction-amount uint) (reward-percentage uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? cftc-reports report-id)) ERR_NOT_FOUND)
    (asserts! (and (> sanction-amount u0) (<= reward-percentage u30)) ERR_INVALID_PARAMS)
    (ok (map-set monetary-sanctions {report-id: report-id, tipster: tipster} {sanction-amount: sanction-amount, reward-percentage: reward-percentage, disbursed: false}))))

(define-public (disburse-reward (report-id uint))
  (let ((sanction (unwrap! (map-get? monetary-sanctions {report-id: report-id, tipster: tx-sender}) ERR_NOT_FOUND))
        (tipster-data (unwrap! (map-get? tipsters tx-sender) ERR_NOT_FOUND))
        (reward-amount (/ (* (get sanction-amount sanction) (get reward-percentage sanction)) u100)))
    (asserts! (not (get disbursed sanction)) ERR_ALREADY_EXISTS)
    (map-set monetary-sanctions {report-id: report-id, tipster: tx-sender} (merge sanction {disbursed: true}))
    (ok (map-set tipsters tx-sender (merge tipster-data {rewards-earned: (+ (get rewards-earned tipster-data) reward-amount)})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
