(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-params (err u103))
(define-constant err-insufficient-capacity (err u104))

(define-map warehouses
  {warehouse-id: uint}
  {
    name: (string-ascii 128),
    location: (string-ascii 128),
    operator: principal,
    capacity: uint,
    used-capacity: uint,
    temperature-controlled: bool,
    active: bool
  }
)

(define-map storage-lots
  {lot-id: uint}
  {
    warehouse-id: uint,
    owner: principal,
    crop-type: (string-ascii 64),
    quantity: uint,
    storage-date: uint,
    quality-grade: (string-ascii 16),
    status: (string-ascii 32)
  }
)

(define-data-var warehouse-nonce uint u0)
(define-data-var lot-nonce uint u0)

(define-read-only (get-warehouse (warehouse-id uint))
  (map-get? warehouses {warehouse-id: warehouse-id})
)

(define-read-only (get-lot (lot-id uint))
  (map-get? storage-lots {lot-id: lot-id})
)

(define-public (register-warehouse
  (name (string-ascii 128))
  (location (string-ascii 128))
  (capacity uint)
  (temperature-controlled bool)
)
  (let ((warehouse-id (var-get warehouse-nonce)))
    (asserts! (> capacity u0) err-invalid-params)
    (map-set warehouses {warehouse-id: warehouse-id}
      {
        name: name,
        location: location,
        operator: tx-sender,
        capacity: capacity,
        used-capacity: u0,
        temperature-controlled: temperature-controlled,
        active: true
      }
    )
    (var-set warehouse-nonce (+ warehouse-id u1))
    (ok warehouse-id)
  )
)

(define-public (store-crop
  (warehouse-id uint)
  (crop-type (string-ascii 64))
  (quantity uint)
  (quality-grade (string-ascii 16))
)
  (let (
    (warehouse (unwrap! (map-get? warehouses {warehouse-id: warehouse-id}) err-not-found))
    (lot-id (var-get lot-nonce))
  )
    (asserts! (get active warehouse) err-unauthorized)
    (asserts! (<= (+ (get used-capacity warehouse) quantity) (get capacity warehouse)) err-insufficient-capacity)
    (map-set storage-lots {lot-id: lot-id}
      {
        warehouse-id: warehouse-id,
        owner: tx-sender,
        crop-type: crop-type,
        quantity: quantity,
        storage-date: stacks-block-height,
        quality-grade: quality-grade,
        status: "stored"
      }
    )
    (map-set warehouses {warehouse-id: warehouse-id}
      (merge warehouse {used-capacity: (+ (get used-capacity warehouse) quantity)})
    )
    (var-set lot-nonce (+ lot-id u1))
    (ok lot-id)
  )
)

(define-public (withdraw-crop (lot-id uint) (quantity uint))
  (let (
    (lot (unwrap! (map-get? storage-lots {lot-id: lot-id}) err-not-found))
    (warehouse (unwrap! (map-get? warehouses {warehouse-id: (get warehouse-id lot)}) err-not-found))
  )
    (asserts! (is-eq tx-sender (get owner lot)) err-unauthorized)
    (asserts! (<= quantity (get quantity lot)) err-invalid-params)
    (map-set storage-lots {lot-id: lot-id}
      (merge lot {quantity: (- (get quantity lot) quantity)})
    )
    (ok (map-set warehouses {warehouse-id: (get warehouse-id lot)}
      (merge warehouse {used-capacity: (- (get used-capacity warehouse) quantity)})
    ))
  )
)

(define-public (transfer-lot (lot-id uint) (new-owner principal))
  (let ((lot (unwrap! (map-get? storage-lots {lot-id: lot-id}) err-not-found)))
    (asserts! (is-eq tx-sender (get owner lot)) err-unauthorized)
    (ok (map-set storage-lots {lot-id: lot-id}
      (merge lot {owner: new-owner})
    ))
  )
)

(define-public (update-lot-status (lot-id uint) (new-status (string-ascii 32)))
  (let ((lot (unwrap! (map-get? storage-lots {lot-id: lot-id}) err-not-found)))
    (asserts! (is-eq tx-sender (get owner lot)) err-unauthorized)
    (ok (map-set storage-lots {lot-id: lot-id}
      (merge lot {status: new-status})
    ))
  )
)
