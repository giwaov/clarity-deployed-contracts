(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-sold-out (err u102))
(define-constant err-invalid-rating (err u103))

(define-map experiences
  uint
  {
    host: principal,
    title: (string-ascii 128),
    category: (string-ascii 64),
    location: (string-ascii 256),
    duration-blocks: uint,
    max-participants: uint,
    booked: uint,
    price-per-person: uint,
    active: bool
  })

(define-map bookings
  {experience-id: uint, booking-id: uint}
  {guest: principal, participants: uint, booked-at: uint, completed: bool})

(define-map reviews
  {experience-id: uint, reviewer: principal}
  {rating: uint, comment: (string-ascii 256), timestamp: uint})

(define-data-var next-experience-id uint u0)

(define-read-only (get-experience (experience-id uint))
  (ok (map-get? experiences experience-id)))

(define-read-only (get-booking (experience-id uint) (booking-id uint))
  (ok (map-get? bookings {experience-id: experience-id, booking-id: booking-id})))

(define-public (create-experience (title (string-ascii 128)) (category (string-ascii 64)) (location (string-ascii 256)) (duration uint) (max uint) (price uint))
  (let ((experience-id (var-get next-experience-id)))
    (map-set experiences experience-id
      {host: tx-sender, title: title, category: category, location: location,
       duration-blocks: duration, max-participants: max, booked: u0,
       price-per-person: price, active: true})
    (var-set next-experience-id (+ experience-id u1))
    (ok experience-id)))

(define-public (book-experience (experience-id uint) (num-participants uint))
  (let ((experience (unwrap! (map-get? experiences experience-id) err-not-found))
        (booking-id (get booked experience))
        (total-price (* (get price-per-person experience) num-participants)))
    (asserts! (get active experience) err-not-found)
    (asserts! (<= (+ (get booked experience) num-participants) (get max-participants experience)) err-sold-out)
    (try! (stx-transfer? total-price tx-sender (get host experience)))
    (map-set bookings {experience-id: experience-id, booking-id: booking-id}
      {guest: tx-sender, participants: num-participants, booked-at: stacks-block-height, completed: false})
    (ok (map-set experiences experience-id
      (merge experience {booked: (+ (get booked experience) num-participants)})))))

(define-public (complete-booking (experience-id uint) (booking-id uint))
  (let ((experience (unwrap! (map-get? experiences experience-id) err-not-found))
        (booking (unwrap! (map-get? bookings {experience-id: experience-id, booking-id: booking-id}) err-not-found)))
    (asserts! (is-eq tx-sender (get host experience)) err-owner-only)
    (ok (map-set bookings {experience-id: experience-id, booking-id: booking-id}
      (merge booking {completed: true})))))

(define-public (leave-review (experience-id uint) (rating uint) (comment (string-ascii 256)))
  (begin
    (asserts! (<= rating u5) err-invalid-rating)
    (ok (map-set reviews {experience-id: experience-id, reviewer: tx-sender}
      {rating: rating, comment: comment, timestamp: stacks-block-height}))))
