(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-params (err u103))

(define-map storage-spaces
  {space-id: uint}
  {
    owner: principal,
    capacity: uint,
    available: uint,
    location: (string-ascii 128),
    price-per-unit: uint,
    active: bool
  }
)

(define-map rentals
  {rental-id: uint}
  {
    space-id: uint,
    renter: principal,
    quantity: uint,
    start-height: uint,
    end-height: uint,
    total-cost: uint,
    status: (string-ascii 16)
  }
)

(define-data-var space-nonce uint u0)
(define-data-var rental-nonce uint u0)

(define-read-only (get-storage-space (space-id uint))
  (map-get? storage-spaces {space-id: space-id})
)

(define-read-only (get-rental (rental-id uint))
  (map-get? rentals {rental-id: rental-id})
)

(define-public (list-storage
  (capacity uint)
  (location (string-ascii 128))
  (price-per-unit uint)
)
  (let ((space-id (var-get space-nonce)))
    (asserts! (> capacity u0) err-invalid-params)
    (map-set storage-spaces {space-id: space-id}
      {
        owner: tx-sender,
        capacity: capacity,
        available: capacity,
        location: location,
        price-per-unit: price-per-unit,
        active: true
      }
    )
    (var-set space-nonce (+ space-id u1))
    (ok space-id)
  )
)

(define-public (rent-storage
  (space-id uint)
  (quantity uint)
  (duration uint)
)
  (let (
    (space (unwrap! (map-get? storage-spaces {space-id: space-id}) err-not-found))
    (rental-id (var-get rental-nonce))
    (total-cost (* (* quantity (get price-per-unit space)) duration))
  )
    (asserts! (get active space) err-unauthorized)
    (asserts! (<= quantity (get available space)) err-invalid-params)
    (map-set rentals {rental-id: rental-id}
      {
        space-id: space-id,
        renter: tx-sender,
        quantity: quantity,
        start-height: stacks-block-height,
        end-height: (+ stacks-block-height duration),
        total-cost: total-cost,
        status: "active"
      }
    )
    (map-set storage-spaces {space-id: space-id}
      (merge space {available: (- (get available space) quantity)})
    )
    (var-set rental-nonce (+ rental-id u1))
    (ok rental-id)
  )
)

(define-public (end-rental (rental-id uint))
  (let (
    (rental (unwrap! (map-get? rentals {rental-id: rental-id}) err-not-found))
    (space (unwrap! (map-get? storage-spaces {space-id: (get space-id rental)}) err-not-found))
  )
    (asserts! (or 
      (is-eq tx-sender (get renter rental))
      (is-eq tx-sender (get owner space)))
      err-unauthorized)
    (map-set rentals {rental-id: rental-id}
      (merge rental {status: "ended"})
    )
    (ok (map-set storage-spaces {space-id: (get space-id rental)}
      (merge space {available: (+ (get available space) (get quantity rental))})
    ))
  )
)
