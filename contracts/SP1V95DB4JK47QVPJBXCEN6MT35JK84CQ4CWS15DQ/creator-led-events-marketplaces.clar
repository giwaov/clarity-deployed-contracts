(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-sold-out (err u102))
(define-constant err-not-verified (err u103))

(define-map creator-led-events
  uint
  {
    creator: principal,
    event-title: (string-ascii 128),
    event-format: (string-ascii 64),
    content-category: (string-ascii 64),
    date: uint,
    total-slots: uint,
    sold: uint,
    tier-prices: (list 5 uint),
    revenue: uint
  })

(define-map verified-creators
  principal
  {
    creator-name: (string-ascii 128),
    platform: (string-ascii 64),
    verified-followers: uint,
    events-hosted: uint
  })

(define-map event-passes
  {event-id: uint, pass-id: uint}
  {holder: principal, tier: uint, purchased-at: uint, redeemed: bool})

(define-data-var next-event-id uint u0)

(define-read-only (get-event (event-id uint))
  (ok (map-get? creator-led-events event-id)))

(define-read-only (get-creator (creator principal))
  (ok (map-get? verified-creators creator)))

(define-public (register-as-creator (name (string-ascii 128)) (platform (string-ascii 64)) (followers uint))
  (begin
    (map-set verified-creators tx-sender
      {creator-name: name, platform: platform, verified-followers: followers, events-hosted: u0})
    (ok true)))

(define-public (create-event (title (string-ascii 128)) (format (string-ascii 64)) (category (string-ascii 64)) (date uint) (slots uint) (prices (list 5 uint)))
  (let ((event-id (var-get next-event-id))
        (creator-info (unwrap! (map-get? verified-creators tx-sender) err-not-verified)))
    (map-set creator-led-events event-id
      {creator: tx-sender, event-title: title, event-format: format, content-category: category,
       date: date, total-slots: slots, sold: u0, tier-prices: prices, revenue: u0})
    (map-set verified-creators tx-sender
      (merge creator-info {events-hosted: (+ (get events-hosted creator-info) u1)}))
    (var-set next-event-id (+ event-id u1))
    (ok event-id)))

(define-public (purchase-pass (event-id uint) (tier uint))
  (let ((event (unwrap! (map-get? creator-led-events event-id) err-not-found))
        (pass-id (get sold event))
        (price (unwrap! (element-at (get tier-prices event) tier) err-not-found)))
    (asserts! (< (get sold event) (get total-slots event)) err-sold-out)
    (try! (stx-transfer? price tx-sender (get creator event)))
    (map-set event-passes {event-id: event-id, pass-id: pass-id}
      {holder: tx-sender, tier: tier, purchased-at: stacks-block-height, redeemed: false})
    (ok (map-set creator-led-events event-id
      (merge event {sold: (+ (get sold event) u1), revenue: (+ (get revenue event) price)})))))

(define-public (redeem-pass (event-id uint) (pass-id uint))
  (let ((pass (unwrap! (map-get? event-passes {event-id: event-id, pass-id: pass-id}) err-not-found)))
    (asserts! (is-eq tx-sender (get holder pass)) err-owner-only)
    (ok (map-set event-passes {event-id: event-id, pass-id: pass-id}
      (merge pass {redeemed: true})))))
