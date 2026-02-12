;; title: targeting-engine
;; version: 1.0.0
;; summary: Match ads with relevant audiences
;; description: Audience segmentation, targeting criteria management, and ad-to-user matching system

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-criteria (err u103))
(define-constant err-segment-full (err u104))
(define-constant err-already-exists (err u105))
(define-constant err-invalid-score (err u106))

;; Targeting criteria types
(define-constant CRITERIA-AGE-RANGE u1)
(define-constant CRITERIA-LOCATION u2)
(define-constant CRITERIA-INTERESTS u3)
(define-constant CRITERIA-BEHAVIOR u4)
(define-constant CRITERIA-DEVICE u5)

;; Segment status
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-PAUSED u2)
(define-constant STATUS-ARCHIVED u3)

;; data vars
(define-data-var segment-nonce uint u0)
(define-data-var max-interests-per-user uint u20)
(define-data-var min-relevance-score uint u50) ;; Out of 100
(define-data-var max-segments-per-campaign uint u5)

;; data maps
(define-map audience-segments
    { segment-id: uint }
    {
        owner: principal,
        name: (string-utf8 100),
        description: (string-utf8 300),
        status: uint,
        min-age: uint,
        max-age: uint,
        locations: (list 10 (string-ascii 30)),
        required-interests: (list 10 (string-ascii 30)),
        excluded-interests: (list 5 (string-ascii 30)),
        min-activity-score: uint,
        estimated-size: uint,
        created-at: uint,
        updated-at: uint
    }
)

(define-map user-interests
    { user: principal }
    {
        interests: (list 20 (string-ascii 30)),
        interest-weights: (list 20 uint), ;; Corresponding weights (0-100)
        age: uint,
        location: (string-ascii 30),
        activity-score: uint,
        device-type: (string-ascii 20),
        last-updated: uint
    }
)

(define-map targeting-rules
    { campaign-id: uint, segment-id: uint }
    {
        bid-modifier: uint, ;; Percentage modifier (100 = no change, 150 = 1.5x bid)
        priority: uint,
        active: bool,
        created-at: uint
    }
)

(define-map segment-performance
    { segment-id: uint }
    {
        total-impressions: uint,
        total-clicks: uint,
        total-conversions: uint,
        conversion-rate: uint, ;; Multiplied by 10000 for precision
        avg-engagement-time: uint,
        last-performance-update: uint
    }
)

(define-map campaign-segments
    { campaign-id: uint }
    {
        segment-ids: (list 5 uint),
        primary-segment: uint
    }
)

(define-map user-segment-matches
    { user: principal, segment-id: uint }
    {
        relevance-score: uint, ;; 0-100
        last-matched: uint,
        match-count: uint
    }
)

(define-map exclusion-list
    { campaign-id: uint, user: principal }
    {
        excluded: bool,
        reason: (string-utf8 100),
        excluded-at: uint
    }
)

;; private functions
(define-private (calculate-relevance-score
    (user-data (tuple
        (interests (list 20 (string-ascii 30)))
        (interest-weights (list 20 uint))
        (age uint)
        (location (string-ascii 30))
        (activity-score uint)
    ))
    (segment-data (tuple
        (min-age uint)
        (max-age uint)
        (locations (list 10 (string-ascii 30)))
        (required-interests (list 10 (string-ascii 30)))
        (min-activity-score uint)
    ))
)
    (let
        (
            (age-match (and
                (>= (get age user-data) (get min-age segment-data))
                (<= (get age user-data) (get max-age segment-data))
            ))
            (activity-match (>= (get activity-score user-data) (get min-activity-score segment-data)))
            (base-score (if (and age-match activity-match) u50 u0))
        )
        ;; Simplified scoring - can be enhanced with interest matching logic
        base-score
    )
)

(define-private (is-valid-criteria-type (criteria-type uint))
    (or
        (is-eq criteria-type CRITERIA-AGE-RANGE)
        (is-eq criteria-type CRITERIA-LOCATION)
        (is-eq criteria-type CRITERIA-INTERESTS)
        (is-eq criteria-type CRITERIA-BEHAVIOR)
        (is-eq criteria-type CRITERIA-DEVICE)
    )
)

(define-private (calculate-conversion-rate (conversions uint) (impressions uint))
    (if (> impressions u0)
        (/ (* conversions u10000) impressions)
        u0
    )
)

;; read only functions
(define-read-only (get-segment (segment-id uint))
    (map-get? audience-segments { segment-id: segment-id })
)

(define-read-only (get-user-interests (user principal))
    (map-get? user-interests { user: user })
)

(define-read-only (get-targeting-rule (campaign-id uint) (segment-id uint))
    (map-get? targeting-rules { campaign-id: campaign-id, segment-id: segment-id })
)

(define-read-only (get-segment-performance (segment-id uint))
    (map-get? segment-performance { segment-id: segment-id })
)

(define-read-only (get-campaign-segments (campaign-id uint))
    (map-get? campaign-segments { campaign-id: campaign-id })
)

(define-read-only (get-user-segment-match (user principal) (segment-id uint))
    (map-get? user-segment-matches { user: user, segment-id: segment-id })
)

(define-read-only (is-user-excluded (campaign-id uint) (user principal))
    (match (map-get? exclusion-list { campaign-id: campaign-id, user: user })
        exclusion (get excluded exclusion)
        false
    )
)

(define-read-only (get-segment-nonce)
    (var-get segment-nonce)
)

;; public functions
(define-public (create-audience-segment
    (name (string-utf8 100))
    (description (string-utf8 300))
    (min-age uint)
    (max-age uint)
    (locations (list 10 (string-ascii 30)))
    (required-interests (list 10 (string-ascii 30)))
    (excluded-interests (list 5 (string-ascii 30)))
    (min-activity-score uint)
)
    (let
        (
            (segment-id (+ (var-get segment-nonce) u1))
        )
        (asserts! (< min-age max-age) err-invalid-criteria)
        (asserts! (<= min-activity-score u100) err-invalid-score)

        (map-set audience-segments
            { segment-id: segment-id }
            {
                owner: tx-sender,
                name: name,
                description: description,
                status: STATUS-ACTIVE,
                min-age: min-age,
                max-age: max-age,
                locations: locations,
                required-interests: required-interests,
                excluded-interests: excluded-interests,
                min-activity-score: min-activity-score,
                estimated-size: u0,
                created-at: stacks-block-time,
                updated-at: stacks-block-time
            }
        )

        (map-set segment-performance
            { segment-id: segment-id }
            {
                total-impressions: u0,
                total-clicks: u0,
                total-conversions: u0,
                conversion-rate: u0,
                avg-engagement-time: u0,
                last-performance-update: u0
            }
        )

        (var-set segment-nonce segment-id)
        (ok segment-id)
    )
)

(define-public (update-segment-criteria
    (segment-id uint)
    (min-age uint)
    (max-age uint)
    (locations (list 10 (string-ascii 30)))
    (required-interests (list 10 (string-ascii 30)))
    (min-activity-score uint)
)
    (let
        (
            (segment (unwrap! (map-get? audience-segments { segment-id: segment-id }) err-not-found))
        )
        (asserts! (is-eq tx-sender (get owner segment)) err-unauthorized)
        (asserts! (< min-age max-age) err-invalid-criteria)
        (asserts! (<= min-activity-score u100) err-invalid-score)

        (map-set audience-segments
            { segment-id: segment-id }
            (merge segment {
                min-age: min-age,
                max-age: max-age,
                locations: locations,
                required-interests: required-interests,
                min-activity-score: min-activity-score,
                updated-at: stacks-block-time
            })
        )
        (ok true)
    )
)

(define-public (update-user-preferences
    (interests (list 20 (string-ascii 30)))
    (interest-weights (list 20 uint))
    (age uint)
    (location (string-ascii 30))
    (device-type (string-ascii 20))
)
    (let
        (
            (existing-data (default-to
                {
                    interests: (list),
                    interest-weights: (list),
                    age: u0,
                    location: "",
                    activity-score: u0,
                    device-type: "",
                    last-updated: u0
                }
                (map-get? user-interests { user: tx-sender })
            ))
        )
        (asserts! (is-eq (len interests) (len interest-weights)) err-invalid-criteria)

        (map-set user-interests
            { user: tx-sender }
            {
                interests: interests,
                interest-weights: interest-weights,
                age: age,
                location: location,
                activity-score: (get activity-score existing-data),
                device-type: device-type,
                last-updated: stacks-block-time
            }
        )
        (ok true)
    )
)

(define-public (add-targeting-criteria
    (campaign-id uint)
    (segment-id uint)
    (bid-modifier uint)
    (priority uint)
)
    (let
        (
            (segment (unwrap! (map-get? audience-segments { segment-id: segment-id }) err-not-found))
            (campaign-data (default-to
                { segment-ids: (list), primary-segment: u0 }
                (map-get? campaign-segments { campaign-id: campaign-id })
            ))
        )
        (asserts! (is-eq (get status segment) STATUS-ACTIVE) err-invalid-criteria)

        (map-set targeting-rules
            { campaign-id: campaign-id, segment-id: segment-id }
            {
                bid-modifier: bid-modifier,
                priority: priority,
                active: true,
                created-at: stacks-block-time
            }
        )

        (map-set campaign-segments
            { campaign-id: campaign-id }
            {
                segment-ids: (unwrap! (as-max-len? (append (get segment-ids campaign-data) segment-id) u5) err-segment-full),
                primary-segment: (if (is-eq (get primary-segment campaign-data) u0) segment-id (get primary-segment campaign-data))
            }
        )
        (ok true)
    )
)

(define-public (match-user-to-segment (segment-id uint) (user principal))
    (let
        (
            (segment (unwrap! (map-get? audience-segments { segment-id: segment-id }) err-not-found))
            (user-data (unwrap! (map-get? user-interests { user: user }) err-not-found))
            (relevance-score (calculate-relevance-score
                {
                    interests: (get interests user-data),
                    interest-weights: (get interest-weights user-data),
                    age: (get age user-data),
                    location: (get location user-data),
                    activity-score: (get activity-score user-data)
                }
                {
                    min-age: (get min-age segment),
                    max-age: (get max-age segment),
                    locations: (get locations segment),
                    required-interests: (get required-interests segment),
                    min-activity-score: (get min-activity-score segment)
                }
            ))
            (existing-match (default-to
                { relevance-score: u0, last-matched: u0, match-count: u0 }
                (map-get? user-segment-matches { user: user, segment-id: segment-id })
            ))
        )
        (asserts! (>= relevance-score (var-get min-relevance-score)) err-invalid-score)

        (map-set user-segment-matches
            { user: user, segment-id: segment-id }
            {
                relevance-score: relevance-score,
                last-matched: stacks-block-time,
                match-count: (+ (get match-count existing-match) u1)
            }
        )
        (ok relevance-score)
    )
)

(define-public (get-matched-campaigns-for-user (user principal))
    (let
        (
            (user-data (unwrap! (map-get? user-interests { user: user }) err-not-found))
        )
        ;; Returns success - actual matching logic would iterate through segments
        (ok true)
    )
)

(define-public (exclude-user-from-campaign (campaign-id uint) (user principal) (reason (string-utf8 100)))
    (begin
        (map-set exclusion-list
            { campaign-id: campaign-id, user: user }
            {
                excluded: true,
                reason: reason,
                excluded-at: stacks-block-time
            }
        )
        (ok true)
    )
)

(define-public (remove-user-exclusion (campaign-id uint) (user principal))
    (begin
        (map-delete exclusion-list { campaign-id: campaign-id, user: user })
        (ok true)
    )
)

(define-public (track-segment-impression (segment-id uint))
    (let
        (
            (performance (unwrap! (map-get? segment-performance { segment-id: segment-id }) err-not-found))
            (new-impressions (+ (get total-impressions performance) u1))
        )
        (map-set segment-performance
            { segment-id: segment-id }
            (merge performance {
                total-impressions: new-impressions,
                conversion-rate: (calculate-conversion-rate (get total-conversions performance) new-impressions),
                last-performance-update: stacks-block-time
            })
        )
        (ok true)
    )
)

(define-public (track-segment-click (segment-id uint))
    (let
        (
            (performance (unwrap! (map-get? segment-performance { segment-id: segment-id }) err-not-found))
        )
        (map-set segment-performance
            { segment-id: segment-id }
            (merge performance {
                total-clicks: (+ (get total-clicks performance) u1),
                last-performance-update: stacks-block-time
            })
        )
        (ok true)
    )
)

(define-public (track-segment-conversion (segment-id uint))
    (let
        (
            (performance (unwrap! (map-get? segment-performance { segment-id: segment-id }) err-not-found))
            (new-conversions (+ (get total-conversions performance) u1))
        )
        (map-set segment-performance
            { segment-id: segment-id }
            (merge performance {
                total-conversions: new-conversions,
                conversion-rate: (calculate-conversion-rate new-conversions (get total-impressions performance)),
                last-performance-update: stacks-block-time
            })
        )
        (ok true)
    )
)

(define-public (update-segment-status (segment-id uint) (new-status uint))
    (let
        (
            (segment (unwrap! (map-get? audience-segments { segment-id: segment-id }) err-not-found))
        )
        (asserts! (is-eq tx-sender (get owner segment)) err-unauthorized)

        (map-set audience-segments
            { segment-id: segment-id }
            (merge segment {
                status: new-status,
                updated-at: stacks-block-time
            })
        )
        (ok true)
    )
)

(define-public (update-user-activity-score (user principal) (new-score uint))
    (let
        (
            (user-data (unwrap! (map-get? user-interests { user: user }) err-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-score u100) err-invalid-score)

        (map-set user-interests
            { user: user }
            (merge user-data {
                activity-score: new-score,
                last-updated: stacks-block-time
            })
        )
        (ok true)
    )
)

;; Admin functions
(define-public (set-min-relevance-score (new-score uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-score u100) err-invalid-score)
        (var-set min-relevance-score new-score)
        (ok true)
    )
)

(define-public (set-max-segments-per-campaign (new-max uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set max-segments-per-campaign new-max)
        (ok true)
    )
)
