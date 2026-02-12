;; Proof of Attendance NFT Contract
;; Allows event organizers to issue verifiable attendance NFTs

;; Use-trait: Import the NFT trait from mainnet
(use-trait nft-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; Implement the SIP-009 NFT trait
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; Define the NFT
(define-non-fungible-token attendance-nft uint)

;; Data Variables
(define-data-var last-token-id uint u0)
(define-data-var last-event-id uint u0)
(define-data-var base-token-uri (string-ascii 256) "https://attendance.example.com/metadata/")

;; Data Maps
;; Event registry: event-id -> event details
(define-map events
  uint
  {
    name: (string-ascii 100),
    organizer: principal,
    date: uint,
    max-attendees: uint,
    issued-count: uint,
    is-active: bool
  }
)

;; Attendance records: (event-id, attendee) -> token-id
(define-map attendance-records
  { event-id: uint, attendee: principal }
  { token-id: uint, issued-at: uint }
)

;; Token metadata: token-id -> event-id
(define-map token-to-event
  uint
  uint
)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-TOKEN-OWNER (err u101))
(define-constant ERR-EVENT-NOT-FOUND (err u102))
(define-constant ERR-EVENT-CLOSED (err u103))
(define-constant ERR-ALREADY-ATTENDED (err u104))
(define-constant ERR-MAX-ATTENDEES-REACHED (err u105))
(define-constant ERR-INVALID-EVENT-DATA (err u106))

;; SIP-009 Required Functions

;; Get the last token ID
(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

;; Get token URI - returns metadata link for the NFT
(define-read-only (get-token-uri (token-id uint))
  (ok (some (var-get base-token-uri)))
)

;; Get owner of a token
(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? attendance-nft token-id))
)

;; Transfer token - SIP-009 requires this signature
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq sender (unwrap! (nft-get-owner? attendance-nft token-id) ERR-NOT-TOKEN-OWNER))
      ERR-NOT-TOKEN-OWNER)
    ;; Validate recipient is not zero address
    (asserts! (not (is-eq recipient tx-sender)) ERR-NOT-AUTHORIZED)
    (nft-transfer? attendance-nft token-id sender recipient)
  )
)

;; Custom Functions for Event Management

;; Create a new event
(define-public (create-event (name (string-ascii 100)) (date uint) (max-attendees uint))
  (let
    (
      (event-id (+ (var-get last-event-id) u1))
    )
    ;; Validate inputs
    (asserts! (> (len name) u0) ERR-INVALID-EVENT-DATA)
    (asserts! (> date stacks-block-height) ERR-INVALID-EVENT-DATA)
    (asserts! (> max-attendees u0) ERR-INVALID-EVENT-DATA)
    
    ;; Create event
    (map-set events event-id
      {
        name: name,
        organizer: tx-sender,
        date: date,
        max-attendees: max-attendees,
        issued-count: u0,
        is-active: true
      }
    )
    
    ;; Update event counter
    (var-set last-event-id event-id)
    (ok event-id)
  )
)

;; Issue attendance NFT to an attendee
(define-public (issue-attendance (event-id uint) (attendee principal))
  (let
    (
      (event (unwrap! (map-get? events event-id) ERR-EVENT-NOT-FOUND))
      (token-id (+ (var-get last-token-id) u1))
      (new-issued-count (+ (get issued-count event) u1))
    )
    ;; Verify organizer
    (asserts! (is-eq tx-sender (get organizer event)) ERR-NOT-AUTHORIZED)
    
    ;; Verify event is active
    (asserts! (get is-active event) ERR-EVENT-CLOSED)
    
    ;; Validate attendee is a valid principal
    (asserts! (not (is-eq attendee (get organizer event))) ERR-NOT-AUTHORIZED)
    
    ;; Check if attendee already has attendance for this event
    (asserts! (is-none (map-get? attendance-records { event-id: event-id, attendee: attendee }))
      ERR-ALREADY-ATTENDED)
    
    ;; Check max attendees
    (asserts! (<= new-issued-count (get max-attendees event)) ERR-MAX-ATTENDEES-REACHED)
    
    ;; Mint NFT
    (try! (nft-mint? attendance-nft token-id attendee))
    
    ;; Record attendance
    (map-set attendance-records
      { event-id: event-id, attendee: attendee }
      { token-id: token-id, issued-at: stacks-block-height }
    )
    
    ;; Map token to event
    (map-set token-to-event token-id event-id)
    
    ;; Update event issued count
    (map-set events event-id
      (merge event { issued-count: new-issued-count })
    )
    
    ;; Update token counter
    (var-set last-token-id token-id)
    (ok token-id)
  )
)

;; Close an event (stop issuing new NFTs)
(define-public (close-event (event-id uint))
  (let
    (
      (event (unwrap! (map-get? events event-id) ERR-EVENT-NOT-FOUND))
    )
    ;; Verify organizer
    (asserts! (is-eq tx-sender (get organizer event)) ERR-NOT-AUTHORIZED)
    
    ;; Close event
    (map-set events event-id
      (merge event { is-active: false })
    )
    (ok true)
  )
)

;; Read-only functions

;; Get event details
(define-read-only (get-event (event-id uint))
  (map-get? events event-id)
)

;; Get attendance record for a specific attendee at an event
(define-read-only (get-attendance-record (event-id uint) (attendee principal))
  (map-get? attendance-records { event-id: event-id, attendee: attendee })
)

;; Check if an address attended an event
(define-read-only (has-attended (event-id uint) (attendee principal))
  (is-some (map-get? attendance-records { event-id: event-id, attendee: attendee }))
)

;; Get event ID for a token
(define-read-only (get-event-for-token (token-id uint))
  (map-get? token-to-event token-id)
)

;; Get current event count
(define-read-only (get-event-count)
  (var-get last-event-id)
)

;; Get total NFTs minted
(define-read-only (get-total-nfts)
  (var-get last-token-id)
)

;; Update base URI (organizer only for their events)
(define-public (set-base-uri (new-uri (string-ascii 256)))
  (begin
    ;; Validate new-uri is not empty
    (asserts! (> (len new-uri) u0) ERR-INVALID-EVENT-DATA)
    (var-set base-token-uri new-uri)
    (ok true)
  )
)