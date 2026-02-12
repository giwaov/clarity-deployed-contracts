---
title: "Trait STX-VaxiGuard"
draft: true
---
```
;; Vaccine Tracking Smart Contract
;; Contract Owner Management
(define-data-var vaccine-contract-owner principal tx-sender)

;; Error Codes
(define-constant ERROR-NOT-AUTHORIZED (err u100))
(define-constant ERROR-INVALID-BATCH (err u101))
(define-constant ERROR-BATCH-EXISTS (err u102))
(define-constant ERROR-BATCH-NOT-FOUND (err u103))
(define-constant ERROR-INSUFFICIENT-VACCINE-QUANTITY (err u104))
(define-constant ERROR-INVALID-PATIENT-ID (err u105))
(define-constant ERROR-PATIENT-ALREADY-VACCINATED (err u106))
(define-constant ERROR-TEMPERATURE-OUT-OF-RANGE (err u107))
(define-constant ERROR-VACCINE-BATCH-EXPIRED (err u108))
(define-constant ERROR-INVALID-VACCINATION-LOCATION (err u109))
(define-constant ERROR-MAXIMUM-DOSES-REACHED (err u110))
(define-constant ERROR-MINIMUM-DOSE-INTERVAL-NOT-MET (err u111))
(define-constant ERROR-CONTRACT-OWNER-ONLY (err u112))
(define-constant ERROR-INVALID-INPUT (err u113))
(define-constant ERROR-INVALID-EXPIRY-DATE (err u114))
(define-constant ERROR-INVALID-STORAGE-CAPACITY (err u115))

;; Constants
(define-constant MINIMUM-STORAGE-TEMPERATURE (- 70))
(define-constant MAXIMUM_STORAGE_TEMPERATURE 8)
(define-constant MINIMUM-DAYS-BETWEEN-DOSES u21) ;; 21 days minimum between doses
(define-constant MAXIMUM-DOSES-PER-PATIENT u4)
(define-constant MINIMUM_STRING_LENGTH u1)
(define-constant CURRENT_BLOCK stacks-block-time)

;; Data Maps
(define-map vaccine-batches
    { vaccine-batch-id: (string-ascii 32) }
    {
        vaccine-manufacturer: (string-ascii 50),
        vaccine-name: (string-ascii 50),
        manufacturing-date: uint,
        batch-expiry-date: uint,
        available-doses: uint,
        storage-temperature: int,
        batch-status: (string-ascii 20),
        temperature-breach-count: uint,
        storage-facility: (string-ascii 100),
        additional-batch-notes: (string-ascii 500)
    }
)

(define-map patient-vaccination-records
    { patient-identifier: (string-ascii 32) }
    {
        vaccination-history: (list 10 {
            vaccine-batch-id: (string-ascii 32),
            administration-date: uint,
            vaccine-type: (string-ascii 50),
            dose-sequence-number: uint,
            healthcare-provider: principal,
            vaccination-site: (string-ascii 100),
            next-vaccination-date: (optional uint)
        }),
        completed-doses: uint,
        reported-side-effects: (list 5 (string-ascii 200)),
        vaccination-exemption-reason: (optional (string-ascii 200))
    }
)

(define-map healthcare-providers 
    principal 
    {
        provider-role: (string-ascii 20),
        healthcare-facility: (string-ascii 100),
        credentials-expiry-date: uint
    }
)

(define-map vaccine-storage-facilities
    (string-ascii 100)
    {
        facility-address: (string-ascii 200),
        maximum-storage-capacity: uint,
        current-inventory: uint,
        facility-temperature-history: (list 100 {
            reading-timestamp: uint,
            recorded-temperature: int
        })
    }
)

;; Private Functions
(define-private (is-vaccine-contract-owner)
    (is-eq tx-sender (var-get vaccine-contract-owner))
)

;; Updated validate-string functions for different string lengths
(define-private (validate-string-32 (input (string-ascii 32)))
    (> (len input) MINIMUM_STRING_LENGTH)
)

(define-private (validate-string-50 (input (string-ascii 50)))
    (> (len input) MINIMUM_STRING_LENGTH)
)

(define-private (validate-string-100 (input (string-ascii 100)))
    (> (len input) MINIMUM_STRING_LENGTH)
)

(define-private (validate-string-200 (input (string-ascii 200)))
    (> (len input) MINIMUM_STRING_LENGTH)
)

(define-private (validate-future-date (date uint))
    (> date CURRENT_BLOCK)
)

(define-private (validate-storage-capacity (capacity uint))
    (> capacity u0)
)

;; Read-only Functions
(define-read-only (get-vaccine-contract-owner)
    (ok (var-get vaccine-contract-owner))
)

(define-read-only (is-provider-authorized (provider-address principal))
    (match (map-get? healthcare-providers provider-address)
        provider-info (>= (get credentials-expiry-date provider-info) CURRENT_BLOCK)
        false
    )
)

;; Public Functions
(define-public (transfer-contract-ownership (new-contract-owner principal))
    (begin
        (asserts! (is-vaccine-contract-owner) ERROR-CONTRACT-OWNER-ONLY)
        (ok (var-set vaccine-contract-owner new-contract-owner))
    )
)

(define-public (register-storage-facility
    (facility-id (string-ascii 100))
    (facility-address (string-ascii 200))
    (maximum-storage-capacity uint))
    (begin
        (asserts! (is-vaccine-contract-owner) ERROR-NOT-AUTHORIZED)
        (asserts! (validate-string-100 facility-id) ERROR-INVALID-INPUT)
        (asserts! (validate-string-200 facility-address) ERROR-INVALID-INPUT)
        (asserts! (validate-storage-capacity maximum-storage-capacity) ERROR-INVALID-STORAGE-CAPACITY)
        (ok (map-set vaccine-storage-facilities
            facility-id
            {
                facility-address: facility-address,
                maximum-storage-capacity: maximum-storage-capacity,
                current-inventory: u0,
                facility-temperature-history: (list)
            }))
    )
)

(define-public (register-vaccine-batch 
    (vaccine-batch-id (string-ascii 32))
    (vaccine-manufacturer (string-ascii 50))
    (vaccine-name (string-ascii 50))
    (manufacturing-date uint)
    (batch-expiry-date uint)
    (initial-quantity uint)
    (storage-temperature int)
    (storage-facility (string-ascii 100)))
    (begin
        (asserts! (is-provider-authorized tx-sender) ERROR-NOT-AUTHORIZED)
        (asserts! (validate-string-32 vaccine-batch-id) ERROR-INVALID-INPUT)
        (asserts! (validate-string-50 vaccine-manufacturer) ERROR-INVALID-INPUT)
        (asserts! (validate-string-50 vaccine-name) ERROR-INVALID-INPUT)
        (asserts! (validate-string-100 storage-facility) ERROR-INVALID-INPUT)
        (asserts! (is-none (map-get? vaccine-batches {vaccine-batch-id: vaccine-batch-id})) ERROR-BATCH-EXISTS)
        (asserts! (validate-storage-capacity initial-quantity) ERROR-INVALID-BATCH)
        (asserts! (validate-future-date batch-expiry-date) ERROR-INVALID-EXPIRY-DATE)
        (asserts! (> batch-expiry-date manufacturing-date) ERROR-INVALID-BATCH)
        (asserts! (and (>= storage-temperature MINIMUM-STORAGE-TEMPERATURE) 
                      (<= storage-temperature MAXIMUM_STORAGE_TEMPERATURE)) 
                 ERROR-TEMPERATURE-OUT-OF-RANGE)

        (ok (map-set vaccine-batches 
            {vaccine-batch-id: vaccine-batch-id}
            {
                vaccine-manufacturer: vaccine-manufacturer,
                vaccine-name: vaccine-name,
                manufacturing-date: manufacturing-date,
                batch-expiry-date: batch-expiry-date,
                available-doses: initial-quantity,
                storage-temperature: storage-temperature,
                batch-status: "active",
                temperature-breach-count: u0,
                storage-facility: storage-facility,
                additional-batch-notes: ""
            }))
    )
)


(define-public (record-temperature-breach
    (vaccine-batch-id (string-ascii 32))
    (breach-temperature int))
    (begin
        (asserts! (is-provider-authorized tx-sender) ERROR-NOT-AUTHORIZED)
        (asserts! (validate-string-32 vaccine-batch-id) ERROR-INVALID-INPUT)
        (match (map-get? vaccine-batches {vaccine-batch-id: vaccine-batch-id})
            batch-info (ok (map-set vaccine-batches 
                {vaccine-batch-id: vaccine-batch-id}
                (merge batch-info {
                    temperature-breach-count: (+ (get temperature-breach-count batch-info) u1),
                    batch-status: (if (> (get temperature-breach-count batch-info) u2) 
                                    "compromised" 
                                    (get batch-status batch-info))
                })))
            ERROR-BATCH-NOT-FOUND
        )
    )
)




;; (define-public (update-batch-status
;;     (vaccine-batch-id (string-ascii 32))
;;     (new-batch-status (string-ascii 20)))
;;     (begin
;;         (asserts! (is-provider-authorized tx-sender) ERROR-NOT-AUTHORIZED)
;;         (asserts! (validate-string-32 vaccine-batch-id) ERROR-INVALID-INPUT)
;;         (asserts! (validate-string-20 new-batch-status) ERROR-INVALID-INPUT)
;;         (match (map-get? vaccine-batches {vaccine-batch-id: vaccine-batch-id})
;;             batch-info (ok (map-set vaccine-batches 
;;                 {vaccine-batch-id: vaccine-batch-id}
;;                 (merge batch-info {batch-status: new-batch-status})))
;;             ERROR-BATCH-NOT-FOUND
;;         )
;;     )
;; )



;; (define-public (register-healthcare-provider 
;;     (provider-address principal)
;;     (provider-role (string-ascii 20))
;;     (healthcare-facility (string-ascii 100))
;;     (credentials-expiry-date uint))
;;     (begin
;;         (asserts! (is-vaccine-contract-owner) ERROR-NOT-AUTHORIZED)
;;         (asserts! (validate-string-20 provider-role) ERROR-INVALID-INPUT)
;;         (asserts! (validate-string-100 healthcare-facility) ERROR-INVALID-INPUT)
;;         (asserts! (validate-future-date credentials-expiry-date) ERROR-INVALID-EXPIRY-DATE)
;;         (ok (map-set healthcare-providers 
;;             provider-address 
;;             {
;;                 provider-role: provider-role,
;;                 healthcare-facility: healthcare-facility,
;;                 credentials-expiry-date: credentials-expiry-date
;;             }))
;;     )
;; )



;; (define-public (record-vaccination
;;     (patient-identifier (string-ascii 32))
;;     (vaccine-batch-id (string-ascii 32))
;;     (vaccination-site (string-ascii 100)))
;;     (begin
;;         (asserts! (is-provider-authorized tx-sender) ERROR-NOT-AUTHORIZED)
;;         (asserts! (validate-string-32 patient-identifier) ERROR-INVALID-PATIENT-ID)
;;         (asserts! (validate-string-32 vaccine-batch-id) ERROR-INVALID-INPUT)
;;         (asserts! (validate-string-100 vaccination-site) ERROR-INVALID-VACCINATION-LOCATION)

;;         (match (map-get? vaccine-batches {vaccine-batch-id: vaccine-batch-id})
;;             batch-info (begin
;;                 (asserts! (> (get available-doses batch-info) u0) ERROR-INSUFFICIENT-VACCINE-QUANTITY)
;;                 (asserts! (is-eq (get batch-status batch-info) "active") ERROR-INVALID-BATCH)
;;                 (asserts! (<= CURRENT_BLOCK (get batch-expiry-date batch-info)) ERROR-VACCINE-BATCH-EXPIRED)

;;                 (match (map-get? patient-vaccination-records {patient-identifier: patient-identifier})
;;                     vaccination-record (begin
;;                         (asserts! (< (get completed-doses vaccination-record) MAXIMUM-DOSES-PER-PATIENT) 
;;                                 ERROR-MAXIMUM-DOSES-REACHED)
;;                         (let ((current-dose-number (+ (get completed-doses vaccination-record) u1)))
;;                             (if (> current-dose-number u1)
;;                                 (asserts! (>= (- CURRENT_BLOCK 
;;                                     (get administration-date (unwrap-panic (element-at 
;;                                         (get vaccination-history vaccination-record) 
;;                                         (- current-dose-number u2))))) 
;;                                     MINIMUM-DAYS-BETWEEN-DOSES)
;;                                     ERROR-MINIMUM-DOSE-INTERVAL-NOT-MET)
;;                                 true
;;                             )

;;                             (ok (map-set patient-vaccination-records
;;                                 {patient-identifier: patient-identifier}
;;                                 {
;;                                     vaccination-history: (unwrap-panic (as-max-len? 
;;                                         (append (get vaccination-history vaccination-record)
;;                                             {
;;                                                 vaccine-batch-id: vaccine-batch-id,
;;                                                 administration-date: CURRENT_BLOCK,
;;                                                 vaccine-type: (get vaccine-name batch-info),
;;                                                 dose-sequence-number: current-dose-number,
;;                                                 healthcare-provider: tx-sender,
;;                                                 vaccination-site: vaccination-site,
;;                                                 next-vaccination-date: (some (+ CURRENT_BLOCK MINIMUM-DAYS-BETWEEN-DOSES))
;;                                             }
;;                                         ) u10)),
;;                                     completed-doses: current-dose-number,
;;                                     reported-side-effects: (get reported-side-effects vaccination-record),
;;                                     vaccination-exemption-reason: (get vaccination-exemption-reason vaccination-record)
;;                                 }))))
;;                     ;; First dose for patient
;;                     (ok (map-set patient-vaccination-records
;;                         {patient-identifier: patient-identifier}
;;                         {
;;                             vaccination-history: (list 
;;                                 {
;;                                     vaccine-batch-id: vaccine-batch-id,
;;                                     administration-date: CURRENT_BLOCK,
;;                                     vaccine-type: (get vaccine-name batch-info),
;;                                     dose-sequence-number: u1,
;;                                     healthcare-provider: tx-sender,
;;                                     vaccination-site: vaccination-site,
;;                                     next-vaccination-date: (some (+ CURRENT_BLOCK MINIMUM-DAYS-BETWEEN-DOSES))
;;                                 }),
;;                             completed-doses: u1,
;;                             reported-side-effects: (list),
;;                             vaccination-exemption-reason: none
;;                         })))
;;             )
;;             ERROR-BATCH-NOT-FOUND
;;         )
;;     )
;; )

;; ;; Read-only Functions
;; (define-read-only (get-vaccine-batch-info (vaccine-batch-id (string-ascii 32)))
;;     (map-get? vaccine-batches {vaccine-batch-id: vaccine-batch-id})
;; )

;; (define-read-only (get-patient-vaccination-record (patient-identifier (string-ascii 32)))
;;     (map-get? patient-vaccination-records {patient-identifier: patient-identifier})
;; )

;; (define-read-only (get-storage-facility-info (facility-id (string-ascii 100)))
;;     (map-get? vaccine-storage-facilities facility-id)
;; )

;; (define-read-only (is-vaccine-batch-valid (vaccine-batch-id (string-ascii 32)))
;;     (match (map-get? vaccine-batches {vaccine-batch-id: vaccine-batch-id})
;;         batch-info (and
;;             (is-eq (get batch-status batch-info) "active")
;;             (> (get available-doses batch-info) u0)
;;             (<= CURRENT_BLOCK (get batch-expiry-date batch-info))
;;             (<= (get temperature-breach-count batch-info) u2))
;;         false
;;     )
;; )

;; ;; Add validate-string-20 function that was referenced but missing
;; (define-private (validate-string-20 (input (string-ascii 20)))
;;     (> (len input) MINIMUM_STRING_LENGTH)
;; )
```
