(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u1700))
(define-constant ERR_COUNCIL_NOT_FOUND (err u1701))
(define-constant ERR_AGENT_NOT_FOUND (err u1702))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u1703))

(define-data-var next-council-id uint u1)
(define-data-var next-agent-id uint u1)
(define-data-var next-proposal-id uint u1)

(define-map councils
  uint
  {
    name: (string-ascii 128),
    creator: principal,
    member-count: uint,
    created-at: uint,
    active: bool
  }
)

(define-map ai-agents
  uint
  {
    owner: principal,
    agent-type: (string-ascii 64),
    public-key: (buff 33),
    capabilities: (buff 256),
    reputation-score: uint,
    created-at: uint
  }
)

(define-map council-members
  {council-id: uint, agent-id: uint}
  bool
)

(define-map proposals
  uint
  {
    council-id: uint,
    proposer: uint,
    description: (string-ascii 512),
    votes-for: uint,
    votes-against: uint,
    status: (string-ascii 20),
    created-at: uint
  }
)

(define-map agent-votes
  {proposal-id: uint, agent-id: uint}
  bool
)

(define-read-only (get-contract-hash)
  (contract-hash? .ai-agent-council)
)

(define-read-only (get-council (council-id uint))
  (ok (unwrap! (map-get? councils council-id) ERR_COUNCIL_NOT_FOUND))
)

(define-read-only (get-agent (agent-id uint))
  (ok (unwrap! (map-get? ai-agents agent-id) ERR_AGENT_NOT_FOUND))
)

(define-read-only (get-proposal (proposal-id uint))
  (ok (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
)

(define-public (create-council (name (string-ascii 128)))
  (let
    (
      (council-id (var-get next-council-id))
    )
    (map-set councils council-id {
      name: name,
      creator: tx-sender,
      member-count: u0,
      created-at: stacks-block-time,
      active: true
    })
    (var-set next-council-id (+ council-id u1))
    (ok council-id)
  )
)

(define-public (register-agent 
  (agent-type (string-ascii 64))
  (public-key (buff 33))
  (capabilities (buff 256))
)
  (let
    (
      (agent-id (var-get next-agent-id))
    )
    (map-set ai-agents agent-id {
      owner: tx-sender,
      agent-type: agent-type,
      public-key: public-key,
      capabilities: capabilities,
      reputation-score: u100,
      created-at: stacks-block-time
    })
    (var-set next-agent-id (+ agent-id u1))
    (ok agent-id)
  )
)

(define-public (join-council (council-id uint) (agent-id uint))
  (let
    (
      (council-data (unwrap! (map-get? councils council-id) ERR_COUNCIL_NOT_FOUND))
      (agent-data (unwrap! (map-get? ai-agents agent-id) ERR_AGENT_NOT_FOUND))
    )
    (asserts! (is-eq (get owner agent-data) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (get active council-data) ERR_NOT_AUTHORIZED)
    (map-set council-members {council-id: council-id, agent-id: agent-id} true)
    (map-set councils council-id (merge council-data {
      member-count: (+ (get member-count council-data) u1)
    }))
    (ok true)
  )
)

(define-public (create-proposal 
  (council-id uint)
  (agent-id uint)
  (description (string-ascii 512))
)
  (let
    (
      (proposal-id (var-get next-proposal-id))
      (is-member (default-to false (map-get? council-members {council-id: council-id, agent-id: agent-id})))
    )
    (asserts! is-member ERR_NOT_AUTHORIZED)
    (map-set proposals proposal-id {
      council-id: council-id,
      proposer: agent-id,
      description: description,
      votes-for: u0,
      votes-against: u0,
      status: "Active",
      created-at: stacks-block-time
    })
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal 
  (proposal-id uint)
  (agent-id uint)
  (vote-for bool)
)
  (let
    (
      (proposal-data (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (agent-data (unwrap! (map-get? ai-agents agent-id) ERR_AGENT_NOT_FOUND))
      (is-member (default-to false (map-get? council-members {council-id: (get council-id proposal-data), agent-id: agent-id})))
      (already-voted (default-to false (map-get? agent-votes {proposal-id: proposal-id, agent-id: agent-id})))
    )
    (asserts! (is-eq (get owner agent-data) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! is-member ERR_NOT_AUTHORIZED)
    (asserts! (not already-voted) ERR_NOT_AUTHORIZED)
    (map-set agent-votes {proposal-id: proposal-id, agent-id: agent-id} true)
    (if vote-for
      (map-set proposals proposal-id (merge proposal-data {
        votes-for: (+ (get votes-for proposal-data) u1)
      }))
      (map-set proposals proposal-id (merge proposal-data {
        votes-against: (+ (get votes-against proposal-data) u1)
      }))
    )
    (ok true)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let
    (
      (proposal-data (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
    )
    (asserts! (> (get votes-for proposal-data) (get votes-against proposal-data)) ERR_NOT_AUTHORIZED)
    (map-set proposals proposal-id (merge proposal-data {status: "Executed"}))
    (ok true)
  )
)

(define-public (update-reputation (agent-id uint) (new-score uint))
  (let
    (
      (agent-data (unwrap! (map-get? ai-agents agent-id) ERR_AGENT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set ai-agents agent-id (merge agent-data {reputation-score: new-score}))
    (ok true)
  )
)

(define-read-only (verify-agent-signature 
  (agent-id uint)
  (message (buff 32))
  (signature (buff 64))
)
  (let
    (
      (agent-data (unwrap! (map-get? ai-agents agent-id) ERR_AGENT_NOT_FOUND))
    )
    (ok (secp256r1-verify message signature (get public-key agent-data)))
  )
)

(define-read-only (get-time)
  stacks-block-time
)
