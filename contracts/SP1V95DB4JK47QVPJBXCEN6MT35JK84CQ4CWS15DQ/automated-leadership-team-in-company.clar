(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)

(define-map leadership-members principal {role: (string-ascii 50), appointed-at: uint, status: bool})
(define-map proposals uint {proposer: principal, description: (string-utf8 500), votes-for: uint, votes-against: uint, executed: bool, created-at: uint})
(define-map votes {proposal-id: uint, member: principal} bool)
(define-data-var proposal-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-member (member principal))
  (map-get? leadership-members member))

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id))

(define-read-only (get-vote (proposal-id uint) (member principal))
  (map-get? votes {proposal-id: proposal-id, member: member}))

(define-public (appoint-member (member principal) (role (string-ascii 50)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? leadership-members member)) ERR_ALREADY_EXISTS)
    (ok (map-set leadership-members member {role: role, appointed-at: stacks-block-height, status: true}))))

(define-public (remove-member (member principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? leadership-members member)) ERR_NOT_FOUND)
    (ok (map-delete leadership-members member))))

(define-public (create-proposal (description (string-utf8 500)))
  (let ((member-data (unwrap! (map-get? leadership-members tx-sender) ERR_UNAUTHORIZED))
        (proposal-id (+ (var-get proposal-count) u1)))
    (asserts! (get status member-data) ERR_UNAUTHORIZED)
    (map-set proposals proposal-id {proposer: tx-sender, description: description, votes-for: u0, votes-against: u0, executed: false, created-at: stacks-block-height})
    (var-set proposal-count proposal-id)
    (ok proposal-id)))

(define-public (vote-proposal (proposal-id uint) (vote-for bool))
  (let ((member-data (unwrap! (map-get? leadership-members tx-sender) ERR_UNAUTHORIZED))
        (proposal-data (unwrap! (map-get? proposals proposal-id) ERR_NOT_FOUND)))
    (asserts! (get status member-data) ERR_UNAUTHORIZED)
    (asserts! (not (get executed proposal-data)) ERR_INVALID_PARAMS)
    (asserts! (is-none (map-get? votes {proposal-id: proposal-id, member: tx-sender})) ERR_ALREADY_EXISTS)
    (map-set votes {proposal-id: proposal-id, member: tx-sender} vote-for)
    (ok (map-set proposals proposal-id 
      (if vote-for
        (merge proposal-data {votes-for: (+ (get votes-for proposal-data) u1)})
        (merge proposal-data {votes-against: (+ (get votes-against proposal-data) u1)}))))))

(define-public (execute-proposal (proposal-id uint))
  (let ((proposal-data (unwrap! (map-get? proposals proposal-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (not (get executed proposal-data)) ERR_INVALID_PARAMS)
    (asserts! (> (get votes-for proposal-data) (get votes-against proposal-data)) ERR_INVALID_PARAMS)
    (ok (map-set proposals proposal-id (merge proposal-data {executed: true})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
