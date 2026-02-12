;; Loiters Communities
;; Community/group management with governance

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MAX-COMMUNITY-NAME-LENGTH u64)
(define-constant MAX-COMMUNITY-DESCRIPTION-LENGTH u512)
(define-constant MIN-COMMUNITY-NAME-LENGTH u3)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u4000))
(define-constant ERR-COMMUNITY-NOT-FOUND (err u4001))
(define-constant ERR-NOT-MEMBER (err u4002))
(define-constant ERR-ALREADY-MEMBER (err u4003))
(define-constant ERR-INVALID-PARAMS (err u4004))
(define-constant ERR-INSUFFICIENT-ROLE (err u4005))
(define-constant ERR-COMMUNITY-FULL (err u4006))
(define-constant ERR-REQUIREMENTS-NOT-MET (err u4007))
(define-constant ERR-INVALID-NAME (err u4008))

;; Role constants
(define-constant ROLE-OWNER u4)
(define-constant ROLE-ADMIN u3)
(define-constant ROLE-MODERATOR u2)
(define-constant ROLE-MEMBER u1)

;; Data Variables
(define-data-var community-counter uint u0)

;; Data Maps

;; Community data
(define-map communities
  uint
  {
    name: (string-utf8 64),
    description: (string-utf8 512),
    image-uri: (string-utf8 256),
    owner: principal,
    created-at: uint,
    is-private: bool,
    member-count: uint,
    max-members: uint,
    min-reputation: uint,
    min-tokens: uint
  }
)

;; Community members
(define-map community-members
  {community-id: uint, member: principal}
  {
    role: uint,
    joined-at: uint,
    contribution-score: uint
  }
)

;; Member count per community
(define-map member-counts uint uint)

;; Community proposals
(define-map community-proposals
  {community-id: uint, proposal-id: uint}
  {
    proposer: principal,
    title: (string-utf8 128),
    description: (string-utf8 512),
    proposal-type: uint, ;; 1=parameter change, 2=member action, 3=treasury
    created-at: uint,
    voting-ends-at: uint,
    votes-for: uint,
    votes-against: uint,
    executed: bool,
    passed: bool
  }
)

;; Proposal counter per community
(define-map community-proposal-counts uint uint)

;; Votes on proposals
(define-map proposal-votes
  {community-id: uint, proposal-id: uint, voter: principal}
  {
    vote: bool, ;; true = for, false = against
    voting-power: uint,
    timestamp: uint
  }
)

;; Community treasury
(define-map community-treasuries uint uint) ;; community-id -> LOIT balance

;; Read-only functions

(define-read-only (get-community (community-id uint))
  (map-get? communities community-id)
)

(define-read-only (get-member-info (community-id uint) (member principal))
  (map-get? community-members {community-id: community-id, member: member})
)

(define-read-only (is-member (community-id uint) (user principal))
  (is-some (map-get? community-members {community-id: community-id, member: user}))
)

(define-read-only (get-member-role (community-id uint) (member principal))
  (match (map-get? community-members {community-id: community-id, member: member})
    member-data (some (get role member-data))
    none
  )
)

(define-read-only (get-proposal (community-id uint) (proposal-id uint))
  (map-get? community-proposals {community-id: community-id, proposal-id: proposal-id})
)

(define-read-only (get-vote (community-id uint) (proposal-id uint) (voter principal))
  (map-get? proposal-votes {community-id: community-id, proposal-id: proposal-id, voter: voter})
)

(define-read-only (get-community-treasury (community-id uint))
  (default-to u0 (map-get? community-treasuries community-id))
)

(define-read-only (get-total-communities)
  (var-get community-counter)
)

;; Public functions

;; Create a new community
(define-public (create-community 
  (name (string-utf8 64))
  (description (string-utf8 512))
  (image-uri (string-utf8 256))
  (is-private bool)
  (max-members uint)
  (min-reputation uint)
  (min-tokens uint))
  (let
    (
      (new-community-id (+ (var-get community-counter) u1))
      (name-len (len name))
      (user-data (unwrap! (contract-call? .loiters-core get-user tx-sender) ERR-NOT-AUTHORIZED))
    )
    (asserts! (and (>= name-len MIN-COMMUNITY-NAME-LENGTH) (<= name-len MAX-COMMUNITY-NAME-LENGTH)) ERR-INVALID-NAME)
    (asserts! (> max-members u0) ERR-INVALID-PARAMS)
    
    ;; Create community
    (map-set communities new-community-id {
      name: name,
      description: description,
      image-uri: image-uri,
      owner: tx-sender,
      created-at: stacks-block-height,
      is-private: is-private,
      member-count: u1,
      max-members: max-members,
      min-reputation: min-reputation,
      min-tokens: min-tokens
    })
    
    ;; Add creator as owner/member
    (map-set community-members {community-id: new-community-id, member: tx-sender} {
      role: ROLE-OWNER,
      joined-at: stacks-block-height,
      contribution-score: u0
    })
    
    (map-set member-counts new-community-id u1)
    (map-set community-treasuries new-community-id u0)
    (map-set community-proposal-counts new-community-id u0)
    
    (var-set community-counter new-community-id)
    
    (print {
      type: "community-created",
      community-id: new-community-id,
      name: name,
      owner: tx-sender,
      timestamp: stacks-block-height
    })
    
    (ok new-community-id)
  )
)

;; Join a community
(define-public (join-community (community-id uint))
  (let
    (
      (community (unwrap! (map-get? communities community-id) ERR-COMMUNITY-NOT-FOUND))
      (user-data (unwrap! (contract-call? .loiters-core get-user tx-sender) ERR-NOT-AUTHORIZED))
      (current-members (get member-count community))
    )
    (asserts! (not (is-member community-id tx-sender)) ERR-ALREADY-MEMBER)
    (asserts! (< current-members (get max-members community)) ERR-COMMUNITY-FULL)
    
    ;; Check requirements
    (asserts! (>= (get reputation-score user-data) (get min-reputation community)) ERR-REQUIREMENTS-NOT-MET)
    ;; Token requirement check would go here when integrated
    
    ;; Add member
    (map-set community-members {community-id: community-id, member: tx-sender} {
      role: ROLE-MEMBER,
      joined-at: stacks-block-height,
      contribution-score: u0
    })
    
    ;; Update member count
    (map-set communities community-id (merge community {
      member-count: (+ current-members u1)
    }))
    
    (print {
      type: "member-joined",
      community-id: community-id,
      member: tx-sender,
      timestamp: stacks-block-height
    })
    
    (ok true)
  )
)

;; Leave a community
(define-public (leave-community (community-id uint))
  (let
    (
      (community (unwrap! (map-get? communities community-id) ERR-COMMUNITY-NOT-FOUND))
      (member-info (unwrap! (get-member-info community-id tx-sender) ERR-NOT-MEMBER))
    )
    ;; Owner cannot leave their own community
    (asserts! (not (is-eq (get role member-info) ROLE-OWNER)) ERR-NOT-AUTHORIZED)
    
    ;; Remove member
    (map-delete community-members {community-id: community-id, member: tx-sender})
    
    ;; Update member count
    (map-set communities community-id (merge community {
      member-count: (- (get member-count community) u1)
    }))
    
    (print {
      type: "member-left",
      community-id: community-id,
      member: tx-sender,
      timestamp: stacks-block-height
    })
    
    (ok true)
  )
)

;; Create a proposal
(define-public (create-proposal
  (community-id uint)
  (title (string-utf8 128))
  (description (string-utf8 512))
  (proposal-type uint))
  (let
    (
      (community (unwrap! (map-get? communities community-id) ERR-COMMUNITY-NOT-FOUND))
      (member-info (unwrap! (get-member-info community-id tx-sender) ERR-NOT-MEMBER))
      (proposal-count (default-to u0 (map-get? community-proposal-counts community-id)))
      (new-proposal-id (+ proposal-count u1))
      (voting-period u1008) ;; ~7 days in blocks (assuming 10 min blocks)
    )
    ;; Only members can create proposals
    (asserts! (>= (get role member-info) ROLE-MEMBER) ERR-NOT-MEMBER)
    
    ;; Create proposal
    (map-set community-proposals {community-id: community-id, proposal-id: new-proposal-id} {
      proposer: tx-sender,
      title: title,
      description: description,
      proposal-type: proposal-type,
      created-at: stacks-block-height,
      voting-ends-at: (+ stacks-block-height voting-period),
      votes-for: u0,
      votes-against: u0,
      executed: false,
      passed: false
    })
    
    (map-set community-proposal-counts community-id new-proposal-id)
    
    (print {
      type: "proposal-created",
      community-id: community-id,
      proposal-id: new-proposal-id,
      proposer: tx-sender,
      title: title,
      timestamp: stacks-block-height
    })
    
    (ok new-proposal-id)
  )
)

;; Vote on a proposal
(define-public (vote-on-proposal (community-id uint) (proposal-id uint) (vote-for bool))
  (let
    (
      (proposal (unwrap! (get-proposal community-id proposal-id) ERR-NOT-AUTHORIZED))
      (member-info (unwrap! (get-member-info community-id tx-sender) ERR-NOT-MEMBER))
      (user-data (unwrap! (contract-call? .loiters-core get-user tx-sender) ERR-NOT-AUTHORIZED))
      (voting-power (+ (get reputation-score user-data) (get contribution-score member-info)))
    )
    ;; Check voting is still open
    (asserts! (<= stacks-block-height (get voting-ends-at proposal)) ERR-NOT-AUTHORIZED)
    
    ;; Check hasn't already voted
    (asserts! (is-none (get-vote community-id proposal-id tx-sender)) ERR-NOT-AUTHORIZED)
    
    ;; Record vote
    (map-set proposal-votes {community-id: community-id, proposal-id: proposal-id, voter: tx-sender} {
      vote: vote-for,
      voting-power: voting-power,
      timestamp: stacks-block-height
    })
    
    ;; Update vote counts
    (if vote-for
      (map-set community-proposals {community-id: community-id, proposal-id: proposal-id}
        (merge proposal {votes-for: (+ (get votes-for proposal) voting-power)}))
      (map-set community-proposals {community-id: community-id, proposal-id: proposal-id}
        (merge proposal {votes-against: (+ (get votes-against proposal) voting-power)}))
    )
    
    (print {
      type: "vote-cast",
      community-id: community-id,
      proposal-id: proposal-id,
      voter: tx-sender,
      vote-for: vote-for,
      voting-power: voting-power,
      timestamp: stacks-block-height
    })
    
    (ok true)
  )
)

;; Execute a passed proposal
(define-public (execute-proposal (community-id uint) (proposal-id uint))
  (let
    (
      (proposal (unwrap! (get-proposal community-id proposal-id) ERR-NOT-AUTHORIZED))
      (member-info (unwrap! (get-member-info community-id tx-sender) ERR-NOT-MEMBER))
    )
    ;; Check voting has ended
    (asserts! (> stacks-block-height (get voting-ends-at proposal)) ERR-NOT-AUTHORIZED)
    
    ;; Check not already executed
    (asserts! (not (get executed proposal)) ERR-NOT-AUTHORIZED)
    
    ;; Check proposal passed (simple majority)
    (asserts! (> (get votes-for proposal) (get votes-against proposal)) ERR-NOT-AUTHORIZED)
    
    ;; Only admins and above can execute
    (asserts! (>= (get role member-info) ROLE-ADMIN) ERR-INSUFFICIENT-ROLE)
    
    ;; Mark as executed and passed
    (map-set community-proposals {community-id: community-id, proposal-id: proposal-id}
      (merge proposal {executed: true, passed: true}))
    
    (print {
      type: "proposal-executed",
      community-id: community-id,
      proposal-id: proposal-id,
      executor: tx-sender,
      timestamp: stacks-block-height
    })
    
    (ok true)
  )
)

;; Update member role (admin function)
(define-public (update-member-role (community-id uint) (member principal) (new-role uint))
  (let
    (
      (community (unwrap! (map-get? communities community-id) ERR-COMMUNITY-NOT-FOUND))
      (caller-info (unwrap! (get-member-info community-id tx-sender) ERR-NOT-MEMBER))
      (member-info (unwrap! (get-member-info community-id member) ERR-NOT-MEMBER))
    )
    ;; Only owner or admin can update roles
    (asserts! (>= (get role caller-info) ROLE-ADMIN) ERR-INSUFFICIENT-ROLE)
    
    ;; Cannot change owner role
    (asserts! (not (is-eq (get role member-info) ROLE-OWNER)) ERR-NOT-AUTHORIZED)
    
    ;; Update role
    (map-set community-members {community-id: community-id, member: member}
      (merge member-info {role: new-role}))
    
    (print {
      type: "role-updated",
      community-id: community-id,
      member: member,
      new-role: new-role,
      updated-by: tx-sender,
      timestamp: stacks-block-height
    })
    
    (ok true)
  )
)
