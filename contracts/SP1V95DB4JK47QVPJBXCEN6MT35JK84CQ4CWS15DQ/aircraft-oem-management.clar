(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-invalid-serial (err u102))

(define-map aircraft-models
  {manufacturer: (string-ascii 64), model: (string-ascii 64)}
  {max-range: uint, max-payload: uint, cruise-speed: uint, certification-date: uint})

(define-map manufactured-aircraft
  (string-ascii 32)
  {
    manufacturer: (string-ascii 64),
    model: (string-ascii 64),
    production-date: uint,
    delivered-to: (string-ascii 128),
    status: (string-ascii 32)
  })

(define-map parts-inventory
  {part-number: (string-ascii 32), manufacturer: (string-ascii 64)}
  {quantity: uint, unit-cost: uint})

(define-read-only (get-model (mfg (string-ascii 64)) (model (string-ascii 64)))
  (ok (map-get? aircraft-models {manufacturer: mfg, model: model})))

(define-read-only (get-aircraft (serial (string-ascii 32)))
  (ok (map-get? manufactured-aircraft serial)))

(define-public (register-model (mfg (string-ascii 64)) (model (string-ascii 64)) (range uint) (payload uint) (speed uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set aircraft-models {manufacturer: mfg, model: model}
      {max-range: range, max-payload: payload, cruise-speed: speed, certification-date: stacks-block-height}))))

(define-public (produce-aircraft (serial (string-ascii 32)) (mfg (string-ascii 64)) (model (string-ascii 64)) (customer (string-ascii 128)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set manufactured-aircraft serial
      {manufacturer: mfg, model: model, production-date: stacks-block-height,
       delivered-to: customer, status: "produced"}))))

(define-public (deliver-aircraft (serial (string-ascii 32)))
  (let ((aircraft (unwrap! (map-get? manufactured-aircraft serial) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set manufactured-aircraft serial (merge aircraft {status: "delivered"})))))
