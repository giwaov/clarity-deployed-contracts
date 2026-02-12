(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u104))
(define-constant err-gateway-offline (err u126))

(define-data-var gateway-nonce uint u0)

(define-map lorawan-gateways
  uint
  {
    owner: principal,
    location-hash: (buff 32),
    range-km: uint,
    packets-relayed: uint,
    devices-served: uint,
    rewards-earned: uint,
    online: bool,
    registered-block: uint
  }
)

(define-map iot-devices
  {gateway-id: uint, device-id: uint}
  {
    owner: principal,
    device-type: (string-ascii 30),
    data-transmitted: uint,
    last-seen: uint,
    active: bool
  }
)

(define-map data-packets
  {gateway-id: uint, packet-id: uint}
  {
    sender-device: uint,
    receiver-gateway: uint,
    payload-size: uint,
    timestamp: uint
  }
)

(define-map device-counter uint uint)
(define-map packet-counter uint uint)
(define-map owner-gateways principal (list 50 uint))

(define-public (deploy-gateway (location (buff 32)) (range uint))
  (let
    (
      (gateway-id (+ (var-get gateway-nonce) u1))
    )
    (asserts! (> range u0) err-invalid-amount)
    (map-set lorawan-gateways gateway-id {
      owner: tx-sender,
      location-hash: location,
      range-km: range,
      packets-relayed: u0,
      devices-served: u0,
      rewards-earned: u0,
      online: true,
      registered-block: stacks-block-height
    })
    (map-set device-counter gateway-id u0)
    (map-set packet-counter gateway-id u0)
    (map-set owner-gateways tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? owner-gateways tx-sender)) gateway-id) u50)))
    (var-set gateway-nonce gateway-id)
    (ok gateway-id)
  )
)

(define-public (register-iot-device (gateway-id uint) (device-type (string-ascii 30)))
  (let
    (
      (gateway (unwrap! (map-get? lorawan-gateways gateway-id) err-not-found))
      (device-id (+ (default-to u0 (map-get? device-counter gateway-id)) u1))
    )
    (asserts! (get online gateway) err-gateway-offline)
    (map-set iot-devices {gateway-id: gateway-id, device-id: device-id} {
      owner: tx-sender,
      device-type: device-type,
      data-transmitted: u0,
      last-seen: stacks-block-height,
      active: true
    })
    (map-set device-counter gateway-id device-id)
    (map-set lorawan-gateways gateway-id (merge gateway {
      devices-served: (+ (get devices-served gateway) u1)
    }))
    (ok device-id)
  )
)

(define-public (transmit-data (gateway-id uint) (device-id uint) (payload-size uint))
  (let
    (
      (gateway (unwrap! (map-get? lorawan-gateways gateway-id) err-not-found))
      (device (unwrap! (map-get? iot-devices {gateway-id: gateway-id, device-id: device-id}) err-not-found))
      (packet-id (+ (default-to u0 (map-get? packet-counter gateway-id)) u1))
    )
    (asserts! (is-eq tx-sender (get owner device)) err-unauthorized)
    (asserts! (get active device) err-not-found)
    (map-set data-packets {gateway-id: gateway-id, packet-id: packet-id} {
      sender-device: device-id,
      receiver-gateway: gateway-id,
      payload-size: payload-size,
      timestamp: stacks-block-height
    })
    (map-set packet-counter gateway-id packet-id)
    (map-set iot-devices {gateway-id: gateway-id, device-id: device-id}
      (merge device {
        data-transmitted: (+ (get data-transmitted device) payload-size),
        last-seen: stacks-block-height
      }))
    (map-set lorawan-gateways gateway-id (merge gateway {
      packets-relayed: (+ (get packets-relayed gateway) u1)
    }))
    (ok packet-id)
  )
)

(define-public (distribute-rewards (gateway-id uint) (reward uint))
  (let
    (
      (gateway (unwrap! (map-get? lorawan-gateways gateway-id) err-not-found))
    )
    (try! (stx-transfer? reward tx-sender (get owner gateway)))
    (map-set lorawan-gateways gateway-id (merge gateway {
      rewards-earned: (+ (get rewards-earned gateway) reward)
    }))
    (ok true)
  )
)

(define-public (toggle-gateway-status (gateway-id uint))
  (let
    (
      (gateway (unwrap! (map-get? lorawan-gateways gateway-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get owner gateway)) err-unauthorized)
    (map-set lorawan-gateways gateway-id (merge gateway {
      online: (not (get online gateway))
    }))
    (ok true)
  )
)

(define-read-only (get-gateway (gateway-id uint))
  (ok (map-get? lorawan-gateways gateway-id))
)

(define-read-only (get-device (gateway-id uint) (device-id uint))
  (ok (map-get? iot-devices {gateway-id: gateway-id, device-id: device-id}))
)

(define-read-only (get-packet (gateway-id uint) (packet-id uint))
  (ok (map-get? data-packets {gateway-id: gateway-id, packet-id: packet-id}))
)

(define-read-only (get-owner-gateways (owner principal))
  (ok (map-get? owner-gateways owner))
)

(define-read-only (calculate-gateway-efficiency (gateway-id uint))
  (let
    (
      (gateway (unwrap-panic (map-get? lorawan-gateways gateway-id)))
      (devices (get devices-served gateway))
      (packets (get packets-relayed gateway))
    )
    (if (> devices u0)
      (ok (/ packets devices))
      (ok u0)
    )
  )
)
