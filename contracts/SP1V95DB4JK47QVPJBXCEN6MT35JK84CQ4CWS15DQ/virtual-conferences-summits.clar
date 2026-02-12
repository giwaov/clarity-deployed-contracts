(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-capacity-reached (err u102))
(define-constant err-session-conflict (err u103))

(define-map virtual-conferences
  uint
  {
    organizer: principal,
    conference-name: (string-ascii 128),
    topic: (string-ascii 64),
    start-block: uint,
    duration-blocks: uint,
    max-participants: uint,
    registered: uint,
    ticket-price: uint,
    platform-url: (string-ascii 256)
  })

(define-map conference-sessions
  {conference-id: uint, session-id: uint}
  {session-title: (string-ascii 128), speaker: principal, start-time: uint, duration: uint})

(define-map participant-registrations
  {conference-id: uint, participant: principal}
  {registered-at: uint, paid: bool, sessions-attended: uint})

(define-data-var next-conference-id uint u0)

(define-read-only (get-conference (conference-id uint))
  (ok (map-get? virtual-conferences conference-id)))

(define-read-only (get-session (conference-id uint) (session-id uint))
  (ok (map-get? conference-sessions {conference-id: conference-id, session-id: session-id})))

(define-public (create-conference (name (string-ascii 128)) (topic (string-ascii 64)) (start uint) (duration uint) (max uint) (price uint) (url (string-ascii 256)))
  (let ((conference-id (var-get next-conference-id)))
    (map-set virtual-conferences conference-id
      {organizer: tx-sender, conference-name: name, topic: topic, start-block: start,
       duration-blocks: duration, max-participants: max, registered: u0,
       ticket-price: price, platform-url: url})
    (var-set next-conference-id (+ conference-id u1))
    (ok conference-id)))

(define-public (add-session (conference-id uint) (session-id uint) (title (string-ascii 128)) (speaker principal) (start uint) (duration uint))
  (let ((conference (unwrap! (map-get? virtual-conferences conference-id) err-not-found)))
    (asserts! (is-eq tx-sender (get organizer conference)) err-owner-only)
    (ok (map-set conference-sessions {conference-id: conference-id, session-id: session-id}
      {session-title: title, speaker: speaker, start-time: start, duration: duration}))))

(define-public (register-participant (conference-id uint))
  (let ((conference (unwrap! (map-get? virtual-conferences conference-id) err-not-found)))
    (asserts! (< (get registered conference) (get max-participants conference)) err-capacity-reached)
    (try! (stx-transfer? (get ticket-price conference) tx-sender (get organizer conference)))
    (map-set participant-registrations {conference-id: conference-id, participant: tx-sender}
      {registered-at: stacks-block-height, paid: true, sessions-attended: u0})
    (ok (map-set virtual-conferences conference-id
      (merge conference {registered: (+ (get registered conference) u1)})))))

(define-public (track-session-attendance (conference-id uint))
  (let ((registration (unwrap! (map-get? participant-registrations {conference-id: conference-id, participant: tx-sender}) err-not-found)))
    (ok (map-set participant-registrations {conference-id: conference-id, participant: tx-sender}
      (merge registration {sessions-attended: (+ (get sessions-attended registration) u1)})))))
