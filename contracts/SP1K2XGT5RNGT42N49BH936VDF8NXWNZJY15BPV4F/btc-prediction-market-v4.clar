;; Bitcoin-Anchored Prediction Market
;; A decentralized prediction market that settles based on Bitcoin block data
;; Uses Clarity 4 features: get-burn-block-info?, tenure-height, bitwise operations

;; Import SIP-010 trait for token interactions
(use-trait sip-010-trait-v4 .sip-010-trait-v4.sip-010-trait-v4)

;; =============================================
;; CONSTANTS
;; =============================================

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-MARKET-NOT-FOUND (err u1001))
(define-constant ERR-MARKET-CLOSED (err u1002))
(define-constant ERR-MARKET-NOT-SETTLED (err u1003))
(define-constant ERR-MARKET-ALREADY-SETTLED (err u1004))
(define-constant ERR-INVALID-OUTCOME (err u1005))
(define-constant ERR-INSUFFICIENT-FUNDS (err u1006))
(define-constant ERR-BET-TOO-SMALL (err u1007))
(define-constant ERR-ALREADY-CLAIMED (err u1008))
(define-constant ERR-NO-POSITION (err u1009))
(define-constant ERR-BURN-BLOCK-NOT-AVAILABLE (err u1010))
(define-constant ERR-INVALID-MARKET-PARAMS (err u1011))
(define-constant ERR-MARKET-NOT-READY-TO-SETTLE (err u1012))
(define-constant ERR-TRANSFER-FAILED (err u1013))
(define-constant ERR-CASHOUT-NOT-ALLOWED (err u1014))
(define-constant ERR-CHALLENGE-WINDOW (err u1015))
(define-constant ERR-ORACLE-NOT-AUTHORIZED (err u1016))
(define-constant ERR-ORACLE-NOT-SET (err u1017))
(define-constant ERR-ORACLE-ALREADY-SETTLED (err u1018))
(define-constant ERR-MARKET-EXPIRED (err u1019))
(define-constant ERR-MAX-POOL-EXCEEDED (err u1020))

;; Platform constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MARKET-CREATION-FEE u5000000) ;; 5 STX in microSTX
(define-constant PLATFORM-FEE-PERCENT u200) ;; 2% (basis points)
(define-constant CREATOR-FEE-PERCENT u100) ;; 1% (basis points)
(define-constant LP-FEE-PERCENT u100) ;; 1% (basis points)
(define-constant LP-FEE-PRECISION u1000000)
(define-constant MIN-BET-AMOUNT u1000000) ;; 1 STX minimum bet
(define-constant BLOCKS-BEFORE-SETTLEMENT u6) ;; Wait 6 Bitcoin blocks for finality
(define-constant CHALLENGE-WINDOW-BLOCKS u6) ;; Dispute window after settlement
(define-constant MIN-MARKET-LIQUIDITY u5000000) ;; 5 STX minimum total pool
(define-constant MAX-MARKET-LIQUIDITY u100000000000) ;; 100k STX hard ceiling

;; Outcome bit flags (Clarity 4 bitwise operations)
(define-constant OUTCOME-A u1) ;; 0001
(define-constant OUTCOME-B u2) ;; 0010
(define-constant OUTCOME-C u4) ;; 0100
(define-constant OUTCOME-D u8) ;; 1000

;; =============================================
;; DATA VARIABLES
;; =============================================

(define-data-var market-nonce uint u0)
(define-data-var total-fees-collected uint u0)
(define-data-var platform-paused bool false)
(define-data-var oracle-admin principal tx-sender)

;; =============================================
;; DATA MAPS
;; =============================================

;; Main market storage
(define-map markets
  uint ;; market-id
  {
    creator: principal,
    title: (string-utf8 256),
    description: (string-utf8 1024),
    category: (string-ascii 32),
    settlement-burn-height: uint, ;; Bitcoin block height for settlement
    settlement-type: (string-ascii 32), ;; "hash-even-odd", "hash-range", "oracle"
    oracle: (optional principal),
    oracle-outcome: (optional uint),
    max-pool: uint,
    possible-outcomes: uint, ;; Bitwise packed outcomes (e.g., u3 = OUTCOME-A | OUTCOME-B)
    total-pool: uint,
    outcome-a-pool: uint,
    outcome-b-pool: uint,
    outcome-c-pool: uint,
    outcome-d-pool: uint,
    winning-outcome: (optional uint),
    settled: bool,
    expired: bool,
    expired-at-burn-height: (optional uint),
    settled-at-burn-height: (optional uint),
    settlement-block-hash: (optional (buff 32)),
    created-at-burn-height: uint,
    created-at-stacks-height: uint,
  }
)

;; User positions in markets
(define-map user-positions
  {
    market-id: uint,
    user: principal,
  }
  {
    outcome-a-amount: uint,
    outcome-b-amount: uint,
    outcome-c-amount: uint,
    outcome-d-amount: uint,
    total-invested: uint,
    claimed: bool,
  }
)

;; User stats (using bitwise flags for achievements)
(define-map user-stats
  principal
  {
    markets-created: uint,
    total-bets-placed: uint,
    total-winnings: uint,
    total-losses: uint,
    achievements: uint, ;; Bitwise packed achievement flags
  }
)

;; Market participants list
(define-map market-participants
  uint ;; market-id
  (list 500 principal)
)

;; Creator fee balances per market
(define-map creator-fees
  uint ;; market-id
  uint ;; accrued fees (microSTX)
)

;; Liquidity provider state per market
(define-map lp-state
  uint ;; market-id
  {
    total-liquidity: uint,
    acc-fee-per-liquidity: uint,
  }
)

;; Liquidity provider positions
(define-map lp-positions
  {
    market-id: uint,
    user: principal,
  }
  {
    liquidity: uint,
    reward-debt: uint,
  }
)

;; =============================================
;; CLARITY 4 HELPER FUNCTIONS
;; =============================================

;; Get current Bitcoin block height (Clarity 4: tenure-height)
(define-read-only (get-current-burn-height)
  tenure-height
)

;; Get Bitcoin block hash for verification (Clarity 4: get-burn-block-info?)
(define-read-only (get-burn-block-hash (burn-height uint))
  (get-burn-block-info? header-hash burn-height)
)

;; Get user's STX account info (Clarity 4: stx-account)
(define-read-only (get-user-stx-info (user principal))
  (stx-account user)
)

;; Check if user has locked STX (premium user feature)
(define-read-only (is-premium-user (user principal))
  (let ((account (stx-account user)))
    (>= (get locked account) u100000000)
    ;; 100+ STX locked = premium
  )
)

;; Expire a market if settlement height passed without enough liquidity
(define-public (expire-market (market-id uint))
  (let (
      (market (unwrap! (map-get? markets market-id) ERR-MARKET-NOT-FOUND))
      (current-burn-height tenure-height)
    )
    (asserts! (not (get settled market)) ERR-MARKET-ALREADY-SETTLED)
    (asserts! (not (get expired market)) ERR-MARKET-EXPIRED)
    (asserts! (>= current-burn-height (get settlement-burn-height market))
      ERR-MARKET-NOT-READY-TO-SETTLE
    )
    (asserts! (< (get total-pool market) MIN-MARKET-LIQUIDITY) ERR-MARKET-EXPIRED)
    (map-set markets market-id
      (merge market {
        settled: true,
        expired: true,
        expired-at-burn-height: (some current-burn-height),
        settled-at-burn-height: none,
        winning-outcome: none,
      })
    )
    (ok true)
  )
)

;; Extract specific byte from hash using slice (Clarity 4: slice?)
(define-read-only (get-hash-byte
    (hash (buff 32))
    (index uint)
  )
  (slice? hash index (+ index u1))
)

;; Convert outcome to string for display (Clarity 4: int-to-ascii)
(define-read-only (outcome-to-string (outcome uint))
  (if (is-eq outcome OUTCOME-A)
    "A"
    (if (is-eq outcome OUTCOME-B)
      "B"
      (if (is-eq outcome OUTCOME-C)
        "C"
        (if (is-eq outcome OUTCOME-D)
          "D"
          "?"
        )
      )
    )
  )
)

;; =============================================
;; BITWISE OPERATION HELPERS (Clarity 4)
;; =============================================

;; Check if an outcome is enabled in the packed outcomes
(define-read-only (is-outcome-enabled
    (packed-outcomes uint)
    (outcome uint)
  )
  (> (bit-and packed-outcomes outcome) u0)
)

;; Pack multiple outcomes into single value
(define-read-only (pack-outcomes
    (a bool)
    (b bool)
    (c bool)
    (d bool)
  )
  (bit-or (bit-or (if a
    OUTCOME-A
    u0
  ) (if b
    OUTCOME-B
    u0
  ))
    (bit-or (if c
      OUTCOME-C
      u0
    )
      (if d
        OUTCOME-D
        u0
      ))
  )
)

;; Count enabled outcomes
(define-read-only (count-enabled-outcomes (packed uint))
  (+
    (+ (if (is-outcome-enabled packed OUTCOME-A)
      u1
      u0
    )
      (if (is-outcome-enabled packed OUTCOME-B)
        u1
        u0
      ))
    (+ (if (is-outcome-enabled packed OUTCOME-C)
      u1
      u0
    )
      (if (is-outcome-enabled packed OUTCOME-D)
        u1
        u0
      ))
  )
)

;; Determine winning outcome from Bitcoin block hash
;; Uses first byte of hash to determine outcome
(define-read-only (determine-outcome-from-hash
    (block-hash (buff 32))
    (num-outcomes uint)
  )
  (let (
      ;; Get first byte of hash using element-at and convert to uint
      (first-byte-opt (element-at? block-hash u0))
      (first-byte (match first-byte-opt
        byte (buff-to-uint-be byte)
        u0
      ))
      (outcome-index (mod first-byte num-outcomes))
    )
    ;; Map index to outcome flag
    (if (is-eq outcome-index u0)
      OUTCOME-A
      (if (is-eq outcome-index u1)
        OUTCOME-B
        (if (is-eq outcome-index u2)
          OUTCOME-C
          OUTCOME-D
        )
      )
    )
  )
)

;; Check if hash is "even" (last byte is even number)
(define-read-only (is-hash-even (block-hash (buff 32)))
  (let (
      (last-byte-opt (element-at? block-hash u31))
      (last-byte (match last-byte-opt
        byte (buff-to-uint-be byte)
        u0
      ))
    )
    (is-eq (mod last-byte u2) u0)
  )
)

;; =============================================
;; PUBLIC FUNCTIONS - MARKET CREATION
;; =============================================

;; Create a new binary prediction market (2 outcomes)
(define-public (create-binary-market
    (title (string-utf8 256))
    (description (string-utf8 1024))
    (category (string-ascii 32))
    (oracle (optional principal))
    (max-pool uint)
    (settlement-burn-height uint)
  )
  (let (
      (market-id (var-get market-nonce))
      (current-burn-height tenure-height)
    )
    ;; Validate parameters
    (asserts!
      (> settlement-burn-height (+ current-burn-height BLOCKS-BEFORE-SETTLEMENT))
      ERR-INVALID-MARKET-PARAMS
    )
    (asserts! (>= max-pool MIN-MARKET-LIQUIDITY) ERR-INVALID-MARKET-PARAMS)
    (asserts! (<= max-pool MAX-MARKET-LIQUIDITY) ERR-INVALID-MARKET-PARAMS)

    ;; Charge market creation fee
    (try! (stx-transfer? MARKET-CREATION-FEE tx-sender CONTRACT-OWNER))

    ;; Create market
    (map-set markets market-id {
      creator: tx-sender,
      title: title,
      description: description,
      category: category,
      settlement-burn-height: settlement-burn-height,
      settlement-type: (if (is-some oracle)
        "oracle"
        "hash-even-odd"
      ),
      oracle: oracle,
      oracle-outcome: none,
      max-pool: max-pool,
      possible-outcomes: (pack-outcomes true true false false), ;; Only A and B
      total-pool: u0,
      outcome-a-pool: u0,
      outcome-b-pool: u0,
      outcome-c-pool: u0,
      outcome-d-pool: u0,
      winning-outcome: none,
      settled: false,
      expired: false,
      expired-at-burn-height: none,
      settled-at-burn-height: none,
      settlement-block-hash: none,
      created-at-burn-height: current-burn-height,
      created-at-stacks-height: stacks-block-height,
    })

    ;; Initialize participants list
    (map-set market-participants market-id (list))
    (map-set creator-fees market-id u0)
    (map-set lp-state market-id {
      total-liquidity: u0,
      acc-fee-per-liquidity: u0,
    })

    ;; Update user stats
    (update-user-markets-created tx-sender)

    ;; Increment nonce
    (var-set market-nonce (+ market-id u1))
    (var-set total-fees-collected
      (+ (var-get total-fees-collected) MARKET-CREATION-FEE)
    )

    (ok market-id)
  )
)

;; Create a multi-outcome market (up to 4 outcomes)
(define-public (create-multi-market
    (title (string-utf8 256))
    (description (string-utf8 1024))
    (category (string-ascii 32))
    (oracle (optional principal))
    (max-pool uint)
    (settlement-burn-height uint)
    (enable-outcome-a bool)
    (enable-outcome-b bool)
    (enable-outcome-c bool)
    (enable-outcome-d bool)
  )
  (let (
      (market-id (var-get market-nonce))
      (current-burn-height tenure-height)
      (packed-outcomes (pack-outcomes enable-outcome-a enable-outcome-b enable-outcome-c
        enable-outcome-d
      ))
    )
    ;; Validate parameters
    (asserts!
      (> settlement-burn-height (+ current-burn-height BLOCKS-BEFORE-SETTLEMENT))
      ERR-INVALID-MARKET-PARAMS
    )
    (asserts! (>= (count-enabled-outcomes packed-outcomes) u2)
      ERR-INVALID-MARKET-PARAMS
    )
    (asserts! (>= max-pool MIN-MARKET-LIQUIDITY) ERR-INVALID-MARKET-PARAMS)
    (asserts! (<= max-pool MAX-MARKET-LIQUIDITY) ERR-INVALID-MARKET-PARAMS)

    ;; Charge market creation fee
    (try! (stx-transfer? MARKET-CREATION-FEE tx-sender CONTRACT-OWNER))

    ;; Create market
    (map-set markets market-id {
      creator: tx-sender,
      title: title,
      description: description,
      category: category,
      settlement-burn-height: settlement-burn-height,
      settlement-type: (if (is-some oracle)
        "oracle"
        "hash-range"
      ),
      oracle: oracle,
      oracle-outcome: none,
      max-pool: max-pool,
      possible-outcomes: packed-outcomes,
      total-pool: u0,
      outcome-a-pool: u0,
      outcome-b-pool: u0,
      outcome-c-pool: u0,
      outcome-d-pool: u0,
      winning-outcome: none,
      settled: false,
      expired: false,
      expired-at-burn-height: none,
      settled-at-burn-height: none,
      settlement-block-hash: none,
      created-at-burn-height: current-burn-height,
      created-at-stacks-height: stacks-block-height,
    })

    ;; Initialize participants list
    (map-set market-participants market-id (list))
    (map-set creator-fees market-id u0)
    (map-set lp-state market-id {
      total-liquidity: u0,
      acc-fee-per-liquidity: u0,
    })

    ;; Update user stats
    (update-user-markets-created tx-sender)

    ;; Increment nonce
    (var-set market-nonce (+ market-id u1))
    (var-set total-fees-collected
      (+ (var-get total-fees-collected) MARKET-CREATION-FEE)
    )

    (ok market-id)
  )
)

;; =============================================
;; PUBLIC FUNCTIONS - BETTING
;; =============================================

;; Place a bet on outcome A
(define-public (bet-outcome-a
    (market-id uint)
    (amount uint)
  )
  (place-bet-internal market-id amount OUTCOME-A)
)

;; Place a bet on outcome B
(define-public (bet-outcome-b
    (market-id uint)
    (amount uint)
  )
  (place-bet-internal market-id amount OUTCOME-B)
)

;; Place a bet on outcome C
(define-public (bet-outcome-c
    (market-id uint)
    (amount uint)
  )
  (place-bet-internal market-id amount OUTCOME-C)
)

;; Place a bet on outcome D
(define-public (bet-outcome-d
    (market-id uint)
    (amount uint)
  )
  (place-bet-internal market-id amount OUTCOME-D)
)

;; Provide liquidity to improve odds
(define-public (add-liquidity
    (market-id uint)
    (amount uint)
  )
  (let (
      (market (unwrap! (map-get? markets market-id) ERR-MARKET-NOT-FOUND))
      (current-burn-height tenure-height)
      (lp (default-to {
        liquidity: u0,
        reward-debt: u0,
      }
        (map-get? lp-positions {
          market-id: market-id,
          user: tx-sender,
        })
      ))
      (state (default-to {
        total-liquidity: u0,
        acc-fee-per-liquidity: u0,
      }
        (map-get? lp-state market-id)
      ))
      (total-pool (get total-pool market))
      (num-outcomes (count-enabled-outcomes (get possible-outcomes market)))
    )
    (asserts! (not (get settled market)) ERR-MARKET-CLOSED)
    (asserts! (< current-burn-height (get settlement-burn-height market))
      ERR-MARKET-CLOSED
    )
    (asserts! (>= amount MIN-BET-AMOUNT) ERR-BET-TOO-SMALL)
    (asserts! (<= (+ (get total-pool market) amount) (get max-pool market))
      ERR-MAX-POOL-EXCEEDED
    )
    (asserts! (>= num-outcomes u2) ERR-INVALID-MARKET-PARAMS)

    ;; Harvest any pending LP fees
    (unwrap! (distribute-lp-fee market-id tx-sender lp state) ERR-TRANSFER-FAILED)

    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

    ;; Allocate liquidity to pools
    (if (is-eq total-pool u0)
      (let (
          (base (/ amount num-outcomes))
          (remainder (- amount (* base num-outcomes)))
          (a-enabled (is-outcome-enabled (get possible-outcomes market) OUTCOME-A))
          (b-enabled (is-outcome-enabled (get possible-outcomes market) OUTCOME-B))
          (c-enabled (is-outcome-enabled (get possible-outcomes market) OUTCOME-C))
          (d-enabled (is-outcome-enabled (get possible-outcomes market) OUTCOME-D))
          (a-add (if a-enabled
            (+ base remainder)
            u0
          ))
          (b-add (if b-enabled
            base
            u0
          ))
          (c-add (if c-enabled
            base
            u0
          ))
          (d-add (if d-enabled
            base
            u0
          ))
        )
        (map-set markets market-id
          (merge market {
            total-pool: (+ total-pool amount),
            outcome-a-pool: (+ (get outcome-a-pool market) a-add),
            outcome-b-pool: (+ (get outcome-b-pool market) b-add),
            outcome-c-pool: (+ (get outcome-c-pool market) c-add),
            outcome-d-pool: (+ (get outcome-d-pool market) d-add),
          })
        )
      )
      (let (
          (pool-a (get outcome-a-pool market))
          (pool-b (get outcome-b-pool market))
          (pool-c (get outcome-c-pool market))
          (pool-d (get outcome-d-pool market))
          (a-add (/ (* pool-a amount) total-pool))
          (b-add (/ (* pool-b amount) total-pool))
          (c-add (/ (* pool-c amount) total-pool))
          (d-add (/ (* pool-d amount) total-pool))
          (sum-add (+ a-add b-add c-add d-add))
          (remainder (- amount sum-add))
          (a-final (+ a-add remainder))
        )
        (map-set markets market-id
          (merge market {
            total-pool: (+ total-pool amount),
            outcome-a-pool: (+ pool-a a-final),
            outcome-b-pool: (+ pool-b b-add),
            outcome-c-pool: (+ pool-c c-add),
            outcome-d-pool: (+ pool-d d-add),
          })
        )
      )
    )

    ;; Update LP position + state
    (map-set lp-positions {
      market-id: market-id,
      user: tx-sender,
    } {
      liquidity: (+ (get liquidity lp) amount),
      reward-debt: (calculate-reward-debt (+ (get liquidity lp) amount)
        (get acc-fee-per-liquidity state)
      ),
    })
    (map-set lp-state market-id
      (merge state { total-liquidity: (+ (get total-liquidity state) amount) })
    )

    (ok {
      market-id: market-id,
      amount: amount,
    })
  )
)

;; Withdraw liquidity before settlement
(define-public (remove-liquidity
    (market-id uint)
    (amount uint)
  )
  (let (
      (market (unwrap! (map-get? markets market-id) ERR-MARKET-NOT-FOUND))
      (current-burn-height tenure-height)
      (lp (unwrap!
        (map-get? lp-positions {
          market-id: market-id,
          user: tx-sender,
        })
        ERR-NO-POSITION
      ))
      (state (default-to {
        total-liquidity: u0,
        acc-fee-per-liquidity: u0,
      }
        (map-get? lp-state market-id)
      ))
      (total-pool (get total-pool market))
    )
    (asserts! (not (get settled market)) ERR-MARKET-CLOSED)
    (asserts! (< current-burn-height (get settlement-burn-height market))
      ERR-MARKET-CLOSED
    )
    (asserts! (> amount u0) ERR-INVALID-MARKET-PARAMS)
    (asserts! (>= (get liquidity lp) amount) ERR-INSUFFICIENT-FUNDS)
    (asserts! (>= total-pool amount) ERR-INSUFFICIENT-FUNDS)

    ;; Harvest any pending LP fees
    (unwrap! (distribute-lp-fee market-id tx-sender lp state) ERR-TRANSFER-FAILED)

    (let (
        (pool-a (get outcome-a-pool market))
        (pool-b (get outcome-b-pool market))
        (pool-c (get outcome-c-pool market))
        (pool-d (get outcome-d-pool market))
        (a-rem (/ (* pool-a amount) total-pool))
        (b-rem (/ (* pool-b amount) total-pool))
        (c-rem (/ (* pool-c amount) total-pool))
        (d-rem (/ (* pool-d amount) total-pool))
        (sum-rem (+ a-rem b-rem c-rem d-rem))
        (remainder (- amount sum-rem))
        (a-final (+ a-rem remainder))
      )
      (map-set markets market-id
        (merge market {
          total-pool: (- total-pool amount),
          outcome-a-pool: (- pool-a a-final),
          outcome-b-pool: (- pool-b b-rem),
          outcome-c-pool: (- pool-c c-rem),
          outcome-d-pool: (- pool-d d-rem),
        })
      )
    )

    (map-set lp-positions {
      market-id: market-id,
      user: tx-sender,
    } {
      liquidity: (- (get liquidity lp) amount),
      reward-debt: (calculate-reward-debt (- (get liquidity lp) amount)
        (get acc-fee-per-liquidity state)
      ),
    })
    (map-set lp-state market-id
      (merge state { total-liquidity: (- (get total-liquidity state) amount) })
    )

    (as-contract (stx-transfer? amount tx-sender contract-caller))
  )
)

;; Cash out a position before settlement based on current pool odds
(define-public (cash-out
    (market-id uint)
    (outcome uint)
    (amount uint)
  )
  (let (
      (market (unwrap! (map-get? markets market-id) ERR-MARKET-NOT-FOUND))
      (current-burn-height tenure-height)
      (position (unwrap!
        (map-get? user-positions {
          market-id: market-id,
          user: tx-sender,
        })
        ERR-NO-POSITION
      ))
      (outcome-pool (get-pool-for-outcome market outcome))
      (user-outcome-amount (get-position-for-outcome position outcome))
      (total-pool (get total-pool market))
    )
    (asserts! (not (get settled market)) ERR-MARKET-CLOSED)
    (asserts! (< current-burn-height (get settlement-burn-height market))
      ERR-MARKET-CLOSED
    )
    (asserts! (is-outcome-enabled (get possible-outcomes market) outcome)
      ERR-INVALID-OUTCOME
    )
    (asserts! (> amount u0) ERR-INVALID-MARKET-PARAMS)
    (asserts! (>= user-outcome-amount amount) ERR-INSUFFICIENT-FUNDS)
    (asserts! (>= outcome-pool amount) ERR-INSUFFICIENT-FUNDS)
    (asserts! (> outcome-pool u0) ERR-CASHOUT-NOT-ALLOWED)

    (let (
        (gross-payout (/ (* amount total-pool) outcome-pool))
        (platform-fee (/ (* gross-payout PLATFORM-FEE-PERCENT) u10000))
        (creator-fee (/ (* gross-payout CREATOR-FEE-PERCENT) u10000))
        (lp-fee (/ (* gross-payout LP-FEE-PERCENT) u10000))
        (net-payout (- gross-payout (+ platform-fee creator-fee lp-fee)))
        (other-total (- total-pool outcome-pool))
        (other-reduction (if (>= gross-payout amount)
          (- gross-payout amount)
          u0
        ))
        (pool-a (get outcome-a-pool market))
        (pool-b (get outcome-b-pool market))
        (pool-c (get outcome-c-pool market))
        (pool-d (get outcome-d-pool market))
        (r-a-base (if (or (is-eq outcome OUTCOME-A) (is-eq other-total u0))
          u0
          (/ (* pool-a other-reduction) other-total)
        ))
        (r-b-base (if (or (is-eq outcome OUTCOME-B) (is-eq other-total u0))
          u0
          (/ (* pool-b other-reduction) other-total)
        ))
        (r-c-base (if (or (is-eq outcome OUTCOME-C) (is-eq other-total u0))
          u0
          (/ (* pool-c other-reduction) other-total)
        ))
        (r-d-base (if (or (is-eq outcome OUTCOME-D) (is-eq other-total u0))
          u0
          (/ (* pool-d other-reduction) other-total)
        ))
        (sum-base (+ r-a-base r-b-base r-c-base r-d-base))
        (remainder (if (>= other-reduction sum-base)
          (- other-reduction sum-base)
          u0
        ))
        (remainder-rec (if (not (is-eq outcome OUTCOME-D))
          OUTCOME-D
          (if (not (is-eq outcome OUTCOME-C))
            OUTCOME-C
            (if (not (is-eq outcome OUTCOME-B))
              OUTCOME-B
              OUTCOME-A
            )
          )
        ))
        (r-a-other (if (and (not (is-eq outcome OUTCOME-A)) (is-eq remainder-rec OUTCOME-A))
          (+ r-a-base remainder)
          r-a-base
        ))
        (r-b-other (if (and (not (is-eq outcome OUTCOME-B)) (is-eq remainder-rec OUTCOME-B))
          (+ r-b-base remainder)
          r-b-base
        ))
        (r-c-other (if (and (not (is-eq outcome OUTCOME-C)) (is-eq remainder-rec OUTCOME-C))
          (+ r-c-base remainder)
          r-c-base
        ))
        (r-d-other (if (and (not (is-eq outcome OUTCOME-D)) (is-eq remainder-rec OUTCOME-D))
          (+ r-d-base remainder)
          r-d-base
        ))
        (r-a (if (is-eq outcome OUTCOME-A)
          amount
          r-a-other
        ))
        (r-b (if (is-eq outcome OUTCOME-B)
          amount
          r-b-other
        ))
        (r-c (if (is-eq outcome OUTCOME-C)
          amount
          r-c-other
        ))
        (r-d (if (is-eq outcome OUTCOME-D)
          amount
          r-d-other
        ))
      )
      (map-set markets market-id
        (merge market {
          total-pool: (- total-pool gross-payout),
          outcome-a-pool: (- pool-a r-a),
          outcome-b-pool: (- pool-b r-b),
          outcome-c-pool: (- pool-c r-c),
          outcome-d-pool: (- pool-d r-d),
        })
      )

      (map-set user-positions {
        market-id: market-id,
        user: tx-sender,
      } {
        outcome-a-amount: (if (is-eq outcome OUTCOME-A)
          (- (get outcome-a-amount position) amount)
          (get outcome-a-amount position)
        ),
        outcome-b-amount: (if (is-eq outcome OUTCOME-B)
          (- (get outcome-b-amount position) amount)
          (get outcome-b-amount position)
        ),
        outcome-c-amount: (if (is-eq outcome OUTCOME-C)
          (- (get outcome-c-amount position) amount)
          (get outcome-c-amount position)
        ),
        outcome-d-amount: (if (is-eq outcome OUTCOME-D)
          (- (get outcome-d-amount position) amount)
          (get outcome-d-amount position)
        ),
        total-invested: (- (get total-invested position) amount),
        claimed: false,
      })

      (var-set total-fees-collected
        (+ (var-get total-fees-collected) platform-fee)
      )
      (map-set creator-fees market-id
        (+ (default-to u0 (map-get? creator-fees market-id)) creator-fee)
      )
      (unwrap! (accrue-lp-fee market-id lp-fee) ERR-TRANSFER-FAILED)

      (if (> net-payout u0)
        (begin
          (try! (as-contract (stx-transfer? net-payout tx-sender contract-caller)))
          (ok {
            market-id: market-id,
            outcome: outcome,
            gross-payout: gross-payout,
            platform-fee: platform-fee,
            creator-fee: creator-fee,
            lp-fee: lp-fee,
            net-payout: net-payout,
          })
        )
        (ok {
          market-id: market-id,
          outcome: outcome,
          gross-payout: gross-payout,
          platform-fee: platform-fee,
          creator-fee: creator-fee,
          lp-fee: lp-fee,
          net-payout: net-payout,
        })
      )
    )
  )
)

;; Internal bet placement logic
(define-private (place-bet-internal
    (market-id uint)
    (amount uint)
    (outcome uint)
  )
  (let (
      (market (unwrap! (map-get? markets market-id) ERR-MARKET-NOT-FOUND))
      (current-burn-height tenure-height)
      (current-position (default-to {
        outcome-a-amount: u0,
        outcome-b-amount: u0,
        outcome-c-amount: u0,
        outcome-d-amount: u0,
        total-invested: u0,
        claimed: false,
      }
        (map-get? user-positions {
          market-id: market-id,
          user: tx-sender,
        })
      ))
    )
    ;; Validate bet
    (asserts! (not (get settled market)) ERR-MARKET-CLOSED)
    (asserts! (< current-burn-height (get settlement-burn-height market))
      ERR-MARKET-CLOSED
    )
    (asserts! (is-outcome-enabled (get possible-outcomes market) outcome)
      ERR-INVALID-OUTCOME
    )
    (asserts! (>= amount MIN-BET-AMOUNT) ERR-BET-TOO-SMALL)
    (asserts! (<= (+ (get total-pool market) amount) (get max-pool market))
      ERR-MAX-POOL-EXCEEDED
    )

    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

    ;; Update market pools
    (map-set markets market-id
      (merge market {
        total-pool: (+ (get total-pool market) amount),
        outcome-a-pool: (if (is-eq outcome OUTCOME-A)
          (+ (get outcome-a-pool market) amount)
          (get outcome-a-pool market)
        ),
        outcome-b-pool: (if (is-eq outcome OUTCOME-B)
          (+ (get outcome-b-pool market) amount)
          (get outcome-b-pool market)
        ),
        outcome-c-pool: (if (is-eq outcome OUTCOME-C)
          (+ (get outcome-c-pool market) amount)
          (get outcome-c-pool market)
        ),
        outcome-d-pool: (if (is-eq outcome OUTCOME-D)
          (+ (get outcome-d-pool market) amount)
          (get outcome-d-pool market)
        ),
      })
    )

    ;; Update user position
    (map-set user-positions {
      market-id: market-id,
      user: tx-sender,
    } {
      outcome-a-amount: (if (is-eq outcome OUTCOME-A)
        (+ (get outcome-a-amount current-position) amount)
        (get outcome-a-amount current-position)
      ),
      outcome-b-amount: (if (is-eq outcome OUTCOME-B)
        (+ (get outcome-b-amount current-position) amount)
        (get outcome-b-amount current-position)
      ),
      outcome-c-amount: (if (is-eq outcome OUTCOME-C)
        (+ (get outcome-c-amount current-position) amount)
        (get outcome-c-amount current-position)
      ),
      outcome-d-amount: (if (is-eq outcome OUTCOME-D)
        (+ (get outcome-d-amount current-position) amount)
        (get outcome-d-amount current-position)
      ),
      total-invested: (+ (get total-invested current-position) amount),
      claimed: false,
    })

    ;; Update user stats
    (update-user-bets-placed tx-sender amount)

    ;; Add to participants list
    (add-participant market-id tx-sender)

    (ok {
      market-id: market-id,
      outcome: outcome,
      amount: amount,
    })
  )
)

;; =============================================
;; PUBLIC FUNCTIONS - SETTLEMENT
;; =============================================

;; Settle market using Bitcoin block hash (anyone can call after settlement height)
(define-public (settle-market (market-id uint))
  (let (
      (market (unwrap! (map-get? markets market-id) ERR-MARKET-NOT-FOUND))
      (settlement-height (get settlement-burn-height market))
      (current-burn-height tenure-height)
      ;; Clarity 4: Get Bitcoin block hash for settlement
      (block-hash (unwrap! (get-burn-block-info? header-hash settlement-height)
        ERR-BURN-BLOCK-NOT-AVAILABLE
      ))
      (num-outcomes (count-enabled-outcomes (get possible-outcomes market)))
      (oracle-outcome (get oracle-outcome market))
      (winning-outcome (if (is-eq (get settlement-type market) "oracle")
        (unwrap! oracle-outcome ERR-ORACLE-NOT-SET)
        (if (is-eq (get settlement-type market) "hash-even-odd")
          (if (is-hash-even block-hash)
            OUTCOME-A
            OUTCOME-B
          )
          (determine-outcome-from-hash block-hash num-outcomes)
        )
      ))
    )
    ;; Validate settlement
    (asserts! (not (get settled market)) ERR-MARKET-ALREADY-SETTLED)
    (asserts! (not (get expired market)) ERR-MARKET-EXPIRED)
    (asserts! (>= (get total-pool market) MIN-MARKET-LIQUIDITY)
      ERR-MARKET-EXPIRED
    )
    (asserts!
      (>= current-burn-height (+ settlement-height BLOCKS-BEFORE-SETTLEMENT))
      ERR-MARKET-NOT-READY-TO-SETTLE
    )

    ;; Update market with settlement info
    (map-set markets market-id
      (merge market {
        settled: true,
        winning-outcome: (some winning-outcome),
        settled-at-burn-height: (some current-burn-height),
        settlement-block-hash: (some block-hash),
      })
    )

    (ok {
      market-id: market-id,
      winning-outcome: winning-outcome,
      block-hash: block-hash,
      settlement-height: settlement-height,
    })
  )
)

;; =============================================
;; PUBLIC FUNCTIONS - CLAIMING WINNINGS
;; =============================================

;; Claim winnings from a settled market
(define-public (claim-winnings (market-id uint))
  (let (
      (market (unwrap! (map-get? markets market-id) ERR-MARKET-NOT-FOUND))
      (position (unwrap!
        (map-get? user-positions {
          market-id: market-id,
          user: tx-sender,
        })
        ERR-NO-POSITION
      ))
      (winning-outcome (unwrap! (get winning-outcome market) ERR-MARKET-NOT-SETTLED))
      (settled-height (unwrap! (get settled-at-burn-height market) ERR-MARKET-NOT-SETTLED))
      (current-burn-height tenure-height)
    )
    ;; Validate claim
    (asserts! (get settled market) ERR-MARKET-NOT-SETTLED)
    (asserts! (not (get expired market)) ERR-MARKET-EXPIRED)
    (asserts! (>= current-burn-height (+ settled-height CHALLENGE-WINDOW-BLOCKS))
      ERR-CHALLENGE-WINDOW
    )
    (asserts! (not (get claimed position)) ERR-ALREADY-CLAIMED)

    (let (
        ;; Calculate user's winning bet amount
        (user-winning-amount (get-position-for-outcome position winning-outcome))
        ;; Get total pool for winning outcome
        (winning-pool (get-pool-for-outcome market winning-outcome))
        ;; Calculate payout
        (total-pool (get total-pool market))
        (gross-payout (if (is-eq winning-pool u0)
          u0
          (/ (* user-winning-amount total-pool) winning-pool)
        ))
        ;; Calculate platform fee (2%)
        (platform-fee (/ (* gross-payout PLATFORM-FEE-PERCENT) u10000))
        ;; Calculate creator fee (1%)
        (creator-fee (/ (* gross-payout CREATOR-FEE-PERCENT) u10000))
        ;; Calculate LP fee (1%)
        (lp-fee (/ (* gross-payout LP-FEE-PERCENT) u10000))
        (net-payout (- gross-payout (+ platform-fee creator-fee lp-fee)))
      )
      ;; Check if user has winning position
      (asserts! (> user-winning-amount u0) ERR-NO-POSITION)

      ;; Mark as claimed
      (map-set user-positions {
        market-id: market-id,
        user: tx-sender,
      }
        (merge position { claimed: true })
      )

      ;; Transfer winnings (minus fee)
      (if (> net-payout u0)
        (begin
          (try! (as-contract (stx-transfer? net-payout tx-sender
            (unwrap! (element-at? (list tx-sender) u0) ERR-TRANSFER-FAILED)
          )))
          (var-set total-fees-collected
            (+ (var-get total-fees-collected) platform-fee)
          )
          (map-set creator-fees market-id
            (+ (default-to u0 (map-get? creator-fees market-id)) creator-fee)
          )
          (unwrap! (accrue-lp-fee market-id lp-fee) ERR-TRANSFER-FAILED)
          ;; Update user stats
          (update-user-winnings tx-sender net-payout)
          (ok {
            market-id: market-id,
            gross-payout: gross-payout,
            platform-fee: platform-fee,
            creator-fee: creator-fee,
            lp-fee: lp-fee,
            net-payout: net-payout,
          })
        )
        (ok {
          market-id: market-id,
          gross-payout: u0,
          platform-fee: u0,
          creator-fee: u0,
          lp-fee: u0,
          net-payout: u0,
        })
      )
    )
  )
)

;; Claim refund for an expired market
(define-public (claim-refund (market-id uint))
  (let (
      (market (unwrap! (map-get? markets market-id) ERR-MARKET-NOT-FOUND))
      (position (unwrap!
        (map-get? user-positions {
          market-id: market-id,
          user: tx-sender,
        })
        ERR-NO-POSITION
      ))
    )
    (asserts! (get expired market) ERR-MARKET-EXPIRED)
    (asserts! (not (get claimed position)) ERR-ALREADY-CLAIMED)
    (let (
        (refund (get total-invested position))
        (pool-a (get outcome-a-pool market))
        (pool-b (get outcome-b-pool market))
        (pool-c (get outcome-c-pool market))
        (pool-d (get outcome-d-pool market))
      )
      (asserts! (> refund u0) ERR-NO-POSITION)

      (map-set markets market-id
        (merge market {
          total-pool: (- (get total-pool market) refund),
          outcome-a-pool: (- pool-a (get outcome-a-amount position)),
          outcome-b-pool: (- pool-b (get outcome-b-amount position)),
          outcome-c-pool: (- pool-c (get outcome-c-amount position)),
          outcome-d-pool: (- pool-d (get outcome-d-amount position)),
        })
      )

      (map-set user-positions {
        market-id: market-id,
        user: tx-sender,
      } {
        outcome-a-amount: u0,
        outcome-b-amount: u0,
        outcome-c-amount: u0,
        outcome-d-amount: u0,
        total-invested: u0,
        claimed: true,
      })

      (as-contract (stx-transfer? refund tx-sender contract-caller))
    )
  )
)

;; =============================================
;; HELPER FUNCTIONS
;; =============================================

(define-private (get-position-for-outcome
    (position {
      outcome-a-amount: uint,
      outcome-b-amount: uint,
      outcome-c-amount: uint,
      outcome-d-amount: uint,
      total-invested: uint,
      claimed: bool,
    })
    (outcome uint)
  )
  (if (is-eq outcome OUTCOME-A)
    (get outcome-a-amount position)
    (if (is-eq outcome OUTCOME-B)
      (get outcome-b-amount position)
      (if (is-eq outcome OUTCOME-C)
        (get outcome-c-amount position)
        (get outcome-d-amount position)
      )
    )
  )
)

(define-private (get-pool-for-outcome
    (market {
      creator: principal,
      title: (string-utf8 256),
      description: (string-utf8 1024),
      category: (string-ascii 32),
      settlement-burn-height: uint,
      settlement-type: (string-ascii 32),
      oracle: (optional principal),
      oracle-outcome: (optional uint),
      max-pool: uint,
      possible-outcomes: uint,
      total-pool: uint,
      outcome-a-pool: uint,
      outcome-b-pool: uint,
      outcome-c-pool: uint,
      outcome-d-pool: uint,
      winning-outcome: (optional uint),
      settled: bool,
      expired: bool,
      expired-at-burn-height: (optional uint),
      settled-at-burn-height: (optional uint),
      settlement-block-hash: (optional (buff 32)),
      created-at-burn-height: uint,
      created-at-stacks-height: uint,
    })
    (outcome uint)
  )
  (if (is-eq outcome OUTCOME-A)
    (get outcome-a-pool market)
    (if (is-eq outcome OUTCOME-B)
      (get outcome-b-pool market)
      (if (is-eq outcome OUTCOME-C)
        (get outcome-c-pool market)
        (get outcome-d-pool market)
      )
    )
  )
)

(define-private (calculate-reward-debt
    (liquidity uint)
    (acc-fee-per-liquidity uint)
  )
  (/ (* liquidity acc-fee-per-liquidity) LP-FEE-PRECISION)
)

(define-private (accrue-lp-fee
    (market-id uint)
    (fee uint)
  )
  (let ((state (default-to {
      total-liquidity: u0,
      acc-fee-per-liquidity: u0,
    }
      (map-get? lp-state market-id)
    )))
    (if (or (is-eq fee u0) (is-eq (get total-liquidity state) u0))
      (begin
        (var-set total-fees-collected (+ (var-get total-fees-collected) fee))
        (ok true)
      )
      (let ((increment (/ (* fee LP-FEE-PRECISION) (get total-liquidity state))))
        (map-set lp-state market-id
          (merge state { acc-fee-per-liquidity: (+ (get acc-fee-per-liquidity state) increment) })
        )
        (ok true)
      )
    )
  )
)

(define-private (distribute-lp-fee
    (market-id uint)
    (user principal)
    (position {
      liquidity: uint,
      reward-debt: uint,
    })
    (state {
      total-liquidity: uint,
      acc-fee-per-liquidity: uint,
    })
  )
  (let ((earned (calculate-reward-debt (get liquidity position)
      (get acc-fee-per-liquidity state)
    )))
    (if (<= earned (get reward-debt position))
      (ok true)
      (let ((pending (- earned (get reward-debt position))))
        (map-set lp-positions {
          market-id: market-id,
          user: user,
        } {
          liquidity: (get liquidity position),
          reward-debt: earned,
        })
        (as-contract (stx-transfer? pending tx-sender contract-caller))
      )
    )
  )
)

(define-private (update-user-markets-created (user principal))
  (let ((stats (default-to {
      markets-created: u0,
      total-bets-placed: u0,
      total-winnings: u0,
      total-losses: u0,
      achievements: u0,
    }
      (map-get? user-stats user)
    )))
    (map-set user-stats user
      (merge stats { markets-created: (+ (get markets-created stats) u1) })
    )
  )
)

(define-private (update-user-bets-placed
    (user principal)
    (amount uint)
  )
  (let ((stats (default-to {
      markets-created: u0,
      total-bets-placed: u0,
      total-winnings: u0,
      total-losses: u0,
      achievements: u0,
    }
      (map-get? user-stats user)
    )))
    (map-set user-stats user
      (merge stats { total-bets-placed: (+ (get total-bets-placed stats) amount) })
    )
  )
)

(define-private (update-user-winnings
    (user principal)
    (amount uint)
  )
  (let ((stats (default-to {
      markets-created: u0,
      total-bets-placed: u0,
      total-winnings: u0,
      total-losses: u0,
      achievements: u0,
    }
      (map-get? user-stats user)
    )))
    (map-set user-stats user
      (merge stats { total-winnings: (+ (get total-winnings stats) amount) })
    )
  )
)

(define-private (add-participant
    (market-id uint)
    (user principal)
  )
  (let ((current-participants (default-to (list) (map-get? market-participants market-id))))
    (if (is-none (index-of? current-participants user))
      (begin
        (map-set market-participants market-id
          (unwrap! (as-max-len? (append current-participants user) u500) false)
        )
        true
      )
      true
    )
  )
)

;; =============================================
;; READ-ONLY FUNCTIONS
;; =============================================

(define-read-only (get-market (market-id uint))
  (map-get? markets market-id)
)

;; Oracle resolves an outcome for oracle markets
(define-public (oracle-settle
    (market-id uint)
    (outcome uint)
  )
  (let (
      (market (unwrap! (map-get? markets market-id) ERR-MARKET-NOT-FOUND))
      (oracle (unwrap! (get oracle market) ERR-ORACLE-NOT-SET))
    )
    (asserts! (is-eq tx-sender oracle) ERR-ORACLE-NOT-AUTHORIZED)
    (asserts! (not (get settled market)) ERR-MARKET-ALREADY-SETTLED)
    (asserts! (is-outcome-enabled (get possible-outcomes market) outcome)
      ERR-INVALID-OUTCOME
    )
    (map-set markets market-id (merge market { oracle-outcome: (some outcome) }))
    (ok outcome)
  )
)

;; Admin can set or rotate oracle for a market before settlement
(define-public (set-market-oracle
    (market-id uint)
    (oracle (optional principal))
  )
  (let (
      (market (unwrap! (map-get? markets market-id) ERR-MARKET-NOT-FOUND))
      (has-c (is-outcome-enabled (get possible-outcomes market) OUTCOME-C))
      (has-d (is-outcome-enabled (get possible-outcomes market) OUTCOME-D))
      (fallback-type (if (or has-c has-d)
        "hash-range"
        "hash-even-odd"
      ))
    )
    (asserts!
      (or (is-eq tx-sender (get creator market)) (is-eq tx-sender (var-get oracle-admin)))
      ERR-NOT-AUTHORIZED
    )
    (asserts! (not (get settled market)) ERR-MARKET-ALREADY-SETTLED)
    (map-set markets market-id
      (merge market {
        oracle: oracle,
        settlement-type: (if (is-some oracle)
          "oracle"
          fallback-type
        ),
      })
    )
    (ok oracle)
  )
)

(define-read-only (get-market-count)
  (var-get market-nonce)
)

(define-read-only (get-user-position
    (market-id uint)
    (user principal)
  )
  (map-get? user-positions {
    market-id: market-id,
    user: user,
  })
)

(define-read-only (get-user-stats (user principal))
  (map-get? user-stats user)
)

(define-read-only (get-market-participants (market-id uint))
  (map-get? market-participants market-id)
)

(define-read-only (get-creator-fees (market-id uint))
  (map-get? creator-fees market-id)
)

(define-read-only (get-lp-state (market-id uint))
  (map-get? lp-state market-id)
)

(define-read-only (get-lp-position
    (market-id uint)
    (user principal)
  )
  (map-get? lp-positions {
    market-id: market-id,
    user: user,
  })
)

(define-read-only (get-total-fees-collected)
  (var-get total-fees-collected)
)

(define-read-only (get-market-odds (market-id uint))
  (let ((market (unwrap! (map-get? markets market-id) none)))
    (some {
      outcome-a-odds: (calculate-odds (get outcome-a-pool market) (get total-pool market)),
      outcome-b-odds: (calculate-odds (get outcome-b-pool market) (get total-pool market)),
      outcome-c-odds: (calculate-odds (get outcome-c-pool market) (get total-pool market)),
      outcome-d-odds: (calculate-odds (get outcome-d-pool market) (get total-pool market)),
      total-pool: (get total-pool market),
    })
  )
)

(define-private (calculate-odds
    (outcome-pool uint)
    (total-pool uint)
  )
  (if (is-eq outcome-pool u0)
    u0
    (/ (* total-pool u10000) outcome-pool)
  )
  ;; Returns odds in basis points (100x multiplier)
)

;; Calculate potential payout for a bet
(define-read-only (calculate-potential-payout
    (market-id uint)
    (outcome uint)
    (bet-amount uint)
  )
  (let (
      (market (unwrap! (map-get? markets market-id) none))
      (outcome-pool (get-pool-for-outcome market outcome))
      (new-pool (+ outcome-pool bet-amount))
      (new-total (+ (get total-pool market) bet-amount))
      (gross-payout (/ (* bet-amount new-total) new-pool))
      (platform-fee (/ (* gross-payout PLATFORM-FEE-PERCENT) u10000))
    )
    (some {
      gross-payout: gross-payout,
      platform-fee: platform-fee,
      net-payout: (- gross-payout platform-fee),
    })
  )
)

;; Get time until settlement (in Bitcoin blocks)
(define-read-only (get-blocks-until-settlement (market-id uint))
  (let (
      (market (unwrap! (map-get? markets market-id) none))
      (current-burn-height tenure-height)
      (settlement-height (get settlement-burn-height market))
    )
    (if (>= current-burn-height settlement-height)
      (some u0)
      (some (- settlement-height current-burn-height))
    )
  )
)

;; Check if market is ready to be settled
(define-read-only (is-market-settleable (market-id uint))
  (let (
      (market (unwrap! (map-get? markets market-id) (some false)))
      (current-burn-height tenure-height)
      (settlement-height (get settlement-burn-height market))
    )
    (some (and
      (not (get settled market))
      (not (get expired market))
      (>= (get total-pool market) MIN-MARKET-LIQUIDITY)
      (>= current-burn-height (+ settlement-height BLOCKS-BEFORE-SETTLEMENT))
    ))
  )
)

;; Check if market winnings are claimable (after challenge window)
(define-read-only (is-claimable (market-id uint))
  (let (
      (market (unwrap! (map-get? markets market-id) (some false)))
      (current-burn-height tenure-height)
      (settled-height (default-to u0 (get settled-at-burn-height market)))
    )
    (some (and
      (get settled market)
      (not (get expired market))
      (>= current-burn-height (+ settled-height CHALLENGE-WINDOW-BLOCKS))
    ))
  )
)

;; Check if market is expired (low liquidity after settlement height)
(define-read-only (is-market-expired (market-id uint))
  (let (
      (market (unwrap! (map-get? markets market-id) (some false)))
      (current-burn-height tenure-height)
      (settlement-height (get settlement-burn-height market))
    )
    (some (or
      (get expired market)
      (and
        (not (get settled market))
        (>= current-burn-height settlement-height)
        (< (get total-pool market) MIN-MARKET-LIQUIDITY)
      )
    ))
  )
)

;; =============================================
;; ADMIN FUNCTIONS
;; =============================================

(define-public (withdraw-fees
    (amount uint)
    (recipient principal)
  )
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (as-contract (stx-transfer? amount tx-sender recipient))
  )
)

;; Creator withdraws accrued fees for a market
(define-public (withdraw-creator-fees
    (market-id uint)
    (amount uint)
    (recipient principal)
  )
  (let (
      (market (unwrap! (map-get? markets market-id) ERR-MARKET-NOT-FOUND))
      (available (default-to u0 (map-get? creator-fees market-id)))
    )
    (asserts! (is-eq tx-sender (get creator market)) ERR-NOT-AUTHORIZED)
    (asserts! (>= available amount) ERR-INSUFFICIENT-FUNDS)
    (map-set creator-fees market-id (- available amount))
    (as-contract (stx-transfer? amount tx-sender recipient))
  )
)

;; LP claims accrued fees for a market
(define-public (claim-lp-fees (market-id uint))
  (let (
      (position (unwrap!
        (map-get? lp-positions {
          market-id: market-id,
          user: tx-sender,
        })
        ERR-NO-POSITION
      ))
      (state (default-to {
        total-liquidity: u0,
        acc-fee-per-liquidity: u0,
      }
        (map-get? lp-state market-id)
      ))
    )
    (begin
      (unwrap! (distribute-lp-fee market-id tx-sender position state)
        ERR-TRANSFER-FAILED
      )
      (ok true)
    )
  )
)

(define-public (set-platform-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set platform-paused paused)
    (ok paused)
  )
)
