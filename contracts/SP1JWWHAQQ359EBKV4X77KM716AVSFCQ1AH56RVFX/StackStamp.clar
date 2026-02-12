;; title: StackStamp
;; version: 1.0
;; summary: On-chain event attendance check-in system
;; description: A blockchain-based attendance tracker where event creators can publish events
;;              and users can check in with verifiable proof stored permanently on-chain.

;; traits
;;

;; token definitions
;;

;; constants
;;
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_EVENT_NOT_FOUND (err u100))
(define-constant ERR_ALREADY_CHECKED_IN (err u101))
(define-constant ERR_INVALID_NAME (err u102))
(define-constant ERR_NOT_EVENT_CREATOR (err u103))

;; data vars
;;
(define-data-var next-event-id uint u0)

;; data maps
;;
(define-map events uint {creator: principal, active: bool})
(define-map attendance {event-id: uint, attendee: principal} uint)

;; public functions
;;

(define-public (create-event (name (string-ascii 100)))
  (let
    (
      (event-id (var-get next-event-id))
      (creator tx-sender)
    )
    (asserts! (> (len name) u0) ERR_INVALID_NAME)

    (map-set events event-id {creator: creator, active: true})
    (var-set next-event-id (+ event-id u1))

    (print {
      event: "event-created",
      event-id: event-id,
      creator: creator,
      name: name,
      block-time: stacks-block-time
    })

    (ok event-id)
  )
)

(define-public (check-in (event-id uint))
  (let
    (
      (attendee tx-sender)
      (event-data (unwrap! (map-get? events event-id) ERR_EVENT_NOT_FOUND))
      (check-in-time stacks-block-time)
    )
    (asserts! (get active event-data) ERR_EVENT_NOT_FOUND)
    (asserts! (is-none (map-get? attendance {event-id: event-id, attendee: attendee})) ERR_ALREADY_CHECKED_IN)

    (map-set attendance {event-id: event-id, attendee: attendee} check-in-time)

    (print {
      event: "checked-in",
      event-id: event-id,
      attendee: attendee,
      check-in-time: check-in-time
    })

    (ok check-in-time)
  )
)

(define-public (close-event (event-id uint))
  (let
    (
      (event-data (unwrap! (map-get? events event-id) ERR_EVENT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get creator event-data)) ERR_NOT_EVENT_CREATOR)
    (map-set events event-id (merge event-data {active: false}))
    (ok true)
  )
)

;; read only functions
;;

(define-read-only (get-event (event-id uint))
  (map-get? events event-id)
)

(define-read-only (get-attendance (event-id uint) (attendee principal))
  (map-get? attendance {event-id: event-id, attendee: attendee})
)

(define-read-only (did-attend (event-id uint) (attendee principal))
  (is-some (map-get? attendance {event-id: event-id, attendee: attendee}))
)