;; =============================================================================
;; EventChain Smart Contract - Event Ticketing System
;; =============================================================================

;; =============================================================================
;; ERROR CONSTANTS - Organized by Category
;; =============================================================================

;; 100-199: Ticket Purchase Errors
(define-constant ERR-SOLD-OUT u100)                    ;; Event has no more tickets available
(define-constant ERR-ALREADY-OWNS-TICKET u101)         ;; User already owns a ticket for this event
(define-constant ERR-PAYMENT-FAILED u102)              ;; STX transfer payment failed
(define-constant ERR-EVENT-NOT-FOUND u103)             ;; Event ID does not exist

;; 200-299: Ticket Transfer Errors
(define-constant ERR-TICKET-USED u201)                 ;; Cannot transfer a used ticket
(define-constant ERR-NO-TICKET u202)                   ;; User does not own a ticket for this event
(define-constant ERR-TRANSFER-FAILED u203)             ;; Ticket transfer operation failed
(define-constant ERR-INVALID-RECIPIENT u204)           ;; Cannot transfer ticket to yourself

;; 300-399: Check-in Errors
(define-constant ERR-TICKET-ALREADY-USED u301)         ;; Ticket has already been used for check-in
(define-constant ERR-USER-NO-TICKET u302)              ;; User does not have a ticket for this event
(define-constant ERR-NOT-EVENT-CREATOR u303)           ;; Only event creator can perform check-ins
(define-constant ERR-EVENT-NOT-FOUND-CHECKIN u304)     ;; Event not found during check-in
(define-constant ERR-TICKET-ID-NOT-FOUND u305)         ;; Ticket ID does not exist
(define-constant ERR-TICKET-OWNER-UPDATE-FAILED u306)  ;; Failed to update ticket owner information

;; 400-499: Authorization & Validation Errors
(define-constant ERR-NOT-ADMIN u401)                   ;; Only admin can perform this action
(define-constant ERR-NOT-ORGANIZER u402)              ;; Only approved organizers can create events
(define-constant ERR-INVALID-INPUT u403)               ;; Input field cannot be empty
(define-constant ERR-INVALID-TIMESTAMP u405)          ;; Event timestamp must be in the future
(define-constant ERR-INVALID-TICKET-COUNT u406)       ;; Event must have at least 1 ticket

;; 500-599: Event Management Errors
(define-constant ERR-NOT-EVENT-OWNER u501)            ;; Only event creator can cancel event
(define-constant ERR-EVENT-NOT-FOUND-CANCEL u502)     ;; Event not found during cancellation
(define-constant ERR-NO-REFUND-TICKET u504)           ;; User does not have a ticket to refund
(define-constant ERR-EVENT-NOT-FOUND-REFUND u505)     ;; Event not found during refund
(define-constant ERR-EVENT-NOT-CANCELLED u506)        ;; Event must be cancelled to get refund

;; =============================================================================
;; GLOBAL STATE VARIABLES
;; =============================================================================
(define-data-var next-event-id uint u1)
(define-data-var next-ticket-id uint u1)
(define-data-var admin principal tx-sender)


;; ---- Maps ----
;; Maps to store events and tickets
(define-map events {event-id: uint} {
    creator: principal,
    name: (string-utf8 100),
    location: (string-utf8 100),
    timestamp: uint,
    price: uint,
    total-tickets: uint,
    tickets-sold: uint,
    created-timestamp: uint,
    image: (string-utf8 100)
})

;; ticket mapping (by event-id and owner)
(define-map tickets {event-id: uint, owner: principal} {used: bool, ticket-id: uint})

;;  Reverse mapping from ticket-id to owner address for easy lookup
(define-map ticket-owners {ticket-id: uint} {
    owner: principal,
    event-id: uint,
    used: bool,
    purchase-timestamp: uint
})

(define-map organizers {organizer: principal} {is-approved: bool})
(define-map event-cancelled {event-id: uint} bool)




;; ---- Admin Function ----
(define-public (add-organizer (who principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR-NOT-ADMIN))
    (map-set organizers {organizer: who} {is-approved: true})
    (ok true))
)


;; =============================================================================
;; EVENT CREATION - Create a new event
;; =============================================================================
;; @desc: Create a new event with specified details (only approved organizers can create events)
;; @param: name - Event name (cannot be empty)
;; @param: location - Event location (cannot be empty) 
;; @param: timestamp - When the event occurs (must be in the future)
;; @param: price - Price per ticket (can be 0 for free events)
;; @param: total-tickets - Total number of tickets available (must be > 0)
;; @param: image - URL/path to event image (optional, can be empty)
;; @returns: (ok event-id) on success, (err error-code) on failure

(define-public (create-event
    (name (string-utf8 100))
    (location (string-utf8 100))
    (timestamp uint)
    (price uint)
    (total-tickets uint)
    (image (string-utf8 100))
  )
  (begin
    ;; Validate organizer authorization first
    (asserts! (is-some (map-get? organizers {organizer: tx-sender})) (err ERR-NOT-ORGANIZER))
    
    ;; Validate all input parameters to prevent untrusted input
    (asserts! (> (len name) u0) (err ERR-INVALID-INPUT))
    (asserts! (> (len location) u0) (err ERR-INVALID-INPUT))
    (asserts! (> timestamp stacks-block-height) (err ERR-INVALID-TIMESTAMP))
    (asserts! (> total-tickets u0) (err ERR-INVALID-TICKET-COUNT))
    ;; NB: price can be 0 for free events, so no validation needed
    
    ;; Create the event record
    (let ((event-id (var-get next-event-id)))
      (map-set events
        (tuple (event-id event-id))
        (tuple
          (creator tx-sender)
          (name name)
          (location location)
          (timestamp timestamp)
          (price price)
          (total-tickets total-tickets)
          (tickets-sold u0)
          (created-timestamp stacks-block-height)
          (image image)))
      
      ;; Increment event counter
      (var-set next-event-id (+ event-id u1))
      
      ;; Return the new event ID
      (ok event-id)
    )
  )
)


;; =============================================================================
;; TICKET PURCHASE - Purchase a ticket for an event
;; =============================================================================
;; @desc: Purchase a ticket for an event, returns unique ticket ID on success
;; @param: event-id - The ID of the event to purchase a ticket for
;; @returns: (ok ticket-id) on success, (err error-code) on failure

(define-public (buy-ticket (event-id uint))
  (match (map-get? events (tuple (event-id event-id)))
    event-data
    (let (
      (ticket-price (get price event-data))
      (tickets-sold (get tickets-sold event-data))
      (total-tickets (get total-tickets event-data))
      (new-ticket-id (var-get next-ticket-id))
      (event-creator (get creator event-data))
    )
      ;; Input validation and business logic checks
      (asserts! (< tickets-sold total-tickets) (err ERR-SOLD-OUT))
      (asserts! (is-none (map-get? tickets (tuple (event-id event-id) (owner tx-sender)))) 
                (err ERR-ALREADY-OWNS-TICKET))
      
      ;; Process payment 
      (try! (stx-transfer? ticket-price tx-sender event-creator))
      
      ;; Create ticket records atomically
      (map-set tickets (tuple (event-id event-id) (owner tx-sender))
        (tuple (used false) (ticket-id new-ticket-id)))
      
      (map-set ticket-owners (tuple (ticket-id new-ticket-id))
        (tuple 
          (owner tx-sender)
          (event-id event-id)
          (used false)
          (purchase-timestamp stacks-block-height)))
      
      ;; Update counters
      (var-set next-ticket-id (+ new-ticket-id u1))
      (map-set events (tuple (event-id event-id))
        (merge event-data (tuple (tickets-sold (+ tickets-sold u1)))))
      
      ;; Return the new ticket ID
      (ok new-ticket-id)
    )
    (err ERR-EVENT-NOT-FOUND)
  )
)


;; =============================================================================
;; TICKET TRANSFER - Transfer a ticket to another user
;; =============================================================================
;; @desc: Transfer ownership of a ticket to another user (ticket must be unused)
;; @param: event-id - The ID of the event 
;; @param: to - The principal address to transfer the ticket to
;; @returns: (ok true) on successful transfer, (err error-code) on failure

(define-public (transfer-ticket (event-id uint) (recipient principal))
  ;; Get ticket data and validate user owns the ticket
  (let ((ticket-data (unwrap! (map-get? tickets (tuple (event-id event-id) (owner tx-sender)))
                               (err ERR-NO-TICKET))))
    
    ;; Extract ticket details
    (let ((ticket-id (get ticket-id ticket-data)))
      
      ;; Validate transfer conditions
      (asserts! (not (get used ticket-data)) (err ERR-TICKET-USED))
      (asserts! (not (is-eq tx-sender recipient)) (err ERR-INVALID-RECIPIENT))
      
      ;; Get ticket owner data for reverse mapping update
      (let ((ticket-owner-data (unwrap! (map-get? ticket-owners {ticket-id: ticket-id})
                                        (err ERR-TRANSFER-FAILED))))
        
        ;; Update primary ticket mapping - transfer ownership
        (map-delete tickets (tuple (event-id event-id) (owner tx-sender)))
        (map-set tickets (tuple (event-id event-id) (owner recipient))
          (tuple (used false) (ticket-id ticket-id)))
        
        ;; Update reverse ticket mapping - change owner
        (map-set ticket-owners (tuple (ticket-id ticket-id))
          (merge ticket-owner-data (tuple (owner recipient))))
        
        ;; Return success
        (ok true)
      )
    )
  )
)

;; ----  Check-In by Ticket ID ----
;; =============================================================================
;; CHECK-IN BY TICKET ID - Check in a ticket using its unique ID
;; =============================================================================
;; @desc: Check in a ticket using its unique ticket ID (only event creator can do this)
;; @param: ticket-id - The unique ID of the ticket to check in
;; @returns: (ok ticket-info) with attendee details on success, (err error-code) on failure

(define-public (check-in-by-ticket-id (ticket-id uint))
  ;; Get ticket info and validate ticket exists
  (let ((ticket-info (unwrap! (map-get? ticket-owners (tuple (ticket-id ticket-id)))
                               (err ERR-TICKET-ID-NOT-FOUND))))
    
    ;; Extract ticket details
    (let (
      (ticket-owner (get owner ticket-info))
      (event-id (get event-id ticket-info))
      (is-already-used (get used ticket-info))
    )
      ;; Get event data and validate event exists
      (let ((event-data (unwrap! (map-get? events (tuple (event-id event-id)))
                                 (err ERR-EVENT-NOT-FOUND-CHECKIN))))
        
        ;; Validate authorization - only event creator can check-in tickets
        (asserts! (is-eq tx-sender (get creator event-data)) (err ERR-NOT-EVENT-CREATOR))
        
        ;; Validate ticket hasn't been used
        (asserts! (not is-already-used) (err ERR-TICKET-ALREADY-USED))
        
        ;; Update both ticket mappings - mark as used
        (map-set tickets (tuple (event-id event-id) (owner ticket-owner))
          (tuple (used true) (ticket-id ticket-id)))
        
        (map-set ticket-owners (tuple (ticket-id ticket-id))
          (merge ticket-info (tuple (used true))))
        
        ;; Return success with attendee information
        (ok {
          ticket-owner: ticket-owner,
          event-id: event-id,
          ticket-id: ticket-id
        })
      )
    )
  )
)

;; =============================================================================
;; CHECK-IN BY USER ADDRESS - Check in a ticket using attendee address
;; =============================================================================
;; @desc: Check in a ticket using the attendee's address (only event creator can do this)
;; @param: event-id - The ID of the event
;; @param: user - The principal address of the ticket holder
;; @returns: (ok true) on success, (err error-code) on failure

(define-public (check-in-ticket (event-id uint) (user principal))
  ;; Get event data and validate event exists
  (let ((event-data (unwrap! (map-get? events (tuple (event-id event-id))) 
                              (err ERR-EVENT-NOT-FOUND-CHECKIN))))
    
    ;; Validate authorization - only event creator can check-in attendees
    (asserts! (is-eq tx-sender (get creator event-data)) (err ERR-NOT-EVENT-CREATOR))
    
    ;; Get ticket data and validate user has a ticket
    (let ((ticket-data (unwrap! (map-get? tickets (tuple (event-id event-id) (owner user)))
                                (err ERR-USER-NO-TICKET))))
      
      ;; Validate ticket hasn't been used
      (asserts! (not (get used ticket-data)) (err ERR-TICKET-ALREADY-USED))
      
      ;; Extract ticket ID for reverse mapping update
      (let ((ticket-id (get ticket-id ticket-data)))
        
        ;; Update primary ticket mapping - mark as used
        (map-set tickets (tuple (event-id event-id) (owner user))
          (tuple (used true) (ticket-id ticket-id)))
        
        ;; Update reverse ticket mapping - mark as used
        (let ((ticket-owner-data (unwrap! (map-get? ticket-owners {ticket-id: ticket-id})
                                          (err ERR-TICKET-OWNER-UPDATE-FAILED))))
          (map-set ticket-owners (tuple (ticket-id ticket-id))
            (merge ticket-owner-data (tuple (used true))))
          
          ;; Return success
          (ok true)
        )
      )
    )
  )
)
;; =============================================================================
;; EVENT CANCELLATION - Cancel an event (only by creator)
;; =============================================================================
;; @desc: Cancel an event, allowing ticket holders to request refunds
;; @param: event-id - The ID of the event to cancel
;; @returns: (ok true) on success, (err error-code) on failure

(define-public (cancel-event (event-id uint))
  ;; Get event data and validate event exists
  (let ((event-data (unwrap! (map-get? events (tuple (event-id event-id))) 
                              (err ERR-EVENT-NOT-FOUND-CANCEL))))
    
    ;; Validate authorization - only event creator can cancel
    (asserts! (is-eq tx-sender (get creator event-data)) (err ERR-NOT-EVENT-OWNER))
    
    ;; Mark event as cancelled
    (map-set event-cancelled (tuple (event-id event-id)) true)
    
    ;; Return success
    (ok true)
  )
)

;; =============================================================================
;; TICKET REFUND - Request refund for cancelled event
;; =============================================================================
;; @desc: Request refund for a ticket when event is cancelled
;; @param: event-id - The ID of the cancelled event
;; @returns: (ok true) on successful refund, (err error-code) on failure

(define-public (refund-ticket (event-id uint))
  ;; Check if event is cancelled
  (let ((cancelled-status (default-to false (map-get? event-cancelled (tuple (event-id event-id))))))
    (asserts! cancelled-status (err ERR-EVENT-NOT-CANCELLED))
    
    ;; Get event data and validate event exists
    (let ((event-data (unwrap! (map-get? events (tuple (event-id event-id)))
                               (err ERR-EVENT-NOT-FOUND-REFUND))))
      
      ;; Get ticket data and validate user has a ticket
      (let ((ticket-data (unwrap! (map-get? tickets (tuple (event-id event-id) (owner tx-sender)))
                                  (err ERR-NO-REFUND-TICKET))))
        
        ;; Extract refund details
        (let (
          (ticket-id (get ticket-id ticket-data))
          (refund-amount (get price event-data))
          (event-creator (get creator event-data))
        )
          ;; Process refund transfer from creator back to ticket holder
          (try! (stx-transfer? refund-amount event-creator tx-sender))
          
          ;; Clean up ticket records - remove from both mappings
          (map-delete tickets (tuple (event-id event-id) (owner tx-sender)))
          (map-delete ticket-owners (tuple (ticket-id ticket-id)))
          
          ;; Return success
          (ok true)
        )
      )
    )
  )
)

;; ---- Read-only Functions ----

;; Get event details by ID
(define-read-only (get-event (event-id uint))
  (map-get? events {event-id: event-id})
)

;; Check if an address is an approved organizer
(define-read-only (is-organizer (who principal))
  (default-to false (get is-approved (map-get? organizers {organizer: who})))
)

;; Get admin address
(define-read-only (get-admin)
  (var-get admin)
)

;; Get next event ID
(define-read-only (get-next-event-id)
  (var-get next-event-id)
)

;; Get next ticket ID
(define-read-only (get-next-ticket-id)
  (var-get next-ticket-id)
)

;; Get ticket info for a user and event
(define-read-only (get-ticket (event-id uint) (owner principal))
  (map-get? tickets {event-id: event-id, owner: owner})
)

;; ---- Read-only Functions for Ticket ID Lookup ----

;; Get ticket owner by ticket ID
(define-read-only (get-ticket-owner (ticket-id uint))
  (map-get? ticket-owners {ticket-id: ticket-id})
)

;; Get ticket info by ticket ID (includes event details)
(define-read-only (get-ticket-info (ticket-id uint))
  (match (map-get? ticket-owners (tuple (ticket-id ticket-id)))
    ticket-info
    (let (
          (event-id (get event-id ticket-info))
         )
      (match (map-get? events (tuple (event-id event-id)))
        event-data
        (some {
          ticket-id: ticket-id,
          owner: (get owner ticket-info),
          event-id: event-id,
          event-name: (get name event-data),
          event-location: (get location event-data),
          event-timestamp: (get timestamp event-data),
          used: (get used ticket-info),
          purchase-timestamp: (get purchase-timestamp ticket-info)
        })
        none
      )
    )
    none
  )
)

;; Check if a ticket ID is valid and not used
(define-read-only (is-ticket-valid (ticket-id uint))
  (match (map-get? ticket-owners (tuple (ticket-id ticket-id)))
    ticket-info
    (not (get used ticket-info))
    false))

;; Check if event is cancelled
(define-read-only (is-event-cancelled (event-id uint))
  (default-to false (map-get? event-cancelled {event-id: event-id}))
)

;; Get total events count
(define-read-only (get-total-events)
  (- (var-get next-event-id) u1)
)

;; Get organizer approval status
(define-read-only (get-organizer-status (organizer principal))
  (map-get? organizers {organizer: organizer})
)

;; Get events count for a specific organizer
(define-read-only (get-organizer-events-count (organizer principal))
  (let (
    (total-events (- (var-get next-event-id) u1))
  )
    (if (is-eq total-events u0)
      u0
      (get count (fold count-organizer-events 
        (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20 u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34 u35 u36 u37 u38 u39 u40 u41 u42 u43 u44 u45 u46 u47 u48 u49 u50) 
        {organizer: organizer, count: u0, total: total-events}
      ))
    )
  )
)

;; Helper function to count events by organizer
(define-private (count-organizer-events (event-id uint) (acc {organizer: principal, count: uint, total: uint}))
  (if (> event-id (get total acc))
    acc ;; Stop if event-id exceeds total events
    (match (map-get? events {event-id: event-id})
      event-data
      (if (is-eq (get creator event-data) (get organizer acc))
        {organizer: (get organizer acc), count: (+ (get count acc) u1), total: (get total acc)}
        acc
      )
      acc ;; No event found at this ID
    )
  )
)

;; ---- Helper Functions ----

;; Get all events created by a specific organizer (returns list of event IDs)
(define-read-only (get-organizer-events (organizer principal))
  (let (
    (total-events (- (var-get next-event-id) u1))
  )
    (if (is-eq total-events u0)
      (list)
      (get events (fold collect-organizer-events 
        (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20 u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34 u35 u36 u37 u38 u39 u40 u41 u42 u43 u44 u45 u46 u47 u48 u49 u50) 
        {organizer: organizer, events: (list), total: total-events}
      ))
    )
  )
)

;; Helper function to collect events by organizer
(define-private (collect-organizer-events (event-id uint) (acc {organizer: principal, events: (list 50 uint), total: uint}))
  (if (> event-id (get total acc))
    acc ;; Stop if event-id exceeds total events
    (match (map-get? events {event-id: event-id})
      event-data
      (if (is-eq (get creator event-data) (get organizer acc))
        {
          organizer: (get organizer acc), 
          events: (unwrap! (as-max-len? (append (get events acc) event-id) u50) acc),
          total: (get total acc)
        }
        acc
      )
      acc ;; No event found at this ID
    )
  )
)
