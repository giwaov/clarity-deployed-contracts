;; title: ticketing
;; version: 1.0.0
;; summary: A smart contract for managing events and ticket sales
;; description: This contract allows event organizers to create events, sell tickets, and enables ticket holders to transfer their tickets. Includes admin functions for platform management.

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;; Admin will be set to deployer address - initialized to first wallet for testing
(define-data-var admin principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; data maps
;; Event information: event-id -> (name, description, venue, date, price, total-tickets, sold-tickets, active)
(define-map events
  { event-id: uint }
  {
    name: (string-ascii 200),
    description: (string-ascii 500),
    venue: (string-ascii 200),
    date: uint,
    price: uint,
    total-tickets: uint,
    sold-tickets: uint,
    active: bool
  }
)

;; Ticket ownership: ticket-id -> owner
(define-map tickets
  { ticket-id: uint }
  principal
)

;; Ticket to event mapping: ticket-id -> event-id
(define-map ticket-to-event
  { ticket-id: uint }
  uint
)

;; Event ID counter
(define-data-var event-id-counter uint u0)

;; Ticket ID counter
(define-data-var ticket-id-counter uint u0)

;; public functions

;; Create a new event (admin only)
(define-public (create-event
  (name (string-ascii 200))
  (description (string-ascii 500))
  (venue (string-ascii 200))
  (date uint)
  (price uint)
  (total-tickets uint)
)
  (let (
    (caller tx-sender)
    (current-admin (var-get admin))
  )
    (asserts! (is-eq caller current-admin) (err u1001))
    (asserts! (<= total-tickets u10000) (err u1002))
    (asserts! (> date u0) (err u1003))
    (let (
      (event-id (+ (var-get event-id-counter) u1))
    )
      (map-set events
        { event-id: event-id }
        {
          name: name,
          description: description,
          venue: venue,
          date: date,
          price: price,
          total-tickets: total-tickets,
          sold-tickets: u0,
          active: true
        }
      )
      (var-set event-id-counter event-id)
      (ok event-id)
    )
  )
)

;; Buy a ticket for an event
(define-public (buy-ticket
  (event-id uint)
  (amount uint)
)
  (let (
    (caller tx-sender)
    (event-info (map-get? events { event-id: event-id }))
  )
    (asserts! (is-some event-info) (err u2001))
    (let (
      (event (unwrap-panic event-info))
    )
      (asserts! (get active event) (err u2002))
      (asserts! (<= amount u10) (err u2003))
      (asserts! (<= (+ (get sold-tickets event) amount) (get total-tickets event)) (err u2004))
      (let (
        (total-cost (* amount (get price event)))
        (stx-amount (stx-get-balance caller))
      )
        (asserts! (>= stx-amount total-cost) (err u2005))
        (try! (stx-transfer? total-cost caller (var-get admin)))
        (let (
          (new-sold (+ (get sold-tickets event) amount))
          (updated-event {
            name: (get name event),
            description: (get description event),
            venue: (get venue event),
            date: (get date event),
            price: (get price event),
            total-tickets: (get total-tickets event),
            sold-tickets: new-sold,
            active: (get active event)
          })
        )
          (map-set events { event-id: event-id } updated-event)
          (mint-tickets-direct event-id caller amount)
          (ok (list amount))
        )
      )
    )
  )
)

;; Transfer a ticket to another principal
(define-public (transfer-ticket
  (ticket-id uint)
  (new-owner principal)
)
  (let (
    (caller tx-sender)
    (current-owner (map-get? tickets { ticket-id: ticket-id }))
  )
    (asserts! (is-some current-owner) (err u3001))
    (asserts! (is-eq caller (unwrap-panic current-owner)) (err u3002))
    (map-set tickets { ticket-id: ticket-id } new-owner)
    (ok true)
  )
)

;; Set a new admin (admin only)
(define-public (set-admin
  (new-admin principal)
)
  (let (
    (caller tx-sender)
    (current-admin (var-get admin))
  )
    (asserts! (is-eq caller current-admin) (err u4001))
    (var-set admin new-admin)
    (ok true)
  )
)

;; Update event information (admin only)
(define-public (update-event
  (event-id uint)
  (name (optional (string-ascii 200)))
  (description (optional (string-ascii 500)))
  (venue (optional (string-ascii 200)))
  (price (optional uint))
)
  (let (
    (caller tx-sender)
    (current-admin (var-get admin))
    (event-info (map-get? events { event-id: event-id }))
  )
    (asserts! (is-eq caller current-admin) (err u5001))
    (asserts! (is-some event-info) (err u5002))
    (let (
      (event (unwrap-panic event-info))
      (updated-event {
        name: (if (is-some name) (unwrap-panic name) (get name event)),
        description: (if (is-some description) (unwrap-panic description) (get description event)),
        venue: (if (is-some venue) (unwrap-panic venue) (get venue event)),
        date: (get date event),
        price: (if (is-some price) (unwrap-panic price) (get price event)),
        total-tickets: (get total-tickets event),
        sold-tickets: (get sold-tickets event),
        active: (get active event)
      })
    )
      (map-set events { event-id: event-id } updated-event)
      (ok true)
    )
  )
)

;; Cancel an event (admin only)
(define-public (cancel-event
  (event-id uint)
)
  (let (
    (caller tx-sender)
    (current-admin (var-get admin))
    (event-info (map-get? events { event-id: event-id }))
  )
    (asserts! (is-eq caller current-admin) (err u6001))
    (asserts! (is-some event-info) (err u6002))
    (let (
      (event (unwrap-panic event-info))
      (updated-event {
        name: (get name event),
        description: (get description event),
        venue: (get venue event),
        date: (get date event),
        price: (get price event),
        total-tickets: (get total-tickets event),
        sold-tickets: (get sold-tickets event),
        active: false
      })
    )
      (map-set events { event-id: event-id } updated-event)
      (ok true)
    )
  )
)

;; read only functions

;; Get event information
(define-read-only (get-event-info
  (event-id uint)
)
  (map-get? events { event-id: event-id })
)

;; Get ticket owner
(define-read-only (get-ticket-owner
  (ticket-id uint)
)
  (map-get? tickets { ticket-id: ticket-id })
)

;; Get event ID for a ticket
(define-read-only (get-ticket-event
  (ticket-id uint)
)
  (map-get? ticket-to-event { ticket-id: ticket-id })
)

;; Get current admin
(define-read-only (get-admin)
  (ok (var-get admin))
)

;; Get total number of events created
(define-read-only (get-total-events)
  (ok (var-get event-id-counter))
)

;; Get total number of tickets minted
(define-read-only (get-total-tickets)
  (ok (var-get ticket-id-counter))
)

;; Check if a principal owns a specific ticket
(define-read-only (is-ticket-owner
  (ticket-id uint)
  (owner principal)
)
  (let (
    (ticket-owner (map-get? tickets { ticket-id: ticket-id }))
  )
    (if (is-some ticket-owner)
      (ok (is-eq (unwrap-panic ticket-owner) owner))
      (ok false)
    )
  )
)

;; private functions

;; Mint tickets for a buyer (direct implementation to avoid recursion issues)
(define-private (mint-tickets-direct
  (event-id uint)
  (owner principal)
  (amount uint)
)
  (let (
    (base-id (var-get ticket-id-counter))
  )
    (begin
      (if (is-eq amount u1)
        (mint-single-ticket event-id owner base-id u1)
        (if (is-eq amount u2)
          (begin 
            (mint-single-ticket event-id owner base-id u1)
            (mint-single-ticket event-id owner base-id u2))
          (if (is-eq amount u3)
            (begin 
              (mint-single-ticket event-id owner base-id u1)
              (mint-single-ticket event-id owner base-id u2)
              (mint-single-ticket event-id owner base-id u3))
            (if (is-eq amount u4)
              (begin 
                (mint-single-ticket event-id owner base-id u1)
                (mint-single-ticket event-id owner base-id u2)
                (mint-single-ticket event-id owner base-id u3)
                (mint-single-ticket event-id owner base-id u4))
              (if (is-eq amount u5)
                (begin 
                  (mint-single-ticket event-id owner base-id u1)
                  (mint-single-ticket event-id owner base-id u2)
                  (mint-single-ticket event-id owner base-id u3)
                  (mint-single-ticket event-id owner base-id u4)
                  (mint-single-ticket event-id owner base-id u5))
                (if (is-eq amount u6)
                  (begin 
                    (mint-single-ticket event-id owner base-id u1)
                    (mint-single-ticket event-id owner base-id u2)
                    (mint-single-ticket event-id owner base-id u3)
                    (mint-single-ticket event-id owner base-id u4)
                    (mint-single-ticket event-id owner base-id u5)
                    (mint-single-ticket event-id owner base-id u6))
                  (if (is-eq amount u7)
                    (begin 
                      (mint-single-ticket event-id owner base-id u1)
                      (mint-single-ticket event-id owner base-id u2)
                      (mint-single-ticket event-id owner base-id u3)
                      (mint-single-ticket event-id owner base-id u4)
                      (mint-single-ticket event-id owner base-id u5)
                      (mint-single-ticket event-id owner base-id u6)
                      (mint-single-ticket event-id owner base-id u7))
                    (if (is-eq amount u8)
                      (begin 
                        (mint-single-ticket event-id owner base-id u1)
                        (mint-single-ticket event-id owner base-id u2)
                        (mint-single-ticket event-id owner base-id u3)
                        (mint-single-ticket event-id owner base-id u4)
                        (mint-single-ticket event-id owner base-id u5)
                        (mint-single-ticket event-id owner base-id u6)
                        (mint-single-ticket event-id owner base-id u7)
                        (mint-single-ticket event-id owner base-id u8))
                      (if (is-eq amount u9)
                        (begin 
                          (mint-single-ticket event-id owner base-id u1)
                          (mint-single-ticket event-id owner base-id u2)
                          (mint-single-ticket event-id owner base-id u3)
                          (mint-single-ticket event-id owner base-id u4)
                          (mint-single-ticket event-id owner base-id u5)
                          (mint-single-ticket event-id owner base-id u6)
                          (mint-single-ticket event-id owner base-id u7)
                          (mint-single-ticket event-id owner base-id u8)
                          (mint-single-ticket event-id owner base-id u9))
                        (begin 
                          (mint-single-ticket event-id owner base-id u1)
                          (mint-single-ticket event-id owner base-id u2)
                          (mint-single-ticket event-id owner base-id u3)
                          (mint-single-ticket event-id owner base-id u4)
                          (mint-single-ticket event-id owner base-id u5)
                          (mint-single-ticket event-id owner base-id u6)
                          (mint-single-ticket event-id owner base-id u7)
                          (mint-single-ticket event-id owner base-id u8)
                          (mint-single-ticket event-id owner base-id u9)
                          (mint-single-ticket event-id owner base-id u10))
                      )))))))))
      (var-set ticket-id-counter (+ base-id amount))
      true
    )
  )
)

;; Helper function to mint a single ticket
(define-private (mint-single-ticket
  (event-id uint)
  (owner principal)
  (base-id uint)
  (offset uint)
)
  (let (
    (current-ticket-id (+ base-id offset))
  )
    (map-set tickets { ticket-id: current-ticket-id } owner)
    (map-set ticket-to-event { ticket-id: current-ticket-id } event-id)
    true
  )
)
