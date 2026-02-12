(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-room-full (err u102))
(define-constant err-meeting-ended (err u103))

(define-map virtual-meetings
  uint
  {
    host: principal,
    meeting-title: (string-ascii 128),
    meeting-type: (string-ascii 64),
    scheduled-start: uint,
    duration-blocks: uint,
    max-participants: uint,
    current-participants: uint,
    room-url: (string-ascii 256),
    recording-enabled: bool,
    active: bool
  })

(define-map meeting-participants
  {meeting-id: uint, participant: principal}
  {joined-at: uint, left-at: uint, duration: uint, moderator: bool})

(define-map breakout-rooms
  {meeting-id: uint, room-id: uint}
  {room-name: (string-ascii 64), participants: (list 20 principal), topic: (string-ascii 128)})

(define-data-var next-meeting-id uint u0)

(define-read-only (get-meeting (meeting-id uint))
  (ok (map-get? virtual-meetings meeting-id)))

(define-read-only (get-participant (meeting-id uint) (participant principal))
  (ok (map-get? meeting-participants {meeting-id: meeting-id, participant: participant})))

(define-public (schedule-meeting (title (string-ascii 128)) (type (string-ascii 64)) (start uint) (duration uint) (max uint) (url (string-ascii 256)) (recording bool))
  (let ((meeting-id (var-get next-meeting-id)))
    (map-set virtual-meetings meeting-id
      {host: tx-sender, meeting-title: title, meeting-type: type, scheduled-start: start,
       duration-blocks: duration, max-participants: max, current-participants: u0,
       room-url: url, recording-enabled: recording, active: true})
    (var-set next-meeting-id (+ meeting-id u1))
    (ok meeting-id)))

(define-public (join-meeting (meeting-id uint))
  (let ((meeting (unwrap! (map-get? virtual-meetings meeting-id) err-not-found)))
    (asserts! (get active meeting) err-meeting-ended)
    (asserts! (< (get current-participants meeting) (get max-participants meeting)) err-room-full)
    (map-set meeting-participants {meeting-id: meeting-id, participant: tx-sender}
      {joined-at: stacks-block-height, left-at: u0, duration: u0, moderator: false})
    (ok (map-set virtual-meetings meeting-id
      (merge meeting {current-participants: (+ (get current-participants meeting) u1)})))))

(define-public (leave-meeting (meeting-id uint))
  (let ((meeting (unwrap! (map-get? virtual-meetings meeting-id) err-not-found))
        (participant (unwrap! (map-get? meeting-participants {meeting-id: meeting-id, participant: tx-sender}) err-not-found))
        (session-duration (- stacks-block-height (get joined-at participant))))
    (map-set meeting-participants {meeting-id: meeting-id, participant: tx-sender}
      (merge participant {left-at: stacks-block-height, duration: session-duration}))
    (ok (map-set virtual-meetings meeting-id
      (merge meeting {current-participants: (- (get current-participants meeting) u1)})))))

(define-public (create-breakout-room (meeting-id uint) (room-id uint) (name (string-ascii 64)) (topic (string-ascii 128)))
  (let ((meeting (unwrap! (map-get? virtual-meetings meeting-id) err-not-found)))
    (asserts! (is-eq tx-sender (get host meeting)) err-owner-only)
    (ok (map-set breakout-rooms {meeting-id: meeting-id, room-id: room-id}
      {room-name: name, participants: (list ), topic: topic}))))

(define-public (end-meeting (meeting-id uint))
  (let ((meeting (unwrap! (map-get? virtual-meetings meeting-id) err-not-found)))
    (asserts! (is-eq tx-sender (get host meeting)) err-owner-only)
    (ok (map-set virtual-meetings meeting-id (merge meeting {active: false})))))
