;; title: social-governance
;; version:
;; summary:
;; description:

;; Decentralized Social Content Platform Smart Contract
;;
;; A comprehensive blockchain-based social platform enabling decentralized content creation,
;; community-driven upvoting, reputation-based governance, content moderation, and premium
;; promotional features with STX-based monetization.

;; ERROR CONSTANTS AND VALIDATION CODES

(define-constant ERR-UNAUTHORIZED-ACCESS (err u1000))
(define-constant ERR-DUPLICATE-VOTE-ATTEMPT (err u1001))
(define-constant ERR-CONTENT-NOT-FOUND (err u1002))
(define-constant ERR-SELF-VOTING-FORBIDDEN (err u1003))
(define-constant ERR-VOTE-REMOVAL-TIME-EXPIRED (err u1004))
(define-constant ERR-INVALID-INPUT-PARAMETER (err u1005))
(define-constant ERR-TRANSACTION-FAILED (err u1006))
(define-constant ERR-TEXT-LENGTH-EXCEEDED (err u1007))
(define-constant ERR-DESCRIPTION-TOO-LONG (err u1008))
(define-constant ERR-INVALID-CONTENT-REFERENCE (err u1009))
(define-constant ERR-EMPTY-INPUT-PROVIDED (err u1010))

;; PLATFORM CONFIGURATION CONSTANTS

(define-constant default-platform-fee-percentage u5)
(define-constant minimum-reputation-for-promotion u10)
(define-constant vote-reversal-time-limit-blocks u10)
(define-constant maximum-commission-rate u20)
(define-constant maximum-reputation-threshold u1000)
(define-constant minimum-boost-payment-amount u100000)
(define-constant maximum-category-text-length u20)
(define-constant maximum-description-text-length u50)

;; DATA STORAGE STRUCTURES

;; Primary content storage with comprehensive metadata
(define-map published-content-database
  { post-id: uint }
  {
    author-principal: principal,
    publication-timestamp: uint,
    total-upvote-count: uint,
    content-category-tag: (string-ascii 20),
    is-currently-active: bool,
  }
)

;; User voting interaction tracking
(define-map user-voting-history
  {
    voter-principal: principal,
    post-id: uint,
  }
  { vote-timestamp: uint }
)

;; Comprehensive user reputation and activity metrics
(define-map platform-user-profiles
  { user-principal: principal }
  {
    current-reputation-score: uint,
    total-content-published: uint,
    total-votes-given: uint,
    account-registration-block: uint,
  }
)

;; Featured and promoted content registry
(define-map promoted-content-registry
  { post-id: uint }
  {
    promotion-timestamp: uint,
    promotion-description: (string-ascii 50),
  }
)

;; PLATFORM STATE VARIABLES

(define-data-var contract-administrator-principal principal tx-sender)
(define-data-var global-content-id-counter uint u0)
(define-data-var platform-fee-percentage uint default-platform-fee-percentage)
(define-data-var minimum-reputation-for-content-promotion uint minimum-reputation-for-promotion)

;; UTILITY AND VALIDATION FUNCTIONS

;; Comprehensive content validation with status checking
(define-private (validate-content-availability (post-id uint))
  (let ((content-record (map-get? published-content-database { post-id: post-id })))
    (if (is-some content-record)
      (let ((content-data (unwrap-panic content-record)))
        (if (get is-currently-active content-data)
          (ok content-data)
          ERR-CONTENT-NOT-FOUND
        )
      )
      ERR-CONTENT-NOT-FOUND
    )
  )
)

;; READ-ONLY QUERY FUNCTIONS

;; Retrieve complete content information by ID
(define-read-only (fetch-content-by-id (post-id uint))
  (map-get? published-content-database { post-id: post-id })
)

;; Check user's voting status for specific content
(define-read-only (check-user-vote-status
    (user-address principal)
    (post-id uint)
  )
  (is-some (map-get? user-voting-history {
    voter-principal: user-address,
    post-id: post-id,
  }))
)

;; Platform statistics and metrics
(define-read-only (get-platform-content-count)
  (var-get global-content-id-counter)
)

;; Content promotion status verification
(define-read-only (check-content-promotion-status (post-id uint))
  (is-some (map-get? promoted-content-registry { post-id: post-id }))
)

;; Current platform fee configuration
(define-read-only (get-current-platform-fee-rate)
  (var-get platform-fee-percentage)
)

;; Content discovery and ranking (requires external indexing)
(define-read-only (discover-trending-content
    (category-filter (string-ascii 20))
    (limit-results uint)
  )
  (err "Trending content discovery requires external indexing service integration")
)

;; Current platform administrator
(define-read-only (get-platform-administrator)
  (var-get contract-administrator-principal)
)

;; Remove content from featured status (admin only)
(define-public (remove-content-from-featured (target-post-id uint))
  (begin
    ;; Input validation
    (asserts!
      (and
        (>= target-post-id u0)
        (< target-post-id (var-get global-content-id-counter))
      )
      ERR-INVALID-CONTENT-REFERENCE
    )

    ;; Admin access verification
    (asserts! (is-eq tx-sender (var-get contract-administrator-principal))
      ERR-UNAUTHORIZED-ACCESS
    )

    ;; Verify content exists
    (asserts! (is-some (fetch-content-by-id target-post-id))
      ERR-CONTENT-NOT-FOUND
    )

    ;; Remove from promotion registry
    (map-delete promoted-content-registry { post-id: target-post-id })

    (ok true)
  )
)

;; CONTENT STATUS MANAGEMENT

;; Deactivate content (author or admin only)
(define-public (set-content-inactive (target-post-id uint))
  (begin
    ;; Input validation
    (asserts!
      (and
        (>= target-post-id u0)
        (< target-post-id (var-get global-content-id-counter))
      )
      ERR-INVALID-CONTENT-REFERENCE
    )

    (let (
        (requesting-user tx-sender)
        (content-data (unwrap! (fetch-content-by-id target-post-id) ERR-CONTENT-NOT-FOUND))
        (is-content-owner (is-eq requesting-user (get author-principal content-data)))
        (is-platform-admin (is-eq requesting-user (var-get contract-administrator-principal)))
      )
      ;; Verify user has deactivation privileges
      (asserts! (or is-content-owner is-platform-admin) ERR-UNAUTHORIZED-ACCESS)

      ;; Update content status to inactive
      (map-set published-content-database { post-id: target-post-id }
        (merge content-data { is-currently-active: false })
      )

      ;; Remove from promoted registry if present
      (if (check-content-promotion-status target-post-id)
        (map-delete promoted-content-registry { post-id: target-post-id })
        true
      )

      (ok true)
    )
  )
)

;; Reactivate previously deactivated content (author only)
(define-public (set-content-active (target-post-id uint))
  (begin
    ;; Input validation
    (asserts!
      (and
        (>= target-post-id u0)
        (< target-post-id (var-get global-content-id-counter))
      )
      ERR-INVALID-CONTENT-REFERENCE
    )

    (let (
        (requesting-user tx-sender)
        (content-data (unwrap! (fetch-content-by-id target-post-id) ERR-CONTENT-NOT-FOUND))
      )
      ;; Verify user is content owner
      (asserts! (is-eq requesting-user (get author-principal content-data))
        ERR-UNAUTHORIZED-ACCESS
      )

      ;; Update content status to active
      (map-set published-content-database { post-id: target-post-id }
        (merge content-data { is-currently-active: true })
      )

      (ok true)
    )
  )
)

;; ADMINISTRATIVE FUNCTIONS

;; Update platform fee percentage (admin only)
(define-public (configure-platform-fee (new-fee-percentage uint))
  (begin
    ;; Admin access verification
    (asserts! (is-eq tx-sender (var-get contract-administrator-principal))
      ERR-UNAUTHORIZED-ACCESS
    )

    ;; Validate fee is within reasonable bounds
    (asserts! (<= new-fee-percentage maximum-commission-rate)
      ERR-INVALID-INPUT-PARAMETER
    )

    ;; Update platform fee
    (var-set platform-fee-percentage new-fee-percentage)

    (ok true)
  )
)

;; Update minimum reputation threshold for content promotion (admin only)
(define-public (configure-promotion-reputation-threshold (new-threshold uint))
  (begin
    ;; Admin access verification
    (asserts! (is-eq tx-sender (var-get contract-administrator-principal))
      ERR-UNAUTHORIZED-ACCESS
    )

    ;; Validate threshold is reasonable
    (asserts! (<= new-threshold maximum-reputation-threshold)
      ERR-INVALID-INPUT-PARAMETER
    )

    ;; Update reputation threshold
    (var-set minimum-reputation-for-content-promotion new-threshold)

    (ok true)
  )
)

;; Transfer administrative privileges (admin only)
(define-public (transfer-platform-administration (new-admin-principal principal))
  (begin
    ;; Admin access verification
    (asserts! (is-eq tx-sender (var-get contract-administrator-principal))
      ERR-UNAUTHORIZED-ACCESS
    )

    ;; Validate new administrator is not null address
    (asserts! (not (is-eq new-admin-principal 'SP000000000000000000002Q6VF78))
      ERR-INVALID-INPUT-PARAMETER
    )

    ;; Transfer administrative rights
    (var-set contract-administrator-principal new-admin-principal)

    (ok true)
  )
)

;; CONTRACT INITIALIZATION

;; Initialize platform with custom administrator
(define-public (initialize-platform-configuration (initial-admin principal))
  (begin
    ;; Current admin access verification
    (asserts! (is-eq tx-sender (var-get contract-administrator-principal))
      ERR-UNAUTHORIZED-ACCESS
    )

    ;; Validate new administrator is not null address
    (asserts! (not (is-eq initial-admin 'SP000000000000000000002Q6VF78))
      ERR-INVALID-INPUT-PARAMETER
    )

    ;; Set initial administrator if different from deployer
    (if (not (is-eq (var-get contract-administrator-principal) initial-admin))
      (var-set contract-administrator-principal initial-admin)
      true
    )

    (ok true)
  )
)
