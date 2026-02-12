(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-robot-inactive (err u105))

(define-data-var robot-nonce uint u0)
(define-data-var message-nonce uint u0)

(define-map robots
  uint
  {
    owner: principal,
    robot-type: (string-ascii 30),
    capabilities: (buff 32),
    network-address: (buff 32),
    active: bool,
    reputation-score: uint,
    total-messages-sent: uint,
    total-messages-received: uint
  }
)

(define-map messages
  uint
  {
    sender-robot-id: uint,
    receiver-robot-id: uint,
    message-hash: (buff 32),
    priority: uint,
    timestamp: uint,
    delivered: bool,
    acknowledged: bool
  }
)

(define-map robot-connections
  {robot-id-1: uint, robot-id-2: uint}
  {
    established-block: uint,
    total-messages-exchanged: uint,
    trust-score: uint,
    active: bool
  }
)

(define-map owner-robots principal (list 50 uint))

(define-public (register-robot (robot-type (string-ascii 30)) (capabilities (buff 32)) (network-address (buff 32)))
  (let
    (
      (robot-id (+ (var-get robot-nonce) u1))
    )
    (map-set robots robot-id
      {
        owner: tx-sender,
        robot-type: robot-type,
        capabilities: capabilities,
        network-address: network-address,
        active: true,
        reputation-score: u100,
        total-messages-sent: u0,
        total-messages-received: u0
      }
    )
    (map-set owner-robots tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? owner-robots tx-sender)) robot-id) u50)))
    (var-set robot-nonce robot-id)
    (ok robot-id)
  )
)

(define-public (establish-connection (robot-id-1 uint) (robot-id-2 uint))
  (let
    (
      (robot1 (unwrap! (map-get? robots robot-id-1) err-not-found))
      (robot2 (unwrap! (map-get? robots robot-id-2) err-not-found))
    )
    (asserts! (is-eq tx-sender (get owner robot1)) err-unauthorized)
    (asserts! (get active robot1) err-robot-inactive)
    (asserts! (get active robot2) err-robot-inactive)
    (asserts! (is-none (map-get? robot-connections {robot-id-1: robot-id-1, robot-id-2: robot-id-2})) err-already-exists)
    (map-set robot-connections {robot-id-1: robot-id-1, robot-id-2: robot-id-2}
      {
        established-block: stacks-block-height,
        total-messages-exchanged: u0,
        trust-score: u50,
        active: true
      }
    )
    (ok true)
  )
)

(define-public (send-message (sender-robot-id uint) (receiver-robot-id uint) (message-hash (buff 32)) (priority uint))
  (let
    (
      (sender (unwrap! (map-get? robots sender-robot-id) err-not-found))
      (receiver (unwrap! (map-get? robots receiver-robot-id) err-not-found))
      (message-id (+ (var-get message-nonce) u1))
      (connection (map-get? robot-connections {robot-id-1: sender-robot-id, robot-id-2: receiver-robot-id}))
    )
    (asserts! (is-eq tx-sender (get owner sender)) err-unauthorized)
    (asserts! (get active sender) err-robot-inactive)
    (asserts! (get active receiver) err-robot-inactive)
    (map-set messages message-id
      {
        sender-robot-id: sender-robot-id,
        receiver-robot-id: receiver-robot-id,
        message-hash: message-hash,
        priority: priority,
        timestamp: stacks-block-height,
        delivered: false,
        acknowledged: false
      }
    )
    (map-set robots sender-robot-id (merge sender {
      total-messages-sent: (+ (get total-messages-sent sender) u1)
    }))
    (match connection
      conn (map-set robot-connections {robot-id-1: sender-robot-id, robot-id-2: receiver-robot-id}
        (merge conn {total-messages-exchanged: (+ (get total-messages-exchanged conn) u1)}))
      true
    )
    (var-set message-nonce message-id)
    (ok message-id)
  )
)

(define-public (acknowledge-message (message-id uint))
  (let
    (
      (message (unwrap! (map-get? messages message-id) err-not-found))
      (receiver (unwrap! (map-get? robots (get receiver-robot-id message)) err-not-found))
    )
    (asserts! (is-eq tx-sender (get owner receiver)) err-unauthorized)
    (map-set messages message-id (merge message {
      delivered: true,
      acknowledged: true
    }))
    (map-set robots (get receiver-robot-id message) (merge receiver {
      total-messages-received: (+ (get total-messages-received receiver) u1)
    }))
    (ok true)
  )
)

(define-public (update-robot-status (robot-id uint) (active bool))
  (let
    (
      (robot (unwrap! (map-get? robots robot-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get owner robot)) err-unauthorized)
    (map-set robots robot-id (merge robot {active: active}))
    (ok true)
  )
)

(define-public (update-trust-score (robot-id-1 uint) (robot-id-2 uint) (new-score uint))
  (let
    (
      (robot (unwrap! (map-get? robots robot-id-1) err-not-found))
      (connection (unwrap! (map-get? robot-connections {robot-id-1: robot-id-1, robot-id-2: robot-id-2}) err-not-found))
    )
    (asserts! (is-eq tx-sender (get owner robot)) err-unauthorized)
    (asserts! (<= new-score u100) err-invalid-amount)
    (map-set robot-connections {robot-id-1: robot-id-1, robot-id-2: robot-id-2}
      (merge connection {trust-score: new-score}))
    (ok true)
  )
)

(define-read-only (get-robot (robot-id uint))
  (ok (map-get? robots robot-id))
)

(define-read-only (get-message (message-id uint))
  (ok (map-get? messages message-id))
)

(define-read-only (get-connection (robot-id-1 uint) (robot-id-2 uint))
  (ok (map-get? robot-connections {robot-id-1: robot-id-1, robot-id-2: robot-id-2}))
)

(define-read-only (get-owner-robots (owner principal))
  (ok (map-get? owner-robots owner))
)
