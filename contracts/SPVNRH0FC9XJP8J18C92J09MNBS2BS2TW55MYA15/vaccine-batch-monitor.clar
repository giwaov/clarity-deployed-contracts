;; title: vaccine-batch-monitor
;; version:
;; summary:
;; description:
;; Vaccine Tracking Smart Contract

;; Contract Owner Management
(define-data-var immunization-system-controller principal tx-sender)

;; Error Codes
(define-constant AUTHORIZATION-ERROR (err u100))
(define-constant INVALID-VACCINE-SHIPMENT (err u101))
(define-constant DUPLICATE-SHIPMENT-ERROR (err u102))
(define-constant SHIPMENT-NOT-FOUND-ERROR (err u103))
(define-constant VACCINE-SUPPLY-DEPLETED (err u104))
(define-constant INVALID-RECIPIENT-ID (err u105))
(define-constant DUPLICATE-IMMUNIZATION (err u106))
(define-constant COLD-CHAIN-BREACH (err u107))
(define-constant EXPIRED-VACCINE-ERROR (err u108))
(define-constant INVALID-CLINIC-LOCATION (err u109))
(define-constant IMMUNIZATION-LIMIT-REACHED (err u110))
(define-constant MINIMUM-INTERVAL-VIOLATION (err u111))
(define-constant ADMIN-PRIVILEGES-REQUIRED (err u112))
(define-constant DATA-VALIDATION-ERROR (err u113))
(define-constant EXPIRY-DATE-ERROR (err u114))
(define-constant STORAGE-CAPACITY-ERROR (err u115))
(define-constant CLINICIAN-ALREADY-REGISTERED (err u116))

;; Constants
(define-constant COLD-CHAIN-MINIMUM-TEMP (- 70))
(define-constant COLD-CHAIN-MAXIMUM-TEMP 8)
(define-constant DOSE-INTERVAL-REQUIREMENT u21) ;; 21 days minimum between doses
(define-constant MAXIMUM-IMMUNIZATION-SERIES u4)
(define-constant MINIMUM-ENTRY-LENGTH u1)
(define-constant CURRENT-CHAIN-HEIGHT stacks-block-height)

;; Data Maps
(define-map vaccine-shipment-registry
    { shipment-id: (string-ascii 32) }
    {
        manufacturer-details: (string-ascii 50),
        vaccine-brand-name: (string-ascii 50),
        production-timestamp: uint,
        expiration-timestamp: uint,
        available-unit-count: uint,
        storage-temp-celsius: int,
        shipment-status: (string-ascii 20),
        temp-violation-incidents: uint,
        storage-facility-id: (string-ascii 100),
        shipment-notes: (string-ascii 500)
    }
)

(define-map immunization-registry
    { recipient-id: (string-ascii 32) }
    {
        immunization-sequence: (list 10 {
            shipment-reference: (string-ascii 32),
            administration-timestamp: uint,
            vaccine-formulation: (string-ascii 50),
            sequence-number: uint,
            administering-clinician: principal,
            clinic-location: (string-ascii 100),
            next-dose-due-date: (optional uint)
        }),
        completed-immunizations: uint,
        adverse-event-reports: (list 5 (string-ascii 200)),
        medical-exemption: (optional (string-ascii 200))
    }
)

(define-map authorized-clinicians 
    principal 
    {
        clinical-role: (string-ascii 20),
        clinic-name: (string-ascii 100),
        credentials-valid-until: uint
    }
)

(define-map cold-chain-facilities
    (string-ascii 100)
    {
        facility-location: (string-ascii 200),
        max-storage-units: uint,
        current-unit-count: uint,
        temperature-monitoring: (list 100 {
            monitoring-timestamp: uint,
            recorded-temp-celsius: int
        })
    }
)

;; Private Functions
(define-private (is-system-controller)
    (is-eq tx-sender (var-get immunization-system-controller))
)

;; String validation functions
(define-private (validate-identifier (input (string-ascii 32)))
    (> (len input) MINIMUM-ENTRY-LENGTH)
)

(define-private (validate-name-field (input (string-ascii 50)))
    (> (len input) MINIMUM-ENTRY-LENGTH)
)

(define-private (validate-location-field (input (string-ascii 100)))
    (> (len input) MINIMUM-ENTRY-LENGTH)
)

(define-private (validate-description-field (input (string-ascii 200)))
    (> (len input) MINIMUM-ENTRY-LENGTH)
)

(define-private (validate-future-date (input-date uint))
    (> input-date CURRENT-CHAIN-HEIGHT)
)

(define-private (validate-storage-limit (proposed-limit uint))
    (> proposed-limit u0)
)

;; Read-only Functions
(define-read-only (get-system-controller)
    (ok (var-get immunization-system-controller))
)

(define-read-only (verify-clinician-status (clinician-address principal))
    (match (map-get? authorized-clinicians clinician-address)
        clinician-data (>= (get credentials-valid-until clinician-data) CURRENT-CHAIN-HEIGHT)
        false
    )
)

;; Public Functions
(define-public (transfer-system-control (new-controller principal))
    (begin
        (asserts! (is-system-controller) ADMIN-PRIVILEGES-REQUIRED)
        (asserts! (is-some (map-get? authorized-clinicians new-controller)) AUTHORIZATION-ERROR)
        (ok (var-set immunization-system-controller new-controller))
    )
)

(define-public (register-clinician 
    (clinician-address principal)
    (role (string-ascii 20))
    (facility-name (string-ascii 100))
    (credential-expiry uint))
    (begin
        (asserts! (is-system-controller) AUTHORIZATION-ERROR)
        (asserts! (is-none (map-get? authorized-clinicians clinician-address)) CLINICIAN-ALREADY-REGISTERED)
        (asserts! (validate-identifier role) DATA-VALIDATION-ERROR)
        (asserts! (validate-location-field facility-name) DATA-VALIDATION-ERROR)
        (asserts! (validate-future-date credential-expiry) EXPIRY-DATE-ERROR)
        (ok (map-set authorized-clinicians 
            clinician-address 
            {
                clinical-role: role,
                clinic-name: facility-name,
                credentials-valid-until: credential-expiry
            }))
    )
)

(define-public (register-storage-facility
    (facility-id (string-ascii 100))
    (location-address (string-ascii 200))
    (storage-capacity uint))
    (begin
        (asserts! (is-system-controller) AUTHORIZATION-ERROR)
        (asserts! (validate-location-field facility-id) DATA-VALIDATION-ERROR)
        (asserts! (validate-description-field location-address) DATA-VALIDATION-ERROR)
        (asserts! (validate-storage-limit storage-capacity) STORAGE-CAPACITY-ERROR)
        (ok (map-set cold-chain-facilities
            facility-id
            {
                facility-location: location-address,
                max-storage-units: storage-capacity,
                current-unit-count: u0,
                temperature-monitoring: (list)
            }))
    )
)

(define-public (register-vaccine-shipment 
    (shipment-id (string-ascii 32))
    (manufacturer (string-ascii 50))
    (brand-name (string-ascii 50))
    (production-date uint)
    (expiry-date uint)
    (dose-quantity uint)
    (storage-temp int)
    (facility-id (string-ascii 100)))
    (begin
        (asserts! (verify-clinician-status tx-sender) AUTHORIZATION-ERROR)
        (asserts! (validate-identifier shipment-id) DATA-VALIDATION-ERROR)
        (asserts! (validate-name-field manufacturer) DATA-VALIDATION-ERROR)
        (asserts! (validate-name-field brand-name) DATA-VALIDATION-ERROR)
        (asserts! (validate-location-field facility-id) DATA-VALIDATION-ERROR)
        (asserts! (is-none (map-get? vaccine-shipment-registry {shipment-id: shipment-id})) DUPLICATE-SHIPMENT-ERROR)
        (asserts! (validate-storage-limit dose-quantity) INVALID-VACCINE-SHIPMENT)
        (asserts! (validate-future-date expiry-date) EXPIRY-DATE-ERROR)
        (asserts! (> expiry-date production-date) INVALID-VACCINE-SHIPMENT)
        (asserts! (and (>= storage-temp COLD-CHAIN-MINIMUM-TEMP) 
                      (<= storage-temp COLD-CHAIN-MAXIMUM-TEMP)) 
                 COLD-CHAIN-BREACH)
        
        (ok (map-set vaccine-shipment-registry 
            {shipment-id: shipment-id}
            {
                manufacturer-details: manufacturer,
                vaccine-brand-name: brand-name,
                production-timestamp: production-date,
                expiration-timestamp: expiry-date,
                available-unit-count: dose-quantity,
                storage-temp-celsius: storage-temp,
                shipment-status: "active",
                temp-violation-incidents: u0,
                storage-facility-id: facility-id,
                shipment-notes: ""
            }))
    )
)

(define-public (update-shipment-status
    (shipment-id (string-ascii 32))
    (new-status (string-ascii 20)))
    (begin
        (asserts! (verify-clinician-status tx-sender) AUTHORIZATION-ERROR)
        (asserts! (validate-identifier shipment-id) DATA-VALIDATION-ERROR)
        (asserts! (validate-identifier new-status) DATA-VALIDATION-ERROR)
        (match (map-get? vaccine-shipment-registry {shipment-id: shipment-id})
            shipment-data (ok (map-set vaccine-shipment-registry 
                {shipment-id: shipment-id}
                (merge shipment-data {shipment-status: new-status})))
            SHIPMENT-NOT-FOUND-ERROR
        )
    )
)

(define-public (record-temperature-violation
    (shipment-id (string-ascii 32))
    (violation-temp int))
    (begin
        (asserts! (verify-clinician-status tx-sender) AUTHORIZATION-ERROR)
        (asserts! (validate-identifier shipment-id) DATA-VALIDATION-ERROR)
        (match (map-get? vaccine-shipment-registry {shipment-id: shipment-id})
            shipment-data (ok (map-set vaccine-shipment-registry 
                {shipment-id: shipment-id}
                (merge shipment-data {
                    temp-violation-incidents: (+ (get temp-violation-incidents shipment-data) u1),
                    shipment-status: (if (> (get temp-violation-incidents shipment-data) u2) 
                                    "compromised" 
                                    (get shipment-status shipment-data))
                })))
            SHIPMENT-NOT-FOUND-ERROR
        )
    )
)

(define-public (record-immunization
    (recipient-id (string-ascii 32))
    (shipment-id (string-ascii 32))
    (clinic-location (string-ascii 100)))
    (begin
        (asserts! (verify-clinician-status tx-sender) AUTHORIZATION-ERROR)
        (asserts! (validate-identifier recipient-id) INVALID-RECIPIENT-ID)
        (asserts! (validate-identifier shipment-id) DATA-VALIDATION-ERROR)
        (asserts! (validate-location-field clinic-location) INVALID-CLINIC-LOCATION)
        
        (match (map-get? vaccine-shipment-registry {shipment-id: shipment-id})
            shipment-data (begin
                (asserts! (> (get available-unit-count shipment-data) u0) VACCINE-SUPPLY-DEPLETED)
                (asserts! (is-eq (get shipment-status shipment-data) "active") INVALID-VACCINE-SHIPMENT)
                (asserts! (<= CURRENT-CHAIN-HEIGHT (get expiration-timestamp shipment-data)) EXPIRED-VACCINE-ERROR)
                
                (match (map-get? immunization-registry {recipient-id: recipient-id})
                    recipient-record (begin
                        (asserts! (< (get completed-immunizations recipient-record) MAXIMUM-IMMUNIZATION-SERIES) 
                                IMMUNIZATION-LIMIT-REACHED)
                        (let ((current-dose (+ (get completed-immunizations recipient-record) u1)))
                            (if (> current-dose u1)
                                (asserts! (>= (- CURRENT-CHAIN-HEIGHT 
                                    (get administration-timestamp (unwrap-panic (element-at 
                                        (get immunization-sequence recipient-record) 
                                        (- current-dose u2))))) 
                                    DOSE-INTERVAL-REQUIREMENT)
                                    MINIMUM-INTERVAL-VIOLATION)
                                true
                            )
                            
                            (ok (map-set immunization-registry
                                {recipient-id: recipient-id}
                                {
                                    immunization-sequence: (unwrap-panic (as-max-len? 
                                        (append (get immunization-sequence recipient-record)
                                            {
                                                shipment-reference: shipment-id,
                                                administration-timestamp: CURRENT-CHAIN-HEIGHT,
                                                vaccine-formulation: (get vaccine-brand-name shipment-data),
                                                sequence-number: current-dose,
                                                administering-clinician: tx-sender,
                                                clinic-location: clinic-location,
                                                next-dose-due-date: (some (+ CURRENT-CHAIN-HEIGHT DOSE-INTERVAL-REQUIREMENT))
                                            }
                                        ) u10)),
                                    completed-immunizations: current-dose,
                                    adverse-event-reports: (get adverse-event-reports recipient-record),
                                    medical-exemption: (get medical-exemption recipient-record)
                                }))))
                    ;; First immunization for recipient
                    (ok (map-set immunization-registry
                        {recipient-id: recipient-id}
                        {
                            immunization-sequence: (list 
                                {
                                    shipment-reference: shipment-id,
                                    administration-timestamp: CURRENT-CHAIN-HEIGHT,
                                    vaccine-formulation: (get vaccine-brand-name shipment-data),
                                    sequence-number: u1,
                                    administering-clinician: tx-sender,
                                    clinic-location: clinic-location,
                                    next-dose-due-date: (some (+ CURRENT-CHAIN-HEIGHT DOSE-INTERVAL-REQUIREMENT))
                                }),
                            completed-immunizations: u1,
                            adverse-event-reports: (list),
                            medical-exemption: none
                        })))
            )
            SHIPMENT-NOT-FOUND-ERROR
        )
    )
)
