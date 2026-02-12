;; Mentorship Contract
;; Handles mentor-student matching, agreements, and reputation tracking

(define-constant ERR-UNAUTHORIZED (err u5001))
(define-constant ERR-MENTORSHIP-NOT-FOUND (err u5002))
(define-constant ERR-INVALID-STATUS (err u5003))
(define-constant ERR-ALREADY-MENTOR (err u5004))

;; Mentorship status: 0 = pending, 1 = active, 2 = completed, 3 = cancelled
(define-map mentorships
    { mentorship-id: uint }
    {
        mentor: principal,
        mentee: principal,
        startup-id: uint,
        agreement-terms: (string-utf8 500),
        status: uint,
        start-time: uint,
        end-time: (optional uint),
        reward-amount: uint,
        reputation-score: uint,
        created-at: uint
    }
)

;; Mentor profiles
(define-map mentor-profiles
    { mentor: principal }
    {
        expertise: (string-utf8 200),
        bio: (string-utf8 500),
        reputation: uint,
        total-mentorships: uint,
        successful-mentorships: uint,
        registered-at: uint
    }
)

;; Mentorship requests
(define-map mentorship-requests
    { startup-id: uint, requester: principal }
    {
        mentorship-id: (optional uint),
        expertise-needed: (string-utf8 200),
        description: (string-utf8 500),
        status: uint, ;; 0: open, 1: matched, 2: closed
        created-at: uint
    }
)

(define-data-var next-mentorship-id uint u1)

;; Register as a mentor
(define-public (register-mentor
    (expertise (string-utf8 200))
    (bio (string-utf8 500))
)
    (let
        (
            (mentor tx-sender)
            (timestamp (unwrap! (get-block-info? time u0) ERR-UNAUTHORIZED))
            (existing-profile (map-get? mentor-profiles { mentor: mentor }))
        )
        (asserts! (is-none existing-profile) ERR-ALREADY-MENTOR)
        (ok (map-set mentor-profiles
            { mentor: mentor }
            {
                expertise: expertise,
                bio: bio,
                reputation: u0,
                total-mentorships: u0,
                successful-mentorships: u0,
                registered-at: timestamp
            }
        ))
    )
)

;; Create mentorship request
(define-public (request-mentorship
    (startup-id uint)
    (expertise-needed (string-utf8 200))
    (description (string-utf8 500))
)
    (let
        (
            (requester tx-sender)
            (timestamp (unwrap! (get-block-info? time u0) ERR-UNAUTHORIZED))
        )
        (ok (map-set mentorship-requests
            { startup-id: startup-id, requester: requester }
            {
                mentorship-id: none,
                expertise-needed: expertise-needed,
                description: description,
                status: u0,
                created-at: timestamp
            }
        ))
    )
)

;; Accept mentorship request and create mentorship
(define-public (accept-mentorship
    (startup-id uint)
    (requester principal)
    (agreement-terms (string-utf8 500))
    (reward-amount uint)
)
    (let
        (
            (mentor tx-sender)
            (request (unwrap! (map-get? mentorship-requests { startup-id: startup-id, requester: requester }) ERR-MENTORSHIP-NOT-FOUND))
            (mentorship-id (var-get next-mentorship-id))
            (timestamp (unwrap! (get-block-info? time u0) ERR-UNAUTHORIZED))
        )
        (asserts! (is-eq (get status request) u0) ERR-INVALID-STATUS)
        (begin
            (map-set mentorships
                { mentorship-id: mentorship-id }
                {
                    mentor: mentor,
                    mentee: requester,
                    startup-id: startup-id,
                    agreement-terms: agreement-terms,
                    status: u1,
                    start-time: timestamp,
                    end-time: none,
                    reward-amount: reward-amount,
                    reputation-score: u0,
                    created-at: timestamp
                }
            )
            (map-set mentorship-requests
                { startup-id: startup-id, requester: requester }
                {
                    mentorship-id: (some mentorship-id),
                    expertise-needed: (get expertise-needed request),
                    description: (get description request),
                    status: u1,
                    created-at: (get created-at request)
                }
            )
            (var-set next-mentorship-id (+ mentorship-id u1))
            (ok mentorship-id)
        )
    )
)

;; Complete mentorship
(define-public (complete-mentorship
    (mentorship-id uint)
    (reputation-score uint)
)
    (let
        (
            (mentorship (unwrap! (map-get? mentorships { mentorship-id: mentorship-id }) ERR-MENTORSHIP-NOT-FOUND))
            (timestamp (unwrap! (get-block-info? time u0) ERR-UNAUTHORIZED))
            (mentor (get mentor mentorship))
            (mentor-profile (unwrap! (map-get? mentor-profiles { mentor: mentor }) ERR-MENTORSHIP-NOT-FOUND))
        )
        (asserts! (is-eq (get status mentorship) u1) ERR-INVALID-STATUS)
        (asserts! (or (is-eq tx-sender (get mentee mentorship)) (is-eq tx-sender mentor)) ERR-UNAUTHORIZED)
        (asserts! (<= reputation-score u100) ERR-INVALID-STATUS)
        (let
            (
                (new-reputation (/ (+ (* (get reputation mentor-profile) (get total-mentorships mentor-profile)) reputation-score) (+ (get total-mentorships mentor-profile) u1)))
                (new-total (+ (get total-mentorships mentor-profile) u1))
                (new-successful (if (>= reputation-score u70) (+ (get successful-mentorships mentor-profile) u1) (get successful-mentorships mentor-profile)))
            )
            (begin
                (map-set mentorships
                    { mentorship-id: mentorship-id }
                    {
                        mentor: mentor,
                        mentee: (get mentee mentorship),
                        startup-id: (get startup-id mentorship),
                        agreement-terms: (get agreement-terms mentorship),
                        status: u2,
                        start-time: (get start-time mentorship),
                        end-time: (some timestamp),
                        reward-amount: (get reward-amount mentorship),
                        reputation-score: reputation-score,
                        created-at: (get created-at mentorship)
                    }
                )
                (map-set mentor-profiles
                    { mentor: mentor }
                    {
                        expertise: (get expertise mentor-profile),
                        bio: (get bio mentor-profile),
                        reputation: new-reputation,
                        total-mentorships: new-total,
                        successful-mentorships: new-successful,
                        registered-at: (get registered-at mentor-profile)
                    }
                )
                (ok true)
            )
        )
    )
)

;; Get mentorship
(define-read-only (get-mentorship (mentorship-id uint))
    (map-get? mentorships { mentorship-id: mentorship-id })
)

;; Get mentor profile
(define-read-only (get-mentor-profile (mentor principal))
    (map-get? mentor-profiles { mentor: mentor })
)

;; Get mentorship request
(define-read-only (get-mentorship-request (startup-id uint) (requester principal))
    (map-get? mentorship-requests { startup-id: startup-id, requester: requester })
)

