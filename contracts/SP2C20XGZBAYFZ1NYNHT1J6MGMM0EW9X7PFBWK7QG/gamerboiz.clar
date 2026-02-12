
;; title: gamerboiz NFT Contract
;; version: 1.0
;; summary: A non-fungible token contract for gamerboiz NFTs
;; description: This contract implements a non-fungible token with marketplace functionality, royalties, and minting capabilities.

;; traits
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)
;; Note: Commission payment is handled internally in this contract

;; token definitions
(define-non-fungible-token gamerboiz uint)

;; constants
(define-constant DEPLOYER tx-sender)
(define-constant COMM u500) ;; 5% commission
(define-constant COMM-ADDR 'SP1ZG0Z8ZMB9DX29YGKZZFD9VEHA05C5Q2F7GNH5P)

;; error codes
(define-constant ERR-MINT-DISABLED u100)
(define-constant ERR-NOT-ENOUGH-PASSES u101)
(define-constant ERR-SALE-DISABLED u102)
(define-constant ERR-CONTRACT-INITIALIZED u103)
(define-constant ERR-NOT-AUTHORIZED u104)
(define-constant ERR-INVALID-USER u105)
(define-constant ERR-LISTING u106)
(define-constant ERR-WRONG-COMMISSION u107)
(define-constant ERR-NOT-FOUND u108)
(define-constant ERR-PAUSED u109)
(define-constant ERR-MINT-LIMIT u110)
(define-constant ERR-METADATA-FROZEN u111)
(define-constant ERR-AIRDROP-CALLED u112)
(define-constant ERR-NO-MORE-MINTS u113)
(define-constant ERR-INVALID-PERCENTAGE u114)
(define-constant ERR-KILL-SWITCH u115)
(define-constant ERR-MAX-SPLITS u116)

;; Split payment iteration helper (max 10 splits)
(define-constant SPLIT-INDEXES (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9))

;; data vars
(define-data-var mint-limit uint u5)
(define-data-var last-id uint u1)
(define-data-var total-price uint u1000000)
(define-data-var artist-address principal 'SP2C20XGZBAYFZ1NYNHT1J6MGMM0EW9X7PFBWK7QG)
(define-data-var ipfs-root (string-ascii 80) "ipfs://ipfs/bafkreicijw7oxiv6xubhsr3iat6dfmekgo3vbm7j62drprbw4crt3x4bie/")
(define-data-var mint-paused bool false)
(define-data-var premint-enabled bool false)
(define-data-var sale-enabled bool false)
(define-data-var metadata-frozen bool false)
(define-data-var airdrop-called bool false)
(define-data-var mint-cap uint u1)
(define-data-var kill-switch bool false)
(define-data-var license-uri (string-ascii 80) "https://creativecommons.org/licenses/by/4.0/")
(define-data-var license-name (string-ascii 40) "CC-BY-ATTRIBUTION")
(define-data-var royalty-percent uint u500)

;; data maps
(define-map mints-per-user principal uint)
(define-map mint-passes principal uint)
(define-map token-count principal uint)
;; Market listings - commission is handled internally using COMM and COMM-ADDR
(define-map market uint {price: uint, royalty: uint})

;; Split payment system - stores payees with percentage in basis points (5000 = 50%)
(define-map split-payees uint {payee: principal, percentage: uint})
(define-data-var split-count uint u0)

;; private functions

;; Process single split payment - FIFO order
;; Each split percentage is calculated from original total, not remaining
;; If remaining < calculated amount, payee gets nothing (FIFO cutoff)
(define-private (process-split (index uint) (state {total: uint, remaining: uint}))
  (if (and (< index (var-get split-count)) (> (get remaining state) u0))
    (match (map-get? split-payees index)
      split-data
        (let ((amount (/ (* (get total state) (get percentage split-data)) u10000)))
          (if (and (> amount u0) (>= (get remaining state) amount))
            (match (stx-transfer? amount tx-sender (get payee split-data))
              ok-val {total: (get total state), remaining: (- (get remaining state) amount)}
              err-val state)
            state))
      state)
    state))

;; Distribute to all splits, return remaining for artist-address
(define-private (distribute-splits (total uint))
  (let ((final-state (fold process-split SPLIT-INDEXES {total: total, remaining: total})))
    (get remaining final-state)))

(define-private (mint-many-iter (ignore bool) (next-id uint))
  (if (<= next-id (var-get mint-limit))
    (begin
      (unwrap! (nft-mint? gamerboiz next-id tx-sender) next-id)
      (+ next-id u1)    
    )
    next-id))

(define-private (mint (orders (list 25 bool)))
  (let 
    (
      (last-nft-id (var-get last-id))
      (enabled (asserts! (<= last-nft-id (var-get mint-limit)) (err ERR-MINT-DISABLED)))
      (art-addr (var-get artist-address))
      (id-reached (fold mint-many-iter orders last-nft-id))
      (price (* (var-get total-price) (- id-reached last-nft-id)))
      (total-commission (/ (* price COMM) u10000))
      (current-balance (get-balance tx-sender))
      (total-artist (- price total-commission))
      (capped (> (var-get mint-cap) u0))
      (user-mints (get-mints tx-sender))
    )
    (asserts! (not (var-get kill-switch)) (err ERR-KILL-SWITCH))
    (asserts! (or (is-eq false (var-get mint-paused)) (is-eq tx-sender DEPLOYER)) (err ERR-PAUSED))
    (asserts! (or (not capped) (is-eq tx-sender DEPLOYER) (is-eq tx-sender art-addr) (>= (var-get mint-cap) (+ (len orders) user-mints))) (err ERR-NO-MORE-MINTS))
    (map-set mints-per-user tx-sender (+ (len orders) user-mints))
    (if (or (is-eq tx-sender art-addr) (is-eq tx-sender DEPLOYER) (is-eq (var-get total-price) u0000000))
      (begin
        (var-set last-id id-reached)
        (map-set token-count tx-sender (+ current-balance (- id-reached last-nft-id)))
        (print {notification: "boom-mint", payload: {id: id-reached, price: price, artist: art-addr}})
      )
      (let 
        (
          ;; Distribute to splits first (FIFO), get remaining for artist-address
          (remaining-after-splits (distribute-splits total-artist))
        )
        (var-set last-id id-reached)
        (map-set token-count tx-sender (+ current-balance (- id-reached last-nft-id)))
        ;; Pay commission to platform
        (try! (stx-transfer? total-commission tx-sender COMM-ADDR))
        ;; Pay remaining balance to artist-address (default payee)
        (if (> remaining-after-splits u0)
          (try! (stx-transfer? remaining-after-splits tx-sender art-addr))
          true
        )
        (print {notification: "boom-mint", payload: {id: id-reached, price: price, artist: art-addr, splits-paid: (- total-artist remaining-after-splits)}})
      )
    )
    (ok id-reached)))

(define-private (is-owner (token-id uint) (user principal))
    (is-eq user (unwrap! (nft-get-owner? gamerboiz token-id) false)))

(define-private (trnsfr (id uint) (sender principal) (recipient principal))
  (match (nft-transfer? gamerboiz id sender recipient)
    success
      (let
        ((sender-balance (get-balance sender))
        (recipient-balance (get-balance recipient)))
          (map-set token-count
            sender
            (- sender-balance u1))
          (map-set token-count
            recipient
            (+ recipient-balance u1))
          (ok success))
    error (err error)))

(define-private (is-sender-owner (id uint))
  (let ((owner (unwrap! (nft-get-owner? gamerboiz id) false)))
    (or (is-eq tx-sender owner) (is-eq contract-caller owner))))

(define-private (pay-royalty (price uint) (royalty uint))
  (let (
    (royalty-amount (/ (* price royalty) u10000))
  )
  (if (and (> royalty-amount u0) (not (is-eq tx-sender (var-get artist-address))))
    (try! (stx-transfer? royalty-amount tx-sender (var-get artist-address)))
    (print false)
  )
  (ok true)))

;; public functions

;; Claim 1 NFTs
(define-public (claim-1)
  (mint (list true)))

(define-public (toggle-kill-switch)
  (begin
    (asserts! (is-eq tx-sender DEPLOYER) (err ERR-NOT-AUTHORIZED))
    (ok (var-set kill-switch (not (var-get kill-switch))))))

(define-public (set-artist-address (address principal))
  (begin
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-INVALID-USER))
    (ok (var-set artist-address address))))

(define-public (set-price (price uint))
  (begin
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-INVALID-USER))
    (ok (var-set total-price price))))

(define-public (toggle-pause)
  (begin
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-INVALID-USER))
    (ok (var-set mint-paused (not (var-get mint-paused))))))

(define-public (set-mint-limit (limit uint))
  (begin
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-INVALID-USER))
    (asserts! (< limit (var-get mint-limit)) (err ERR-MINT-LIMIT))
    (ok (var-set mint-limit limit))))

(define-public (burn (token-id uint))
  (begin 
    (asserts! (is-owner token-id tx-sender) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-none (map-get? market token-id)) (err ERR-LISTING))
    (nft-burn? gamerboiz token-id tx-sender)))

(define-public (set-base-uri (new-base-uri (string-ascii 80)))
  (begin
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (var-get metadata-frozen)) (err ERR-METADATA-FROZEN))
    (print { notification: "token-metadata-update", payload: { token-class: "nft", contract-id: (as-contract tx-sender) }})
    (var-set ipfs-root new-base-uri)
    (ok true)))

(define-public (freeze-metadata)
  (begin
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-NOT-AUTHORIZED))
    (var-set metadata-frozen true)
    (ok true)))

(define-public (transfer (id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-none (map-get? market id)) (err ERR-LISTING))
    (trnsfr id sender recipient)))

;; List NFT for sale on marketplace
;; Commission (5%) is handled internally using COMM-ADDR
(define-public (list-in-ustx (id uint) (price uint))
  (let ((listing {price: price, royalty: (var-get royalty-percent)}))
    (asserts! (is-sender-owner id) (err ERR-NOT-AUTHORIZED))
    (map-set market id listing)
    (print (merge listing {a: "list-in-ustx", id: id}))
    (ok true)))

(define-public (unlist-in-ustx (id uint))
  (begin
    (asserts! (is-sender-owner id) (err ERR-NOT-AUTHORIZED))
    (map-delete market id)
    (print {a: "unlist-in-ustx", id: id})
    (ok true)))

;; Buy listed NFT from marketplace
;; Handles payment distribution: seller, royalty (to artist), commission (to platform)
(define-public (buy-in-ustx (id uint))
  (let (
      (owner (unwrap! (nft-get-owner? gamerboiz id) (err ERR-NOT-FOUND)))
      (listing (unwrap! (map-get? market id) (err ERR-LISTING)))
      (price (get price listing))
      (royalty (get royalty listing))
      (commission-amount (/ (* price COMM) u10000))
    )
    ;; Transfer price to seller
    (try! (stx-transfer? price tx-sender owner))
    ;; Pay royalty to artist (if applicable)
    (try! (pay-royalty price royalty))
    ;; Pay marketplace commission to platform
    (if (> commission-amount u0)
      (try! (stx-transfer? commission-amount tx-sender COMM-ADDR))
      true
    )
    ;; Transfer NFT to buyer
    (try! (trnsfr id owner tx-sender))
    ;; Clear listing
    (map-delete market id)
    (print {a: "buy-in-ustx", id: id, price: price, commission: commission-amount})
    (ok true)))

(define-public (set-royalty-percent (royalty uint))
  (begin
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-INVALID-USER))
    (asserts! (and (>= royalty u0) (<= royalty u1000)) (err ERR-INVALID-PERCENTAGE))
    (ok (var-set royalty-percent royalty))))

(define-public (set-license-uri (uri (string-ascii 80)))
  (begin
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-NOT-AUTHORIZED))
    (ok (var-set license-uri uri))))

(define-public (set-license-name (name (string-ascii 40)))
  (begin
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-NOT-AUTHORIZED))
    (ok (var-set license-name name))))

;; ============================================
;; SPLIT PAYMENT ADMIN FUNCTIONS
;; ============================================

;; Add a split payee - appends to end (FIFO order)
;; percentage is in basis points: 5000 = 50%, 2500 = 25%, etc.
;; NOTE: No validation that total percentages <= 100%
;; Payments go FIFO - if splits exceed 100%, later payees won't receive payment
(define-public (add-split-payee (payee principal) (percentage uint))
  (let ((new-index (var-get split-count)))
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-NOT-AUTHORIZED))
    (asserts! (< new-index u10) (err ERR-MAX-SPLITS))
    (map-set split-payees new-index {payee: payee, percentage: percentage})
    (var-set split-count (+ new-index u1))
    (print {notification: "split-payee-added", payload: {index: new-index, payee: payee, percentage: percentage}})
    (ok new-index)))

;; Remove a specific split payee by index
;; Shifts remaining payees down to maintain FIFO order
(define-public (remove-split-payee (index uint))
  (let ((current-count (var-get split-count)))
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-NOT-AUTHORIZED))
    (asserts! (< index current-count) (err ERR-NOT-FOUND))
    ;; Shift all payees after this index down by 1
    (shift-payees-down index)
    (var-set split-count (- current-count u1))
    (print {notification: "split-payee-removed", payload: {index: index}})
    (ok true)))

;; Helper to shift payees down after removal
(define-private (shift-payees-down (start-index uint))
  (begin
    (and (< start-index u9) (is-some (map-get? split-payees (+ start-index u1)))
      (map-set split-payees start-index (unwrap-panic (map-get? split-payees (+ start-index u1)))))
    (and (< (+ start-index u1) u9) (is-some (map-get? split-payees (+ start-index u2)))
      (map-set split-payees (+ start-index u1) (unwrap-panic (map-get? split-payees (+ start-index u2)))))
    (and (< (+ start-index u2) u9) (is-some (map-get? split-payees (+ start-index u3)))
      (map-set split-payees (+ start-index u2) (unwrap-panic (map-get? split-payees (+ start-index u3)))))
    (and (< (+ start-index u3) u9) (is-some (map-get? split-payees (+ start-index u4)))
      (map-set split-payees (+ start-index u3) (unwrap-panic (map-get? split-payees (+ start-index u4)))))
    (and (< (+ start-index u4) u9) (is-some (map-get? split-payees (+ start-index u5)))
      (map-set split-payees (+ start-index u4) (unwrap-panic (map-get? split-payees (+ start-index u5)))))
    (and (< (+ start-index u5) u9) (is-some (map-get? split-payees (+ start-index u6)))
      (map-set split-payees (+ start-index u5) (unwrap-panic (map-get? split-payees (+ start-index u6)))))
    (and (< (+ start-index u6) u9) (is-some (map-get? split-payees (+ start-index u7)))
      (map-set split-payees (+ start-index u6) (unwrap-panic (map-get? split-payees (+ start-index u7)))))
    (and (< (+ start-index u7) u9) (is-some (map-get? split-payees (+ start-index u8)))
      (map-set split-payees (+ start-index u7) (unwrap-panic (map-get? split-payees (+ start-index u8)))))
    (and (< (+ start-index u8) u9) (is-some (map-get? split-payees (+ start-index u9)))
      (map-set split-payees (+ start-index u8) (unwrap-panic (map-get? split-payees (+ start-index u9)))))
    ;; Delete the last slot
    (map-delete split-payees (- (var-get split-count) u1))
    true))

;; Clear all split payees
(define-public (clear-split-payees)
  (begin
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-NOT-AUTHORIZED))
    (var-set split-count u0)
    (print {notification: "split-payees-cleared"})
    (ok true)))

;; Update an existing split payee's percentage
(define-public (update-split-percentage (index uint) (new-percentage uint))
  (let ((current-count (var-get split-count)))
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-NOT-AUTHORIZED))
    (asserts! (< index current-count) (err ERR-NOT-FOUND))
    (match (map-get? split-payees index)
      existing-data
        (begin
          (map-set split-payees index {payee: (get payee existing-data), percentage: new-percentage})
          (print {notification: "split-percentage-updated", payload: {index: index, new-percentage: new-percentage}})
          (ok true))
      (err ERR-NOT-FOUND))))

;; read only functions
(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? gamerboiz token-id)))

(define-read-only (get-last-token-id)
  (ok (- (var-get last-id) u1)))

(define-read-only (get-token-uri (token-id uint))
  (ok (some (concat (concat (var-get ipfs-root) "{id}") ".json"))))

(define-read-only (get-paused)
  (ok (var-get mint-paused)))

(define-read-only (get-price)
  (ok (var-get total-price)))

(define-read-only (get-artist-address)
  (ok (var-get artist-address)))

(define-read-only (get-mints (caller principal))
  (default-to u0 (map-get? mints-per-user caller)))

(define-read-only (get-mint-limit)
  (ok (var-get mint-limit)))

(define-read-only (get-license-uri)
  (ok (var-get license-uri)))

(define-read-only (get-license-name)
  (ok (var-get license-name)))

(define-read-only (get-listing-in-ustx (id uint))
  (map-get? market id))

(define-read-only (get-balance (account principal))
  (default-to u0
    (map-get? token-count account)))

(define-read-only (get-royalty-percent)
  (ok (var-get royalty-percent)))

;; Split payment read-only functions
(define-read-only (get-split-payee (index uint))
  (map-get? split-payees index))

(define-read-only (get-split-count)
  (ok (var-get split-count)))

;; Get all split payees as a list of tuples (for easier frontend consumption)
(define-read-only (get-all-splits)
  (ok {
    count: (var-get split-count),
    split-0: (map-get? split-payees u0),
    split-1: (map-get? split-payees u1),
    split-2: (map-get? split-payees u2),
    split-3: (map-get? split-payees u3),
    split-4: (map-get? split-payees u4),
    split-5: (map-get? split-payees u5),
    split-6: (map-get? split-payees u6),
    split-7: (map-get? split-payees u7),
    split-8: (map-get? split-payees u8),
    split-9: (map-get? split-payees u9)
  }))



;; Airdrop
(define-public (admin-airdrop)
  (let
    (
      (last-nft-id (var-get last-id))
    )
    (begin
      (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-NOT-AUTHORIZED))
      (asserts! (is-eq false (var-get airdrop-called)) (err ERR-AIRDROP-CALLED))
      (try! (nft-mint? gamerboiz (+ last-nft-id u0) 'SP27ENRYMEGM9K6TVR7A8JEDTFXN5EA22KPJHVPE1))
      (map-set token-count 'SP27ENRYMEGM9K6TVR7A8JEDTFXN5EA22KPJHVPE1 (+ (get-balance 'SP27ENRYMEGM9K6TVR7A8JEDTFXN5EA22KPJHVPE1) u1))
      (try! (nft-mint? gamerboiz (+ last-nft-id u1) 'SP3N3B77Y7Q2KDSQS5A630AN2HGZ96P36ZJAYK1MY))
      (map-set token-count 'SP3N3B77Y7Q2KDSQS5A630AN2HGZ96P36ZJAYK1MY (+ (get-balance 'SP3N3B77Y7Q2KDSQS5A630AN2HGZ96P36ZJAYK1MY) u1))

      (var-set last-id (+ last-nft-id u2))
      (var-set airdrop-called true)
      (ok true))))

