(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u1000))
(define-constant ERR_ROOM_NOT_FOUND (err u1001))
(define-constant ERR_NOT_MEMBER (err u1002))
(define-constant ERR_ROOM_FULL (err u1003))

(define-constant MAX_ROOM_MEMBERS u100)

(define-data-var next-room-id uint u1)

(define-map game-rooms
  uint
  {
    creator: principal,
    name: (string-ascii 128),
    max-members: uint,
    member-count: uint,
    created-at: uint,
    active: bool
  }
)

(define-map room-members
  {room-id: uint, member: principal}
  bool
)

(define-map room-messages
  {room-id: uint, message-id: uint}
  {
    sender: principal,
    content: (string-ascii 512),
    timestamp: uint
  }
)

(define-map room-message-count
  uint
  uint
)

(define-read-only (get-contract-hash)
  (contract-hash? .multiplayer-communication)
)

(define-read-only (get-room (room-id uint))
  (ok (unwrap! (map-get? game-rooms room-id) ERR_ROOM_NOT_FOUND))
)

(define-read-only (get-member-count (room-id uint))
  (let
    (
      (room-data (unwrap! (map-get? game-rooms room-id) ERR_ROOM_NOT_FOUND))
    )
    (ok (get member-count room-data))
  )
)

(define-read-only (is-member (room-id uint) (member principal))
  (ok (default-to false (map-get? room-members {room-id: room-id, member: member})))
)

(define-public (create-room (name (string-ascii 128)) (max-members uint))
  (let
    (
      (room-id (var-get next-room-id))
    )
    (asserts! (<= max-members MAX_ROOM_MEMBERS) ERR_NOT_AUTHORIZED)
    (map-set game-rooms room-id {
      creator: tx-sender,
      name: name,
      max-members: max-members,
      member-count: u1,
      created-at: stacks-block-time,
      active: true
    })
    (map-set room-members {room-id: room-id, member: tx-sender} true)
    (map-set room-message-count room-id u0)
    (var-set next-room-id (+ room-id u1))
    (ok room-id)
  )
)

(define-public (join-room (room-id uint))
  (let
    (
      (room-data (unwrap! (map-get? game-rooms room-id) ERR_ROOM_NOT_FOUND))
      (is-already-member (default-to false (map-get? room-members {room-id: room-id, member: tx-sender})))
    )
    (asserts! (not is-already-member) ERR_NOT_MEMBER)
    (asserts! (< (get member-count room-data) (get max-members room-data)) ERR_ROOM_FULL)
    (asserts! (get active room-data) ERR_NOT_AUTHORIZED)
    (map-set room-members {room-id: room-id, member: tx-sender} true)
    (map-set game-rooms room-id (merge room-data {
      member-count: (+ (get member-count room-data) u1)
    }))
    (ok true)
  )
)

(define-public (leave-room (room-id uint))
  (let
    (
      (room-data (unwrap! (map-get? game-rooms room-id) ERR_ROOM_NOT_FOUND))
      (is-member-check (default-to false (map-get? room-members {room-id: room-id, member: tx-sender})))
    )
    (asserts! is-member-check ERR_NOT_MEMBER)
    (map-set room-members {room-id: room-id, member: tx-sender} false)
    (map-set game-rooms room-id (merge room-data {
      member-count: (- (get member-count room-data) u1)
    }))
    (ok true)
  )
)

(define-public (send-message (room-id uint) (content (string-ascii 512)))
  (let
    (
      (is-member-check (default-to false (map-get? room-members {room-id: room-id, member: tx-sender})))
      (message-count (default-to u0 (map-get? room-message-count room-id)))
    )
    (asserts! is-member-check ERR_NOT_MEMBER)
    (map-set room-messages 
      {room-id: room-id, message-id: message-count}
      {sender: tx-sender, content: content, timestamp: stacks-block-time}
    )
    (map-set room-message-count room-id (+ message-count u1))
    (ok true)
  )
)

(define-read-only (get-message (room-id uint) (message-id uint))
  (ok (map-get? room-messages {room-id: room-id, message-id: message-id}))
)

(define-read-only (verify-message-signature (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (ok (secp256r1-verify message signature public-key))
)

(define-read-only (get-time)
  stacks-block-time
)
