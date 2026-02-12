(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-not-qualified (err u102))
(define-constant err-capacity-reached (err u103))

(define-map professional-events
  uint
  {
    organizer: principal,
    title: (string-ascii 128),
    profession: (string-ascii 64),
    ceu-credits: uint,
    start-block: uint,
    capacity: uint,
    enrolled: uint,
    fee: uint,
    certification-required: bool
  })

(define-map attendee-profiles
  principal
  {
    profession: (string-ascii 64),
    certification-id: (string-ascii 128),
    verified: bool,
    total-ceu: uint
  })

(define-map enrollments
  {event-id: uint, attendee: principal}
  {enrolled-at: uint, completed: bool, credits-earned: uint})

(define-data-var next-event-id uint u0)

(define-read-only (get-event (event-id uint))
  (ok (map-get? professional-events event-id)))

(define-read-only (get-profile (user principal))
  (ok (map-get? attendee-profiles user)))

(define-public (register-professional (profession (string-ascii 64)) (cert-id (string-ascii 128)))
  (begin
    (map-set attendee-profiles tx-sender
      {profession: profession, certification-id: cert-id, verified: false, total-ceu: u0})
    (ok true)))

(define-public (verify-professional (user principal))
  (let ((profile (unwrap! (map-get? attendee-profiles user) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set attendee-profiles user (merge profile {verified: true})))))

(define-public (create-event (title (string-ascii 128)) (profession (string-ascii 64)) (credits uint) (start uint) (capacity uint) (fee uint) (cert-req bool))
  (let ((event-id (var-get next-event-id)))
    (map-set professional-events event-id
      {organizer: tx-sender, title: title, profession: profession, ceu-credits: credits,
       start-block: start, capacity: capacity, enrolled: u0, fee: fee, certification-required: cert-req})
    (var-set next-event-id (+ event-id u1))
    (ok event-id)))

(define-public (enroll (event-id uint))
  (let ((event (unwrap! (map-get? professional-events event-id) err-not-found))
        (profile (unwrap! (map-get? attendee-profiles tx-sender) err-not-qualified)))
    (asserts! (get verified profile) err-not-qualified)
    (asserts! (< (get enrolled event) (get capacity event)) err-capacity-reached)
    (try! (stx-transfer? (get fee event) tx-sender (get organizer event)))
    (map-set enrollments {event-id: event-id, attendee: tx-sender}
      {enrolled-at: stacks-block-height, completed: false, credits-earned: u0})
    (ok (map-set professional-events event-id (merge event {enrolled: (+ (get enrolled event) u1)})))))

(define-public (complete-event (event-id uint) (attendee principal))
  (let ((event (unwrap! (map-get? professional-events event-id) err-not-found))
        (enrollment (unwrap! (map-get? enrollments {event-id: event-id, attendee: attendee}) err-not-found))
        (profile (unwrap! (map-get? attendee-profiles attendee) err-not-found)))
    (asserts! (is-eq tx-sender (get organizer event)) err-owner-only)
    (map-set enrollments {event-id: event-id, attendee: attendee}
      (merge enrollment {completed: true, credits-earned: (get ceu-credits event)}))
    (ok (map-set attendee-profiles attendee
      (merge profile {total-ceu: (+ (get total-ceu profile) (get ceu-credits event))})))))
