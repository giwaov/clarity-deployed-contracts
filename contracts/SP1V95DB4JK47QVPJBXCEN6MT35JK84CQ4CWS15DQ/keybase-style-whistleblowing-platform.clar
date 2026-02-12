(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)

(define-map encrypted-messages uint {encrypted-hash: (buff 32), recipient-key: (buff 33), timestamp: uint, verified: bool, read: bool})
(define-map keybase-users principal {username: (string-ascii 50), public-key: (buff 33), verified: bool, active: bool})
(define-map secure-channels {sender: principal, receiver: principal} {channel-id: (string-ascii 50), established-at: uint, active: bool})
(define-data-var message-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-encrypted-message (message-id uint))
  (map-get? encrypted-messages message-id))

(define-read-only (get-keybase-user (user-id principal))
  (map-get? keybase-users user-id))

(define-read-only (get-secure-channel (sender principal) (receiver principal))
  (map-get? secure-channels {sender: sender, receiver: receiver}))

(define-public (register-keybase-user (username (string-ascii 50)) (public-key (buff 33)))
  (begin
    (asserts! (is-none (map-get? keybase-users tx-sender)) ERR_ALREADY_EXISTS)
    (ok (map-set keybase-users tx-sender {username: username, public-key: public-key, verified: false, active: true}))))

(define-public (verify-user (user principal))
  (let ((user-data (unwrap! (map-get? keybase-users user) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set keybase-users user (merge user-data {verified: true})))))

(define-public (establish-secure-channel (receiver principal) (channel-id (string-ascii 50)))
  (begin
    (asserts! (is-some (map-get? keybase-users tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? keybase-users receiver)) ERR_NOT_FOUND)
    (ok (map-set secure-channels {sender: tx-sender, receiver: receiver} {channel-id: channel-id, established-at: stacks-block-height, active: true}))))

(define-public (send-encrypted-message (encrypted-hash (buff 32)) (recipient-key (buff 33)))
  (let ((message-id (+ (var-get message-count) u1))
        (sender-data (unwrap! (map-get? keybase-users tx-sender) ERR_UNAUTHORIZED)))
    (asserts! (get active sender-data) ERR_UNAUTHORIZED)
    (map-set encrypted-messages message-id {encrypted-hash: encrypted-hash, recipient-key: recipient-key, timestamp: stacks-block-height, verified: false, read: false})
    (var-set message-count message-id)
    (ok message-id)))

(define-public (mark-message-read (message-id uint))
  (let ((message (unwrap! (map-get? encrypted-messages message-id) ERR_NOT_FOUND)))
    (asserts! (is-some (map-get? keybase-users tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (not (get read message)) ERR_ALREADY_EXISTS)
    (ok (map-set encrypted-messages message-id (merge message {read: true})))))

(define-public (deactivate-user (user principal))
  (let ((user-data (unwrap! (map-get? keybase-users user) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set keybase-users user (merge user-data {active: false})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
