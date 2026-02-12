(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)

(define-map board-members principal {position: (string-ascii 50), voting-power: uint, appointed-at: uint, active: bool})
(define-map board-proposals uint {title: (string-utf8 200), proposer: principal, votes: uint, total-power: uint, quorum: uint, status: (string-ascii 20), created-at: uint})
(define-map member-votes {proposal-id: uint, member: principal} uint)
(define-data-var proposal-counter uint u0)
(define-data-var quorum-threshold uint u60)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-board-member (member principal))
  (map-get? board-members member))

(define-read-only (get-board-proposal (proposal-id uint))
  (map-get? board-proposals proposal-id))

(define-read-only (get-member-vote (proposal-id uint) (member principal))
  (map-get? member-votes {proposal-id: proposal-id, member: member}))

(define-read-only (get-quorum-threshold) (var-get quorum-threshold))

(define-public (add-board-member (member principal) (position (string-ascii 50)) (voting-power uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? board-members member)) ERR_ALREADY_EXISTS)
    (asserts! (> voting-power u0) ERR_INVALID_PARAMS)
    (ok (map-set board-members member {position: position, voting-power: voting-power, appointed-at: stacks-block-height, active: true}))))

(define-public (remove-board-member (member principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? board-members member)) ERR_NOT_FOUND)
    (ok (map-delete board-members member))))

(define-public (update-voting-power (member principal) (new-power uint))
  (let ((member-data (unwrap! (map-get? board-members member) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (> new-power u0) ERR_INVALID_PARAMS)
    (ok (map-set board-members member (merge member-data {voting-power: new-power})))))

(define-public (create-board-proposal (title (string-utf8 200)))
  (let ((member-data (unwrap! (map-get? board-members tx-sender) ERR_UNAUTHORIZED))
        (new-id (+ (var-get proposal-counter) u1)))
    (asserts! (get active member-data) ERR_UNAUTHORIZED)
    (map-set board-proposals new-id {title: title, proposer: tx-sender, votes: u0, total-power: u0, quorum: (var-get quorum-threshold), status: "active", created-at: stacks-block-height})
    (var-set proposal-counter new-id)
    (ok new-id)))

(define-public (cast-vote (proposal-id uint))
  (let ((member-data (unwrap! (map-get? board-members tx-sender) ERR_UNAUTHORIZED))
        (proposal-data (unwrap! (map-get? board-proposals proposal-id) ERR_NOT_FOUND))
        (voting-power (get voting-power member-data)))
    (asserts! (get active member-data) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status proposal-data) "active") ERR_INVALID_PARAMS)
    (asserts! (is-none (map-get? member-votes {proposal-id: proposal-id, member: tx-sender})) ERR_ALREADY_EXISTS)
    (map-set member-votes {proposal-id: proposal-id, member: tx-sender} voting-power)
    (ok (map-set board-proposals proposal-id 
      (merge proposal-data {total-power: (+ (get total-power proposal-data) voting-power)})))))

(define-public (finalize-proposal (proposal-id uint))
  (let ((proposal-data (unwrap! (map-get? board-proposals proposal-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status proposal-data) "active") ERR_INVALID_PARAMS)
    (ok (map-set board-proposals proposal-id 
      (merge proposal-data {status: (if (>= (get total-power proposal-data) (get quorum proposal-data)) "approved" "rejected")})))))

(define-public (set-quorum (new-quorum uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (and (> new-quorum u0) (<= new-quorum u100)) ERR_INVALID_PARAMS)
    (ok (var-set quorum-threshold new-quorum))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
