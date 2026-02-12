;; sBTCForge-Quest Gaming Platform Smart Contract
;; Handles in-game asset ownership and trading functionality


;; Constants
(define-constant platform-admin tx-sender)
(define-constant err-admin-only (err u100))
(define-constant err-resource-not-found (err u101))
(define-constant err-permission-denied (err u102))
(define-constant err-invalid-parameters (err u103))
(define-constant err-pricing-error (err u104))
(define-constant max-character-level u100)
(define-constant max-character-experience u10000)
(define-constant max-item-metadata-length u256)
(define-constant max-batch-operation-size u10)


;;;;;;; Data Variables ;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-data-var total-item-count uint u0)



;;;;; Read-only Functions;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Get item details
(define-read-only (get-item-details (item-id uint))
    (if (<= item-id (var-get total-item-count))
        (map-get? game-items { item-id: item-id })
        none))

;; Get marketplace listing details
(define-read-only (get-marketplace-listing (item-id uint))
    (map-get? marketplace-item-listings { item-id: item-id }))

;; Get character progression
(define-read-only (get-character-progression (character principal))
    (map-get? character-progression { character: character }))

;; Get total items created
(define-read-only (get-total-items)
    (var-get total-item-count))



;; Map definitions
(define-map game-items 
    { item-id: uint }
    { owner: principal, item-uri: (string-utf8 256), can-trade: bool })


(define-map item-market-values
    { item-id: uint }
    { price: uint })


(define-map character-progression
    { character: principal }
    { experience: uint, level: uint })


(define-map marketplace-item-listings
    { item-id: uint }
    { seller: principal, price: uint, listing-timestamp: uint })


;;;;;; Private Functions ;;;;;;

;; Validate game item exists and return item data
(define-private (validate-and-fetch-item (item-id uint))
    (let ((item (map-get? game-items { item-id: item-id })))
        (asserts! (and 
                (is-some item)
                (<= item-id (var-get total-item-count)))
            err-resource-not-found)
        (ok (unwrap-panic item))))


;; Validate item metadata URI length
(define-private (is-valid-item-uri (uri (string-utf8 256)))
    (let ((uri-length (len uri)))
        (and 
            (> uri-length u0)
            (<= uri-length max-item-metadata-length))))

;; Helper function for batch item creation
(define-private (create-single-item 
    (uri (string-utf8 256))
    (can-trade bool))
    (let 
        ((item-id (+ (var-get total-item-count) u1)))
        (asserts! (is-valid-item-uri uri) err-invalid-parameters)
        (map-set game-items
            { item-id: item-id }
            { owner: platform-admin,
              item-uri: uri,
              can-trade: can-trade })
        (var-set total-item-count item-id)
        (ok item-id)))



;;;;; Public Functions ;;;;;;;

;; Batch Create new game items
(define-public (batch-create-items 
    (item-uris (list 10 (string-utf8 256))) 
    (tradable-flags (list 10 bool)))
    (begin
        (asserts! (is-eq tx-sender platform-admin) err-admin-only)
        (asserts! (and 
            (> (len item-uris) u0)
            (<= (len item-uris) max-batch-operation-size)
            (is-eq (len item-uris) (len tradable-flags))) 
            err-invalid-parameters)
        (let ((created-items 
            (map create-single-item 
                item-uris 
                tradable-flags)))
            (ok created-items))))


;; Batch Transfer game items
(define-public (batch-transfer-items 
    (item-ids (list 10 uint)) 
    (recipients (list 10 principal)))
    (begin
        (asserts! (and 
            (> (len item-ids) u0)
            (<= (len item-ids) max-batch-operation-size)
            (is-eq (len item-ids) (len recipients))) 
            err-invalid-parameters)
        (let ((transfers 
            (map transfer-single-item 
                item-ids 
                recipients)))
            (ok transfers))))

;; Helper function for batch item transfer
(define-private (transfer-single-item 
    (item-id uint)
    (recipient principal))
    (let 
        ((item (unwrap-panic (validate-and-fetch-item item-id))))
        (asserts! (and
                (is-eq (get owner item) tx-sender)
                (get can-trade item)
                (not (is-eq recipient tx-sender)))
            err-permission-denied)
        (map-set game-items
            { item-id: item-id }
            { owner: recipient,
              item-uri: (get item-uri item),
              can-trade: (get can-trade item) })
        (ok true)))

;; Create single game item
(define-public (create-item (item-uri (string-utf8 256)) (can-trade bool))
    (let
        ((item-id (+ (var-get total-item-count) u1)))
        (asserts! (is-eq tx-sender platform-admin) err-admin-only)
        (asserts! (is-valid-item-uri item-uri) err-invalid-parameters)
        (map-set game-items
            { item-id: item-id }
            { owner: tx-sender,
              item-uri: item-uri,
              can-trade: can-trade })
        (var-set total-item-count item-id)
        (ok item-id)))

;; Transfer item ownership
(define-public (transfer-item (item-id uint) (recipient principal))
    (begin
        (asserts! (<= item-id (var-get total-item-count)) err-invalid-parameters)
        (let ((item (try! (validate-and-fetch-item item-id))))
            (asserts! (and
                    (is-eq (get owner item) tx-sender)
                    (get can-trade item)
                    (not (is-eq recipient tx-sender)))
                err-permission-denied)
            (map-set game-items
                { item-id: item-id }
                { owner: recipient,
                  item-uri: (get item-uri item),
                  can-trade: (get can-trade item) })
            (ok true))))
