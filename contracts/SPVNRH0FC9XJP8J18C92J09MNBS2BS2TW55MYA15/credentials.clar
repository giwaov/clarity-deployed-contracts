;; StackCred - Decentralized Education Credentials
;; Handles peer assessment and skill verification on Stacks blockchain

;; Constants
(define-constant contract-owner tx-sender)
(define-constant min-assessors u3)
(define-constant assessment-threshold u70)  ;; 70% approval needed
(define-constant max-assessors u20)  ;; Maximum number of assessors per skill
(define-constant standard-deviation-threshold u15)  ;; 15% deviation threshold
(define-constant reputation-penalty u5)  ;; Penalty for invalid assessments
(define-constant reputation-reward u2)  ;; Reward for valid assessments

;; traits
;;
;; Error codes
(define-constant err-not-authorized (err u100))
(define-constant err-already-registered (err u101))
(define-constant err-not-registered (err u102))
(define-constant err-insufficient-assessors (err u103))
(define-constant err-already-assessed (err u104))
(define-constant err-max-assessors-reached (err u105))
(define-constant err-invalid-score (err u106))
(define-constant err-invalid-skill-id (err u107))
(define-constant err-invalid-input (err u108))

;; token definitions
;;
;; Data Maps
(define-map users 
    principal 
    {
        registered: bool,
        skills: (list 20 uint),
        reputation: uint,
        total-assessments: uint,
        invalid-assessments: uint
    }
)

;; constants
;;
(define-map skill-reputation
    {user: principal, skill-id: uint}
    {
        reputation: uint,
        assessments-given: uint,
        valid-assessments: uint
    }
)

;; data vars
;;
(define-map skills 
    uint 
    {
        name: (string-ascii 50),
        description: (string-ascii 200),
        required-assessments: uint,
        category: (string-ascii 50)
    }
)

;; data maps
;;
(define-map skill-assessments
    {skill-id: uint, user: principal}
    {
        assessors: (list 20 principal),
        scores: (list 20 uint),
        verified: bool,
        timestamp: uint,
        mean-score: uint,
        standard-deviation: uint
    }
)

;; public functions
;;
;; Data var for skill ID counter
(define-data-var skill-id-counter uint u0)

;; read only functions
;;
;; Helper Functions for Validation
(define-private (is-valid-skill-id (skill-id uint))
    (match (map-get? skills skill-id)
        skill true
        false
    )
)

;; private functions
;;
(define-private (is-valid-string-200 (str (string-ascii 200)))
    (and 
        (not (is-eq str ""))
        (<= (len str) u200)
    )
)

(define-private (is-valid-string-50 (str (string-ascii 50)))
    (and 
        (not (is-eq str ""))
        (<= (len str) u50)
    )
)

(define-private (is-valid-name (str (string-ascii 50)))
    (and 
        (not (is-eq str ""))
        (<= (len str) u50)
        ;; Add any additional name-specific validation rules here
    )
)

(define-private (is-valid-category (str (string-ascii 50)))
    (and 
        (not (is-eq str ""))
        (<= (len str) u50)
        ;; Add any additional category-specific validation rules here
    )
)

(define-private (is-valid-description (str (string-ascii 200)))
    (and 
        (not (is-eq str ""))
        (<= (len str) u200)
        ;; Add any additional description-specific validation rules here
    )
)

;; Helper Functions for Statistical Calculations
(define-private (square (x uint))
    (* x x)
)

(define-private (calculate-mean (scores (list 20 uint)))
    (let (
        (sum (fold + scores u0))
        (count (len scores))
    )
    (if (> count u0)
        (/ sum count)
        u0
    ))
)

(define-private (square-diff-from-mean (score uint) (mean uint))
    (square (if (> score mean) 
        (- score mean)
        (- mean score)
    ))
)

(define-private (calculate-standard-deviation (scores (list 20 uint)) (mean uint))
    (let (
        (count (len scores))
        (squared-diffs (map square-diff-from-mean scores (list count mean)))
        (squared-diff-sum (fold + squared-diffs u0))
    )
    (if (> count u1)
        (sqrt (/ squared-diff-sum (- count u1)))
        u0
    ))
)

(define-private (sqrt (x uint))
    ;; Simple integer square root implementation
    (let ((guess (/ x u2)))
        (if (>= guess x)
            u1
            guess
        )
    )
)



;; Reputation Management Functions
(define-private (update-user-reputation (user principal) (skill-id uint) (is-valid bool))
    (begin
        (let (
            (current-user (unwrap! (map-get? users user) false))
            (current-skill-rep (default-to 
                {reputation: u0, assessments-given: u0, valid-assessments: u0}
                (map-get? skill-reputation {user: user, skill-id: skill-id})))
        )
            ;; Update overall user reputation
            (map-set users user
                (merge current-user {
                    reputation: (if is-valid
                        (+ (get reputation current-user) reputation-reward)
                        (if (> (get reputation current-user) reputation-penalty)
                            (- (get reputation current-user) reputation-penalty)
                            u0
                        )),
                    total-assessments: (+ (get total-assessments current-user) u1),
                    invalid-assessments: (if is-valid
                        (get invalid-assessments current-user)
                        (+ (get invalid-assessments current-user) u1)
                    )
                })
            )

            ;; Update skill-specific reputation
            (map-set skill-reputation
                {user: user, skill-id: skill-id}
                {
                    reputation: (if is-valid
                        (+ (get reputation current-skill-rep) reputation-reward)
                        (if (> (get reputation current-skill-rep) reputation-penalty)
                            (- (get reputation current-skill-rep) reputation-penalty)
                            u0
                        )),
                    assessments-given: (+ (get assessments-given current-skill-rep) u1),
                    valid-assessments: (if is-valid
                        (+ (get valid-assessments current-skill-rep) u1)
                        (get valid-assessments current-skill-rep)
                    )
                }
            )
        )
        true
    )
)

;; Private functions
(define-private (get-next-skill-id)
    (let ((current (var-get skill-id-counter)))
        (var-set skill-id-counter (+ current u1))
        current
    )
)

;; Helper function to process reputation updates
(define-private (process-assessor-reputation (assessor principal) (score uint) (mean uint) (std-dev uint) (skill-id uint))
    (let (
        (score-deviation (if (> score mean)
            (- score mean)
            (- mean score)
        ))
    )
        (update-user-reputation 
            assessor 
            skill-id
            (< score-deviation standard-deviation-threshold)
        )
    )
)

;; Public functions
(define-public (register-user)
    (let ((sender tx-sender))
        (asserts! (not (default-to false (get registered (map-get? users sender)))) err-already-registered)
        (ok (map-set users 
            sender
            {
                registered: true,
                skills: (list ),
                reputation: u0,
                total-assessments: u0,
                invalid-assessments: u0
            }
        ))
    )
)

(define-public (add-skill (name (string-ascii 50)) (description (string-ascii 200)) (required-assessments uint) (category (string-ascii 50)))
    (let ((skill-id (get-next-skill-id)))
        ;; Input validation
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (is-valid-name name) err-invalid-input)
        (asserts! (is-valid-description description) err-invalid-input)
        (asserts! (is-valid-category category) err-invalid-input)
        (asserts! (<= required-assessments max-assessors) err-invalid-score)
        (asserts! (> required-assessments u0) err-invalid-input)

        (ok (map-set skills 
            skill-id
            {
                name: name,
                description: description,
                required-assessments: required-assessments,
                category: category
            }
        ))
    )
)

(define-public (request-assessment (skill-id uint))
    (let ((sender tx-sender))
        ;; Input validation
        (asserts! (is-valid-skill-id skill-id) err-invalid-skill-id)
        (asserts! (default-to false (get registered (map-get? users sender))) err-not-registered)
        (asserts! (is-none (map-get? skill-assessments {skill-id: skill-id, user: sender})) err-already-assessed)

        (ok (map-set skill-assessments
            {skill-id: skill-id, user: sender}
            {
                assessors: (list ),
                scores: (list ),
                verified: false,
                timestamp: stacks-block-height,
                mean-score: u0,
                standard-deviation: u0
            }
        ))
    )
)
