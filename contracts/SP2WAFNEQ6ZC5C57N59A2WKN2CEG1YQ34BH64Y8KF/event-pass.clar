
(define-constant ERR-ZERO-SEATS (err u100)) ;; Error returned when an event is registered without any available seats.
(define-constant ERR-NO-SUCH-EVENT (err u101)) ;; Error returned when a caller references an event identifier that does not exist.
(define-constant ERR-SEAT-TAKEN (err u102)) ;; Error returned when an attempt is made to buy a seat that was already sold.
(define-constant ERR-INVALID-SEAT (err u103)) ;; Error returned when the requested seat number is out of the valid range.
(define-constant ERR-SOLD-OUT (err u104)) ;; Error returned when all tickets for the event have already been sold.
(define-constant ERR-NO-TICKET (err u105)) ;; Error returned when the contract cannot find metadata for a given ticket request.
(define-constant ERR-EVENT-INACTIVE (err u106)) ;; Error returned when a ticket action is attempted on an inactive event.
(define-constant ERR-NOT-CREATOR (err u107)) ;; Error returned when a non-creator attempts to manage an event.
(define-constant ERR-STATUS-TRANSITION (err u108)) ;; Error returned when an invalid status transition is requested.
(define-constant ERR-INVALID-INPUT (err u109)) ;; Error returned when input validation fails for strings or other parameters.
(define-constant ERR-INVALID-PRICE (err u110)) ;; Error returned when price parameter is invalid or exceeds reasonable bounds.
(define-constant ERR-NOT-TICKET-OWNER (err u111)) ;; Error returned when a non-owner attempts to transfer a ticket.
(define-constant ERR-TRANSFER-TO-SELF (err u112)) ;; Error returned when attempting to transfer a ticket to yourself.
(define-constant ERR-ALREADY-REFUNDED (err u113)) ;; Error returned when attempting to refund a ticket that was already refunded.
(define-constant ERR-EVENT-NOT-CANCELED (err u114)) ;; Error returned when attempting to refund a ticket for a non-canceled event.
(define-constant ERR-PAYMENT-LISTS-MISMATCH (err u115)) ;; Error returned when recipient and amount lists have different lengths.
(define-constant ERR-EMPTY-PAYMENT-LIST (err u116)) ;; Error returned when payment list is empty.
(define-constant ERR-PAYMENT-FAILED (err u117)) ;; Error returned when a payment transfer fails.

(define-constant STATUS-ACTIVE u0) ;; Status code meaning the event is active and accepting ticket purchases.
(define-constant STATUS-CANCELED u1) ;; Status code meaning the event has been canceled by its creator.
(define-constant STATUS-ENDED u2) ;; Status code meaning the event has ended and should no longer sell tickets.

(define-constant MAX-PRICE u1000000000000) ;; Maximum price cap: 1 million STX in micro-STX units to prevent overflow issues.
(define-constant MAX-SEATS u10000) ;; Maximum seats per event: 10,000 to prevent excessive gas costs and ensure reasonable event sizes.

;; Private helper function to validate string input is not empty.
(define-private (is-valid-string (str (string-ascii 64)))
  (> (len str) u0))

;; Private helper function to validate date string input is not empty.
(define-private (is-valid-date (date (string-ascii 32)))
  (> (len date) u0))

;; Private helper function to validate metadata URI is not empty.
(define-private (is-valid-uri (uri (string-ascii 256)))
  (> (len uri) u0))

;; Private helper function to validate price is within reasonable bounds.
(define-private (is-valid-price (price uint))
  (<= price MAX-PRICE))

;; Private helper function to validate total seats is within reasonable bounds.
(define-private (is-valid-seats (seats uint))
  (and (> seats u0) (<= seats MAX-SEATS)))

(define-data-var next-event-id uint u1) ;; Persistent counter that assigns incremental identifiers to new events starting at 1.

(define-map events ;; Storage map that keeps the core metadata for each event keyed by its identifier.
  {event-id: uint} ;; Map key specification: the event identifier.
  {creator: principal, title: (string-ascii 64), date: (string-ascii 32), price: uint, total-seats: uint, sold-seats: uint, status: uint, metadata-uri: (string-ascii 256)}) ;; Map value specification describing who created the event, its ticketing details, lifecycle status, and metadata pointer.

(define-map tickets ;; Storage map that keeps track of each sold seat per event.
  {event-id: uint, seat: uint} ;; Map key specification combining the event identifier and seat number.
  {owner: principal, refunded: bool}) ;; Map value specification storing the principal that owns this seat and refund status.

(define-map token-metadata ;; Metadata URI map keyed by token identifier so wallets can resolve SIP-016 metadata.
  {event-id: uint, seat: uint}
  {uri: (string-ascii 256)})

(define-data-var contract-metadata-uri (optional (string-ascii 256)) none) ;; Optional contract-level metadata URI advertised through SIP-016.
(define-data-var deployer principal tx-sender) ;; Store the contract deployer as the owner.

(define-non-fungible-token ticket ;; Declaration of the NFT collection used to represent tickets.
  {event-id: uint, seat: uint}) ;; Each NFT token identifier is the pair of event identifier and seat number.

;; function contract-owner: returns the principal that deployed this contract.
(define-read-only (contract-owner)
  (var-get deployer))

;; function get-next-event-id: exposes the identifier that will be used for the next event registration.
(define-read-only (get-next-event-id) ;; Read-only helper that reveals the next event identifier that will be assigned.
  (var-get next-event-id)) ;; Return the current value of the incrementing event counter.

;; function get-event: returns stored metadata for a particular event id when available.
(define-read-only (get-event (event-id uint)) ;; Read-only helper that fetches the metadata for a single event.
  (map-get? events {event-id: event-id})) ;; Return the optional event record stored under the requested identifier.

;; function get-ticket-metadata: surfaces ownership details for a specific event seat.
(define-read-only (get-ticket-metadata (event-id uint) (seat uint)) ;; Read-only helper that returns the metadata tuple for a given ticket.
  (match (map-get? tickets {event-id: event-id, seat: seat}) ;; Attempt to find the ticket ownership record for the supplied event and seat.
    ticket-record ;; When the lookup succeeds, bind the ticket record to the name ticket-record.
    (ok {event-id: event-id, seat: seat, owner: (get owner ticket-record), refunded: (get refunded ticket-record)}) ;; Return the metadata as a response containing event id, seat, owner, and refund status.
    ERR-NO-TICKET)) ;; If the ticket does not exist, propagate an error indicating that no ticket was found.

;; function create-event: lets any caller register a new event with pricing, capacity, and metadata information.
(define-public (create-event (title (string-ascii 64)) (date (string-ascii 32)) (price uint) (total-seats uint) (metadata-uri (string-ascii 256))) ;; Public function that lets any principal register a new event.
  (begin ;; Sequence the event creation steps.
    ;; Input validation checks
    (asserts! (is-valid-string title) ERR-INVALID-INPUT) ;; Ensure title is not empty.
    (asserts! (is-valid-date date) ERR-INVALID-INPUT) ;; Ensure date is not empty.
    (asserts! (is-valid-uri metadata-uri) ERR-INVALID-INPUT) ;; Ensure metadata URI is not empty.
    (asserts! (is-valid-price price) ERR-INVALID-PRICE) ;; Ensure price is valid and within bounds.
    (asserts! (is-valid-seats total-seats) ERR-ZERO-SEATS) ;; Ensure seats are valid and within bounds.
    (let ((event-id (var-get next-event-id))) ;; Grab the current counter value so we can use it as the new event identifier.
      (begin ;; Sequence the state changes required to register the event.
        (map-set events ;; Persist the new event metadata into storage.
          {event-id: event-id} ;; Use the freshly allocated identifier as the map key.
          {creator: tx-sender, ;; Store the principal that created the event.
           title: title, ;; Record the human-readable event title supplied by the creator.
           date: date, ;; Record the event date string provided by the creator.
           price: price, ;; Record the ticket price in micro-STX units.
           total-seats: total-seats, ;; Record the total number of seats for sale.
           sold-seats: u0, ;; Initialize the sold tickets counter to zero.
           status: STATUS-ACTIVE, ;; Mark the event as active so ticket sales are permitted.
           metadata-uri: metadata-uri}) ;; Persist the metadata pointer used to render ticket NFTs.
        (var-set next-event-id (+ event-id u1)) ;; Increment the counter so the next event receives a new identifier.
        (print {event: "event-created", event-id: event-id, creator: tx-sender, title: title, price: price, total-seats: total-seats})
        (ok event-id))))) ;; Return the newly assigned event identifier wrapped in an ok response.

;; function purchase-ticket: sells a designated seat, updates inventory, and mints the ticket NFT.
(define-public (purchase-ticket (event-id uint) (seat uint)) ;; Public function that lets a user purchase a specific seat for an event.
  (let ((event-data (unwrap! (map-get? events {event-id: event-id}) ERR-NO-SUCH-EVENT))) ;; Retrieve the event metadata or abort if the event identifier is unknown.
    (let ((updated-sold (+ (get sold-seats event-data) u1))) ;; Pre-calculate the new sold count after this transaction.
      (begin ;; Sequence the validations and state updates needed to mint the ticket.
        (asserts! (is-eq (get status event-data) STATUS-ACTIVE) ERR-EVENT-INACTIVE) ;; Ensure the event is currently active before allowing a purchase.
        (asserts! (< (get sold-seats event-data) (get total-seats event-data)) ERR-SOLD-OUT) ;; Ensure the event still has capacity before processing the request.
        (asserts! (> seat u0) ERR-INVALID-SEAT) ;; Reject seat numbers less than one.
        (asserts! (<= seat (get total-seats event-data)) ERR-INVALID-SEAT) ;; Reject seat numbers that exceed the event's seat supply.
        (asserts! (is-none (map-get? tickets {event-id: event-id, seat: seat})) ERR-SEAT-TAKEN) ;; Ensure the seat has not already been sold.
        (asserts! (<= updated-sold (get total-seats event-data)) ERR-SOLD-OUT) ;; Ensure selling this ticket does not exceed the total seat count.
        (try! (stx-transfer? (get price event-data) tx-sender (get creator event-data))) ;; Collect payment by transferring the ticket price from the buyer to the event creator.
        (map-set tickets ;; Record the new ticket ownership entry.
          {event-id: event-id, ;; Use the event identifier as part of the composite key.
           seat: seat} ;; Use the seat number as the second part of the composite key.
          {owner: tx-sender, refunded: false}) ;; Store the buyer principal as the owner of this seat and set refunded to false.
        (map-set events ;; Update the event metadata to reflect the incremented sold count.
          {event-id: event-id} ;; Target the existing event record using its identifier.
          {creator: (get creator event-data), ;; Preserve the event creator's principal.
           title: (get title event-data), ;; Preserve the original event title.
           date: (get date event-data), ;; Preserve the event date value.
           price: (get price event-data), ;; Preserve the ticket price.
           total-seats: (get total-seats event-data), ;; Preserve the total seat count.
           sold-seats: updated-sold, ;; Replace the sold tickets counter with the new value.
           status: (get status event-data), ;; Keep the event status unchanged during the sale.
           metadata-uri: (get metadata-uri event-data)}) ;; Preserve the metadata pointer when updating the record.
        (map-set token-metadata ;; Store the metadata URI for this minted ticket to satisfy SIP-016 lookups.
          {event-id: event-id, seat: seat}
          {uri: (get metadata-uri event-data)})
        (try! (nft-mint? ticket ;; Mint the NFT representation of the ticket.
                         {event-id: event-id, ;; Use the event identifier as part of the NFT token identifier.
                          seat: seat} ;; Use the seat number as the second component of the NFT token identifier.
                         tx-sender)) ;; Assign ownership of the freshly minted NFT to the buyer.
        (print {event: "ticket-purchased", event-id: event-id, seat: seat, buyer: tx-sender, price: (get price event-data)})
        (ok {event-id: event-id, seat: seat, owner: tx-sender}))))) ;; Return the ticket metadata confirming the purchase.

;; function cancel-event: allows the event creator to mark an event as canceled and halt future ticket sales.
(define-public (cancel-event (event-id uint)) ;; Public function enabling the creator to cancel an event.
  (let ((event-data (unwrap! (map-get? events {event-id: event-id}) ERR-NO-SUCH-EVENT))) ;; Retrieve the event metadata or abort if the identifier is unknown.
    (begin ;; Sequence validations before updating status.
      (asserts! (is-eq tx-sender (get creator event-data)) ERR-NOT-CREATOR) ;; Ensure only the original creator can manage the event status.
      (asserts! (is-eq (get status event-data) STATUS-ACTIVE) ERR-STATUS-TRANSITION) ;; Permit cancelation only when the event is still active.
      (map-set events ;; Write the updated status while preserving other fields.
        {event-id: event-id} ;; Target the existing event record by identifier.
        {creator: (get creator event-data), ;; Preserve event creator.
         title: (get title event-data), ;; Preserve event title.
         date: (get date event-data), ;; Preserve event date.
         price: (get price event-data), ;; Preserve ticket price.
         total-seats: (get total-seats event-data), ;; Preserve capacity.
         sold-seats: (get sold-seats event-data), ;; Preserve sales count.
         status: STATUS-CANCELED, ;; Apply the canceled status code.
         metadata-uri: (get metadata-uri event-data)}) ;; Preserve the metadata pointer when updating status.
      (print {event: "event-canceled", event-id: event-id, creator: tx-sender})
      (ok STATUS-CANCELED)))) ;; Return the new status code to the caller.

;; function end-event: allows the event creator to mark an event as ended once it is complete.
(define-public (end-event (event-id uint)) ;; Public function enabling the creator to end an event.
  (let ((event-data (unwrap! (map-get? events {event-id: event-id}) ERR-NO-SUCH-EVENT))) ;; Retrieve the event metadata or abort if the identifier is unknown.
    (begin ;; Sequence validations before updating status.
      (asserts! (is-eq tx-sender (get creator event-data)) ERR-NOT-CREATOR) ;; Ensure only the original creator can mark the event as ended.
      (asserts! (is-eq (get status event-data) STATUS-ACTIVE) ERR-STATUS-TRANSITION) ;; Permit ending only when the event is active.
      (map-set events ;; Write the updated status while preserving other fields.
        {event-id: event-id} ;; Target the existing event record by identifier.
        {creator: (get creator event-data), ;; Preserve event creator.
         title: (get title event-data), ;; Preserve event title.
         date: (get date event-data), ;; Preserve event date.
         price: (get price event-data), ;; Preserve ticket price.
         total-seats: (get total-seats event-data), ;; Preserve capacity.
         sold-seats: (get sold-seats event-data), ;; Preserve sales count.
         status: STATUS-ENDED, ;; Apply the ended status code.
         metadata-uri: (get metadata-uri event-data)}) ;; Preserve the metadata pointer when ending an event.
      (print {event: "event-ended", event-id: event-id, creator: tx-sender})
      (ok STATUS-ENDED)))) ;; Return the new status code to the caller.

;; function set-contract-metadata: allows the contract deployer to advertise a metadata document for the entire collection.
(define-public (set-contract-metadata (uri (optional (string-ascii 256))))
  (begin
    (asserts! (is-eq tx-sender (contract-owner)) ERR-NOT-CREATOR) ;; Restrict updates to the contract deployer.
    (var-set contract-metadata-uri uri) ;; Persist the provided optional URI.
    (ok uri))) ;; Return the stored value for convenience.

;; function get-contract-uri: SIP-016 helper exposing the contract metadata pointer.
(define-read-only (get-contract-uri)
  (ok (var-get contract-metadata-uri)))

;; function get-token-uri: SIP-016 helper that surfaces the metadata URI for an individual ticket NFT.
(define-read-only (get-token-uri (token-id {event-id: uint, seat: uint}))
  (match (map-get? token-metadata token-id)
    token-record (ok (some (get uri token-record))) ;; Return the stored URI when available.
    (ok none))) ;; Unminted seats do not expose metadata yet.

;; function transfer-ticket: allows a ticket owner to transfer their ticket to another user.
(define-public (transfer-ticket (event-id uint) (seat uint) (recipient principal))
  (let (
    (event-data (unwrap! (map-get? events {event-id: event-id}) ERR-NO-SUCH-EVENT))
    (ticket-data (unwrap! (map-get? tickets {event-id: event-id, seat: seat}) ERR-NO-TICKET))
    (transfer-fee (/ (get price event-data) u20))) ;; 5% transfer fee to event creator
    (begin
      ;; Validate transfer is allowed
      (asserts! (is-eq tx-sender (get owner ticket-data)) ERR-NOT-TICKET-OWNER) ;; Only ticket owner can transfer
      (asserts! (not (is-eq tx-sender recipient)) ERR-TRANSFER-TO-SELF) ;; Cannot transfer to yourself
      (asserts! (not (is-eq (get status event-data) STATUS-ENDED)) ERR-EVENT-INACTIVE) ;; Cannot transfer after event ended
      
      ;; Charge transfer fee (5% of original ticket price to event creator)
      (if (> transfer-fee u0)
        (try! (stx-transfer? transfer-fee tx-sender (get creator event-data)))
        true)
      
      ;; Update ticket ownership
      (map-set tickets
        {event-id: event-id, seat: seat}
        {owner: recipient, refunded: (get refunded ticket-data)})
      
      ;; Transfer the NFT
      (try! (nft-transfer? ticket
                          {event-id: event-id, seat: seat}
                          tx-sender
                          recipient))
      
      (print {event: "ticket-transferred", event-id: event-id, seat: seat, from: tx-sender, to: recipient, fee: transfer-fee})
      (ok {event-id: event-id, seat: seat, from: tx-sender, to: recipient, fee: transfer-fee}))))

;; function claim-refund: allows ticket holders to claim a refund for canceled events (creator pays).
(define-public (claim-refund (event-id uint) (seat uint))
  (let (
    (event-data (unwrap! (map-get? events {event-id: event-id}) ERR-NO-SUCH-EVENT))
    (ticket-data (unwrap! (map-get? tickets {event-id: event-id, seat: seat}) ERR-NO-TICKET)))
    (begin
      ;; Validate refund is allowed
      (asserts! (is-eq tx-sender (get owner ticket-data)) ERR-NOT-TICKET-OWNER) ;; Only ticket owner can claim refund
      (asserts! (is-eq (get status event-data) STATUS-CANCELED) ERR-EVENT-NOT-CANCELED) ;; Event must be canceled
      (asserts! (not (get refunded ticket-data)) ERR-ALREADY-REFUNDED) ;; Cannot refund twice
      
      ;; Mark ticket as refunded first
      (map-set tickets
        {event-id: event-id, seat: seat}
        {owner: tx-sender, refunded: true})
      
      ;; Burn the NFT since it's been refunded
      (try! (nft-burn? ticket {event-id: event-id, seat: seat} tx-sender))
      
      (print {event: "refund-claimed", event-id: event-id, seat: seat, owner: tx-sender, amount: (get price event-data)})
      (ok {event-id: event-id, seat: seat, refund-amount: (get price event-data)}))))

;; function process-refund: allows event creator to process refund by sending STX to ticket holder.
(define-public (process-refund (event-id uint) (seat uint))
  (let (
    (event-data (unwrap! (map-get? events {event-id: event-id}) ERR-NO-SUCH-EVENT))
    (ticket-data (unwrap! (map-get? tickets {event-id: event-id, seat: seat}) ERR-NO-TICKET)))
    (begin
      ;; Validate refund processing is allowed
      (asserts! (is-eq tx-sender (get creator event-data)) ERR-NOT-CREATOR) ;; Only creator can process refund
      (asserts! (is-eq (get status event-data) STATUS-CANCELED) ERR-EVENT-NOT-CANCELED) ;; Event must be canceled
      (asserts! (get refunded ticket-data) ERR-NO-TICKET) ;; Ticket must be marked as refunded
      
      ;; Transfer refund amount from creator to ticket holder
      (try! (stx-transfer? (get price event-data) tx-sender (get owner ticket-data)))
      
      (print {event: "refund-processed", event-id: event-id, seat: seat, refunded-to: (get owner ticket-data), amount: (get price event-data)})
      (ok {event-id: event-id, seat: seat, refunded-to: (get owner ticket-data), amount: (get price event-data)}))))

;; ========== BATCH PAYMENT SYSTEM ==========

;; Private helper for processing a single payment in batch
(define-private (process-single-payment 
  (payment-info {recipient: principal, amount: uint}) 
  (context {sender: principal, success-count: uint, failed-count: uint, total-sent: uint}))
  (let (
    (sender (get sender context))
    (recipient (get recipient payment-info))
    (amount (get amount payment-info)))
    ;; Attempt to transfer STX to recipient
    (match (stx-transfer? amount sender recipient)
      success
        ;; Payment succeeded, update context
        {sender: sender,
         success-count: (+ (get success-count context) u1),
         failed-count: (get failed-count context),
         total-sent: (+ (get total-sent context) amount)}
      error
        ;; Payment failed, increment failed count
        {sender: sender,
         success-count: (get success-count context),
         failed-count: (+ (get failed-count context) u1),
         total-sent: (get total-sent context)})))

;; Helper function to combine recipients and amounts into payment info tuples
(define-private (build-payment-info (recipient principal) (amount uint))
  {recipient: recipient, amount: amount})

;; function batch-pay: sends STX to multiple wallet addresses with specified amounts in one transaction.
;; This allows event creators to pay multiple people (workers, contractors, etc.) at once.
;; Max 50 recipients per batch to avoid hitting gas limits.
(define-public (batch-pay 
  (event-id uint)
  (recipients (list 50 principal)) 
  (amounts (list 50 uint)))
  (let (
    (event-data (unwrap! (map-get? events {event-id: event-id}) ERR-NO-SUCH-EVENT))
    (recipients-len (len recipients))
    (amounts-len (len amounts)))
    (begin
      ;; Validate caller is event creator
      (asserts! (is-eq tx-sender (get creator event-data)) ERR-NOT-CREATOR)
      
      ;; Validate lists have same length
      (asserts! (is-eq recipients-len amounts-len) ERR-PAYMENT-LISTS-MISMATCH)
      
      ;; Validate lists are not empty
      (asserts! (> recipients-len u0) ERR-EMPTY-PAYMENT-LIST)
      
      ;; Build payment info list by combining recipients and amounts
      (let (
        (payment-list (map build-payment-info recipients amounts))
        (initial-context {sender: tx-sender, success-count: u0, failed-count: u0, total-sent: u0})
        (final-context (fold process-single-payment payment-list initial-context)))
        
        ;; Emit batch payment event
        (print {
          event: "batch-payment",
          event-id: event-id,
          total-recipients: recipients-len,
          successful-payments: (get success-count final-context),
          failed-payments: (get failed-count final-context),
          total-amount-sent: (get total-sent final-context)})
        
        ;; Return summary of batch payment
        (ok {
          event-id: event-id,
          total-recipients: recipients-len,
          successful-payments: (get success-count final-context),
          failed-payments: (get failed-count final-context),
          total-amount-sent: (get total-sent final-context)})))))

