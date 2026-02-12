(define-non-fungible-token ai-agent-nft uint)

(define-data-var token-id-nonce uint u0)

(define-map token-data uint {data-hash: (buff 32), description: (string-ascii 256)})
(define-map token-authorized-users {token-id: uint, user: principal} bool)
(define-map token-approvals uint principal)
(define-map operator-approvals {owner: principal, operator: principal} bool)
(define-map delegate-access principal principal)

(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-token-exists (err u102))
(define-constant err-zero-address (err u103))
(define-constant err-not-found (err u104))

(define-read-only (get-last-token-id)
  (ok (var-get token-id-nonce)))

(define-read-only (get-owner (token-id uint))
  (ok (unwrap! (nft-get-owner? ai-agent-nft token-id) err-not-owner)))

(define-read-only (get-token-data (token-id uint))
  (ok (unwrap! (map-get? token-data token-id) err-not-owner)))

(define-read-only (is-authorized (token-id uint) (user principal))
  (default-to false (map-get? token-authorized-users {token-id: token-id, user: user})))

(define-read-only (get-approved (token-id uint))
  (ok (map-get? token-approvals token-id)))

(define-read-only (is-approved-for-all (owner principal) (operator principal))
  (default-to false (map-get? operator-approvals {owner: owner, operator: operator})))

(define-read-only (get-delegate-access (user principal))
  (ok (map-get? delegate-access user)))

(define-public (mint (data-hash (buff 32)) (description (string-ascii 256)) (recipient principal))
  (let ((new-id (+ (var-get token-id-nonce) u1)))
    (try! (nft-mint? ai-agent-nft new-id recipient))
    (map-set token-data new-id {data-hash: data-hash, description: description})
    (var-set token-id-nonce new-id)
    (ok new-id)))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) err-not-authorized)
    (asserts! (is-some (nft-get-owner? ai-agent-nft token-id)) err-not-found)
    (try! (nft-transfer? ai-agent-nft token-id sender recipient))
    (map-delete token-approvals token-id)
    (ok true)))

(define-public (authorize-usage (token-id uint) (user principal))
  (let ((owner (unwrap! (nft-get-owner? ai-agent-nft token-id) err-not-owner)))
    (asserts! (is-eq tx-sender owner) err-not-owner)
    (map-set token-authorized-users {token-id: token-id, user: user} true)
    (ok true)))

(define-public (revoke-authorization (token-id uint) (user principal))
  (let ((owner (unwrap! (nft-get-owner? ai-agent-nft token-id) err-not-owner)))
    (asserts! (is-eq tx-sender owner) err-not-owner)
    (map-delete token-authorized-users {token-id: token-id, user: user})
    (ok true)))

(define-public (approve (spender principal) (token-id uint))
  (let ((owner (unwrap! (nft-get-owner? ai-agent-nft token-id) err-not-owner)))
    (asserts! (or (is-eq tx-sender owner) 
                  (is-approved-for-all owner tx-sender)) err-not-owner)
    (map-set token-approvals token-id spender)
    (ok true)))

(define-public (set-approval-for-all (operator principal) (approved bool))
  (begin
    (asserts! (not (is-eq operator tx-sender)) err-not-authorized)
    (map-set operator-approvals {owner: tx-sender, operator: operator} approved)
    (ok true)))

(define-public (delegate-access-to (assistant principal))
  (begin
    (map-set delegate-access tx-sender assistant)
    (ok true)))

(define-read-only (get-contract-hash)
  (contract-hash? .ai-agent-nft))

(define-read-only (get-block-time)
  stacks-block-time)
