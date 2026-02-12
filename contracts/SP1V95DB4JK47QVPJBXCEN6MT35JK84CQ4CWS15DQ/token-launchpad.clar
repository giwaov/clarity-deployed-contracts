(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))
(define-constant ERR_LAUNCH_ENDED (err u105))

(define-data-var contract-owner principal tx-sender)

(define-map token-launches uint {project-name: (string-utf8 100), token-contract: principal, creator: principal, total-supply: uint, price: uint, raised: uint, start-block: uint, end-block: uint, status: (string-ascii 20)})
(define-map participants {launch-id: uint, participant: principal} {contribution: uint, tokens-allocated: uint, claimed: bool})
(define-map project-kyc {launch-id: uint, participant: principal} {verified: bool, verification-hash: (buff 32)})
(define-map vesting-schedules {launch-id: uint, beneficiary: principal} {total-amount: uint, released: uint, start-block: uint, duration: uint})
(define-data-var launch-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-token-launch (launch-id uint))
  (map-get? token-launches launch-id))

(define-read-only (get-participant (launch-id uint) (participant principal))
  (map-get? participants {launch-id: launch-id, participant: participant}))

(define-read-only (get-kyc-status (launch-id uint) (participant principal))
  (map-get? project-kyc {launch-id: launch-id, participant: participant}))

(define-read-only (get-vesting-schedule (launch-id uint) (beneficiary principal))
  (map-get? vesting-schedules {launch-id: launch-id, beneficiary: beneficiary}))

(define-public (create-launch (project-name (string-utf8 100)) (token-contract principal) (total-supply uint) (price uint) (duration uint))
  (let ((launch-id (+ (var-get launch-count) u1)))
    (asserts! (and (> total-supply u0) (> price u0) (> duration u0)) ERR_INVALID_PARAMS)
    (map-set token-launches launch-id {project-name: project-name, token-contract: token-contract, creator: tx-sender, total-supply: total-supply, price: price, raised: u0, start-block: stacks-block-height, end-block: (+ stacks-block-height duration), status: "active"})
    (var-set launch-count launch-id)
    (ok launch-id)))

(define-public (verify-participant-kyc (launch-id uint) (participant principal) (verification-hash (buff 32)))
  (let ((launch (unwrap! (map-get? token-launches launch-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get creator launch)) ERR_UNAUTHORIZED)
    (ok (map-set project-kyc {launch-id: launch-id, participant: participant} {verified: true, verification-hash: verification-hash}))))

(define-public (participate (launch-id uint) (contribution uint))
  (let ((launch (unwrap! (map-get? token-launches launch-id) ERR_NOT_FOUND))
        (kyc (unwrap! (map-get? project-kyc {launch-id: launch-id, participant: tx-sender}) ERR_UNAUTHORIZED))
        (tokens-allocated (/ contribution (get price launch)))
        (existing-participation (default-to {contribution: u0, tokens-allocated: u0, claimed: false} 
                                             (map-get? participants {launch-id: launch-id, participant: tx-sender}))))
    (asserts! (get verified kyc) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status launch) "active") ERR_INVALID_PARAMS)
    (asserts! (<= stacks-block-height (get end-block launch)) ERR_LAUNCH_ENDED)
    (asserts! (> contribution u0) ERR_INVALID_PARAMS)
    (map-set participants {launch-id: launch-id, participant: tx-sender} 
      {contribution: (+ (get contribution existing-participation) contribution), 
       tokens-allocated: (+ (get tokens-allocated existing-participation) tokens-allocated), 
       claimed: false})
    (ok (map-set token-launches launch-id (merge launch {raised: (+ (get raised launch) contribution)})))))

(define-public (finalize-launch (launch-id uint))
  (let ((launch (unwrap! (map-get? token-launches launch-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get creator launch)) ERR_UNAUTHORIZED)
    (asserts! (> stacks-block-height (get end-block launch)) ERR_INVALID_PARAMS)
    (ok (map-set token-launches launch-id (merge launch {status: "finalized"})))))

(define-public (create-vesting (launch-id uint) (beneficiary principal) (total-amount uint) (duration uint))
  (let ((launch (unwrap! (map-get? token-launches launch-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get creator launch)) ERR_UNAUTHORIZED)
    (asserts! (and (> total-amount u0) (> duration u0)) ERR_INVALID_PARAMS)
    (ok (map-set vesting-schedules {launch-id: launch-id, beneficiary: beneficiary} 
         {total-amount: total-amount, released: u0, start-block: stacks-block-height, duration: duration}))))

(define-public (release-vested-tokens (launch-id uint))
  (let ((schedule (unwrap! (map-get? vesting-schedules {launch-id: launch-id, beneficiary: tx-sender}) ERR_NOT_FOUND))
        (elapsed (- stacks-block-height (get start-block schedule)))
        (releasable (if (>= elapsed (get duration schedule))
                       (get total-amount schedule)
                       (/ (* (get total-amount schedule) elapsed) (get duration schedule))))
        (unreleased (- releasable (get released schedule))))
    (asserts! (> unreleased u0) ERR_INVALID_PARAMS)
    (ok (map-set vesting-schedules {launch-id: launch-id, beneficiary: tx-sender} 
         (merge schedule {released: releasable})))))

(define-public (claim-tokens (launch-id uint))
  (let ((participation (unwrap! (map-get? participants {launch-id: launch-id, participant: tx-sender}) ERR_NOT_FOUND))
        (launch (unwrap! (map-get? token-launches launch-id) ERR_NOT_FOUND)))
    (asserts! (is-eq (get status launch) "finalized") ERR_INVALID_PARAMS)
    (asserts! (not (get claimed participation)) ERR_ALREADY_EXISTS)
    (ok (map-set participants {launch-id: launch-id, participant: tx-sender} (merge participation {claimed: true})))))

(define-public (update-launch-status (launch-id uint) (new-status (string-ascii 20)))
  (let ((launch (unwrap! (map-get? token-launches launch-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set token-launches launch-id (merge launch {status: new-status})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
