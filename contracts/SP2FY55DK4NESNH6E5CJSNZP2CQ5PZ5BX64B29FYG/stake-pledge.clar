;; ============================================
;; STAKE-PLEDGE: Accountability Contract
;; ============================================
;; Stake STX on your commitments. Your judge decides if you succeed.
;; Success = get your stake back. Failure = stake is burned or sent to judge.

;; ============================================
;; CONSTANTS
;; ============================================

(define-constant CONTRACT_OWNER tx-sender)

;; Error codes
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_COMMITMENT_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_JUDGED (err u102))
(define-constant ERR_NOT_JUDGE (err u103))
(define-constant ERR_DEADLINE_NOT_REACHED (err u104))
(define-constant ERR_ALREADY_CLAIMED (err u105))
(define-constant ERR_NOT_CREATOR (err u106))
(define-constant ERR_NOT_SUCCESSFUL (err u107))
(define-constant ERR_INVALID_STAKE (err u108))
(define-constant ERR_INVALID_DEADLINE (err u109))
(define-constant ERR_SELF_JUDGE (err u110))

;; Commitment status
(define-constant STATUS_ACTIVE u1)
(define-constant STATUS_SUCCESS u2)
(define-constant STATUS_FAILED u3)
(define-constant STATUS_CLAIMED u4)

;; Minimum stake: 1 STX (1,000,000 microSTX)
(define-constant MIN_STAKE u1000000)

;; Blocks per day (~144 on Stacks)
(define-constant BLOCKS_PER_DAY u144)

;; ============================================
;; DATA STORAGE
;; ============================================

;; Commitment counter
(define-data-var commitment-counter uint u0)

;; Total STX staked (for stats)
(define-data-var total-staked uint u0)
(define-data-var total-burned uint u0)

;; Commitment data
(define-map commitments uint {
    creator: principal,
    judge: principal,
    description: (string-utf8 280),
    stake: uint,
    deadline: uint,
    status: uint,
    created-at: uint,
    judged-at: (optional uint)
})

;; User stats
(define-map user-stats principal {
    total-commitments: uint,
    successful: uint,
    failed: uint,
    total-staked: uint,
    total-lost: uint
})

;; ============================================
;; CORE FUNCTIONS
;; ============================================

;; Create a new commitment with STX stake
(define-public (create-commitment 
    (description (string-utf8 280))
    (judge principal)
    (deadline-blocks uint))
  (let
    (
      (creator tx-sender)
      (stake (stx-get-balance creator))
      (commitment-id (+ (var-get commitment-counter) u1))
      (deadline (+ stacks-block-height deadline-blocks))
    )
    ;; This function expects STX to be sent via stx-transfer in same tx
    ;; For simplicity, we'll use a separate stake function
    (ok commitment-id)
  )
)

;; Create and stake in one call
(define-public (pledge
    (description (string-utf8 280))
    (judge principal)
    (deadline-blocks uint)
    (stake-amount uint))
  (let
    (
      (creator tx-sender)
      (commitment-id (+ (var-get commitment-counter) u1))
      (deadline (+ stacks-block-height deadline-blocks))
    )
    ;; Validations
    (asserts! (>= stake-amount MIN_STAKE) ERR_INVALID_STAKE)
    (asserts! (> deadline-blocks u0) ERR_INVALID_DEADLINE)
    (asserts! (not (is-eq creator judge)) ERR_SELF_JUDGE)

    ;; Transfer stake to contract
    (try! (stx-transfer? stake-amount creator (as-contract tx-sender)))

    ;; Store commitment
    (map-set commitments commitment-id {
      creator: creator,
      judge: judge,
      description: description,
      stake: stake-amount,
      deadline: deadline,
      status: STATUS_ACTIVE,
      created-at: stacks-block-height,
      judged-at: none
    })

    ;; Update counter
    (var-set commitment-counter commitment-id)

    ;; Update stats
    (var-set total-staked (+ (var-get total-staked) stake-amount))
    (update-user-stats creator stake-amount)

    ;; Emit event
    (print {
      event: "commitment-created",
      id: commitment-id,
      creator: creator,
      judge: judge,
      stake: stake-amount,
      deadline: deadline,
      description: description
    })

    (ok commitment-id)
  )
)

;; Judge marks commitment as success or failure
(define-public (judge-commitment (commitment-id uint) (success bool))
  (let
    (
      (commitment (unwrap! (map-get? commitments commitment-id) ERR_COMMITMENT_NOT_FOUND))
      (caller tx-sender)
    )
    ;; Only judge can call
    (asserts! (is-eq caller (get judge commitment)) ERR_NOT_JUDGE)
    ;; Must still be active
    (asserts! (is-eq (get status commitment) STATUS_ACTIVE) ERR_ALREADY_JUDGED)
    ;; Deadline must be reached
    (asserts! (>= stacks-block-height (get deadline commitment)) ERR_DEADLINE_NOT_REACHED)

    ;; Update status
    (map-set commitments commitment-id 
      (merge commitment {
        status: (if success STATUS_SUCCESS STATUS_FAILED),
        judged-at: (some stacks-block-height)
      })
    )

    ;; If failed, handle the stake
    (if (not success)
      (begin
        ;; Burn the stake (send to a burn address)
        (try! (as-contract (stx-transfer? (get stake commitment) tx-sender (get judge commitment))))
        (var-set total-burned (+ (var-get total-burned) (get stake commitment)))
        (update-user-failure (get creator commitment) (get stake commitment))
      )
      (update-user-success (get creator commitment))
    )

    ;; Emit event
    (print {
      event: "commitment-judged",
      id: commitment-id,
      success: success,
      judge: caller,
      creator: (get creator commitment)
    })

    (ok success)
  )
)

;; Creator claims back stake after success
(define-public (claim-stake (commitment-id uint))
  (let
    (
      (commitment (unwrap! (map-get? commitments commitment-id) ERR_COMMITMENT_NOT_FOUND))
      (caller tx-sender)
    )
    ;; Only creator can claim
    (asserts! (is-eq caller (get creator commitment)) ERR_NOT_CREATOR)
    ;; Must be successful
    (asserts! (is-eq (get status commitment) STATUS_SUCCESS) ERR_NOT_SUCCESSFUL)

    ;; Update status to claimed
    (map-set commitments commitment-id 
      (merge commitment { status: STATUS_CLAIMED })
    )

    ;; Return stake to creator
    (try! (as-contract (stx-transfer? (get stake commitment) tx-sender caller)))

    ;; Emit event
    (print {
      event: "stake-claimed",
      id: commitment-id,
      creator: caller,
      amount: (get stake commitment)
    })

    (ok (get stake commitment))
  )
)

;; ============================================
;; HELPER FUNCTIONS
;; ============================================

(define-private (update-user-stats (user principal) (stake uint))
  (let
    (
      (stats (default-to 
        { total-commitments: u0, successful: u0, failed: u0, total-staked: u0, total-lost: u0 }
        (map-get? user-stats user)))
    )
    (map-set user-stats user {
      total-commitments: (+ (get total-commitments stats) u1),
      successful: (get successful stats),
      failed: (get failed stats),
      total-staked: (+ (get total-staked stats) stake),
      total-lost: (get total-lost stats)
    })
  )
)

(define-private (update-user-success (user principal))
  (let
    (
      (stats (unwrap-panic (map-get? user-stats user)))
    )
    (map-set user-stats user 
      (merge stats { successful: (+ (get successful stats) u1) })
    )
  )
)

(define-private (update-user-failure (user principal) (lost uint))
  (let
    (
      (stats (unwrap-panic (map-get? user-stats user)))
    )
    (map-set user-stats user {
      total-commitments: (get total-commitments stats),
      successful: (get successful stats),
      failed: (+ (get failed stats) u1),
      total-staked: (get total-staked stats),
      total-lost: (+ (get total-lost stats) lost)
    })
  )
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

(define-read-only (get-commitment (commitment-id uint))
  (map-get? commitments commitment-id)
)

(define-read-only (get-user-stats (user principal))
  (default-to 
    { total-commitments: u0, successful: u0, failed: u0, total-staked: u0, total-lost: u0 }
    (map-get? user-stats user))
)

(define-read-only (get-total-commitments)
  (var-get commitment-counter)
)

(define-read-only (get-global-stats)
  (ok {
    total-commitments: (var-get commitment-counter),
    total-staked: (var-get total-staked),
    total-burned: (var-get total-burned)
  })
)

(define-read-only (get-commitment-status (commitment-id uint))
  (match (map-get? commitments commitment-id)
    commitment (ok (get status commitment))
    ERR_COMMITMENT_NOT_FOUND
  )
)

(define-read-only (is-deadline-reached (commitment-id uint))
  (match (map-get? commitments commitment-id)
    commitment (ok (>= stacks-block-height (get deadline commitment)))
    ERR_COMMITMENT_NOT_FOUND
  )
)

(define-read-only (get-time-remaining (commitment-id uint))
  (match (map-get? commitments commitment-id)
    commitment 
      (let ((deadline (get deadline commitment)))
        (ok (if (>= stacks-block-height deadline)
          u0
          (- deadline stacks-block-height)))
      )
    ERR_COMMITMENT_NOT_FOUND
  )
)

(define-read-only (blocks-to-days (blocks uint))
  (/ blocks BLOCKS_PER_DAY)
)

(define-read-only (days-to-blocks (days uint))
  (* days BLOCKS_PER_DAY)
)
