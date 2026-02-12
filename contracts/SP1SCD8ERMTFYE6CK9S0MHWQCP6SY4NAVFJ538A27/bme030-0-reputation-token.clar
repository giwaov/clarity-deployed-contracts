;; Title: BME030 Reputation Token
;; Synopsis:
;; Wraps reputation scheme within a non-transferable soulbound semi fungible token (see sip-013).
;; Description:
;; The reputation token is a SIP-013 compliant token that is controlled by active DAO extensions.
;; It facilitates hierarchical reputation and rewards based on engagements across a number of
;; BigMarket DAO features and use cases. 

(impl-trait 'SPDBEG5X8XD50SPM1JJH0E5CTXGDV5NJTKAKKR5V.sip013-semi-fungible-token-trait.sip013-semi-fungible-token-trait)
(impl-trait 'SPDBEG5X8XD50SPM1JJH0E5CTXGDV5NJTKAKKR5V.sip013-transfer-many-trait.sip013-transfer-many-trait)
(impl-trait 'SP3JP0N1ZXGASRJ0F7QAHWFPGTVK9T2XNXDB908Z.extension-trait.extension-trait)

(define-constant err-unauthorised (err u30001))
(define-constant err-already-minted (err u30002))
(define-constant err-soulbound (err u30003))
(define-constant err-insufficient-balance (err u30004))
(define-constant err-zero-amount (err u30005))
(define-constant err-claims-old-epoch (err u30006))
(define-constant err-claims-zero-rep (err u30007))
(define-constant err-claims-zero-total (err u30008))
(define-constant err-invalid-tier (err u30009))
(define-constant err-too-high (err u30010))
(define-constant err-epoch-too-short (err u30011))
(define-constant err-epoch-too-long  (err u30012))

(define-constant max-tier u20)
(define-constant SCALE u1000000)

(define-fungible-token bigr-token)
(define-non-fungible-token bigr-id { token-id: uint, owner: principal })

(define-map balances { token-id: uint, owner: principal } uint)
(define-map supplies uint uint)
(define-map last-claimed-epoch { who: principal } uint)
(define-map tier-weights uint uint)
(define-map join-epoch { who: principal } uint)
(define-map minted-in-epoch { epoch: uint } uint)
(define-map minted-in-epoch-by { epoch: uint, who: principal } uint)
(define-map total-weighted-supply { epoch: uint } uint)
(define-map user-total-rep { who: principal } uint)         ;; running total, lifetime reputation

(define-data-var reward-per-epoch uint u10000000000) ;; 10,000 BIG per epoch (in micro units)
(define-data-var epoch-duration uint u4000) ;; roughly monthly
(define-data-var overall-supply uint u0)
(define-data-var token-name (string-ascii 32) "BigMarket Reputation Token")
(define-data-var token-symbol (string-ascii 10) "BIGR")
(define-data-var launch-height uint u0)
(define-data-var weighted-supply uint u0)

;; ------------------------
;; DAO Control Check
;; ------------------------
(define-public (is-dao-or-extension)
	(ok (asserts! (or (is-eq tx-sender .bigmarket-dao) (contract-call? .bigmarket-dao is-extension contract-caller)) err-unauthorised))
)

(define-read-only (get-epoch)
	(/ burn-block-height (var-get epoch-duration))
)

(define-read-only (get-last-claimed-epoch (user principal))
  (default-to u0 (map-get? last-claimed-epoch { who: user }))
)

(define-read-only (get-latest-claimable-epoch)
  (let ((cur (get-epoch)))
    (if (> cur u0) (- cur u1) u0) ;; floor and subtract 1, but never negative
  )
)

;; ------------------------
;; Trait Implementations
;; ------------------------
(define-read-only (get-balance (token-id uint) (who principal))
  (ok (default-to u0 (map-get? balances { token-id: token-id, owner: who })))
)

(define-public (set-launch-height)
  (begin
    (try! (is-dao-or-extension))
    (asserts! (is-eq (var-get launch-height) u0) err-unauthorised)
    (var-set launch-height burn-block-height)
    (ok (var-get launch-height))
  )
)

(define-public (set-epoch-duration (duration uint))
  (begin
    (try! (is-dao-or-extension))
    (asserts! (>= duration u100) err-epoch-too-short)
    (asserts! (<= duration u100000) err-epoch-too-long)
    (var-set epoch-duration duration)
    (ok (var-get epoch-duration))
  )
)

(define-read-only (get-total-weighted-supply-at (epoch uint))
  (ok (default-to u0 (map-get? total-weighted-supply { epoch: epoch })))
)

(define-read-only (get-total-weighted-supply)
  (ok (var-get weighted-supply))
)

(define-read-only (get-symbol)
	(ok (var-get token-symbol))
)

(define-read-only (get-name)
	(ok (var-get token-name))
)

(define-read-only (get-overall-balance (who principal))
  (ok (ft-get-balance bigr-token who))
)

(define-read-only (get-total-supply (token-id uint))
  (ok (default-to u0 (map-get? supplies token-id)))
)

(define-read-only (get-overall-supply)
  (ok (var-get overall-supply))
)

(define-read-only (get-decimals (token-id uint)) (ok u0))

(define-read-only (get-token-uri (token-id uint))
  (ok none)
)

(define-public (set-reward-per-epoch (new-reward uint))
  (begin
    (try! (is-dao-or-extension))
    (asserts! (<= new-reward u100000000000) err-too-high) ;; cap at 100k BIG
    (var-set reward-per-epoch new-reward)
    (print { event: "set-reward-per-epoch", new-reward: new-reward })
    (ok true)
  )
)
(define-public (set-tier-weight (token-id uint) (weight uint))
  (begin
    (try! (is-dao-or-extension))
    (map-set tier-weights token-id weight)
    (print { event: "set-tier-weight", token-id: token-id, weight: weight })
    (ok true)
  )
)

;; ------------------------
;; Mint / Burn
;; ------------------------
(define-public (mint (recipient principal) (token-id uint) (amount uint))
  (begin
    (try! (is-dao-or-extension))
    (mint-core recipient token-id amount)
  )
)

(define-private (mint-core (recipient principal) (token-id uint) (amount uint))
  (let (
    (current-epoch (/ burn-block-height (var-get epoch-duration)))
    (weight (default-to u1 (map-get? tier-weights token-id)))
    (weighted-amount (* amount weight))
    (old-supply (default-to u0 (map-get? supplies token-id)))
  )
    (begin
      (asserts! (> amount u0) err-zero-amount)
      (asserts! (and (> token-id u0) (<= token-id max-tier)) err-invalid-tier)

      (try! (ft-mint? bigr-token amount recipient))
      (try! (tag-nft { token-id: token-id, owner: recipient }))
      (map-set balances { token-id: token-id, owner: recipient }
        (+ amount (default-to u0 (map-get? balances { token-id: token-id, owner: recipient }))))
      (map-set supplies token-id (+ amount (default-to u0 (map-get? supplies token-id))))
      (var-set overall-supply (+ (var-get overall-supply) amount))
      (var-set weighted-supply (+ (var-get weighted-supply) weighted-amount))
      
      (let ((prev-total (default-to u0 (map-get? total-weighted-supply { epoch: current-epoch }))))
        (map-set total-weighted-supply { epoch: current-epoch } (+ prev-total weighted-amount)))

      ;; track epoch joined to avoid overpaying rewards
      (if (is-none (map-get? join-epoch { who: recipient }))
            (map-set join-epoch { who: recipient } current-epoch)
            true)
      
      ;; update minted for this epoch
      (map-set minted-in-epoch { epoch: current-epoch }
        (+ weighted-amount (default-to u0 (map-get? minted-in-epoch { epoch: current-epoch }))))
      
      (map-set minted-in-epoch-by { epoch: current-epoch, who: recipient }
        (+ weighted-amount (default-to u0 (map-get? minted-in-epoch-by { epoch: current-epoch, who: recipient }))))
      
      (map-set user-total-rep { who: recipient }
        (+ weighted-amount (default-to u0 (map-get? user-total-rep { who: recipient }))))

      (print { event: "sft_mint", token-id: token-id, amount: amount, recipient: recipient })
      (ok true)
    )
  )
)

(define-public (burn (owner principal) (token-id uint) (amount uint))
  (begin
    (try! (is-dao-or-extension))
    (burn-core owner token-id amount)
  )
)
(define-private (burn-core (owner principal) (token-id uint) (amount uint))
  (let (
    (current-epoch (/ burn-block-height (var-get epoch-duration)))
    (weight (default-to u1 (map-get? tier-weights token-id)))
    (weighted-amount (* amount weight))
    (current (default-to u0 (map-get? balances { token-id: token-id, owner: owner })))
    (old-supply (default-to u0 (map-get? supplies token-id)))
  )
    (begin
      (asserts! (>= current amount) err-insufficient-balance)
      (try! (ft-burn? bigr-token amount owner))
      (map-set balances { token-id: token-id, owner: owner } (- current amount))
      (map-set supplies token-id (- (unwrap-panic (get-total-supply token-id)) amount))
      (var-set overall-supply (- (var-get overall-supply) amount))

      ;; Decrement epoch-level mint counters
      (let (
        (prev-total (default-to u0 (map-get? minted-in-epoch { epoch: current-epoch })))
        (prev-user (default-to u0 (map-get? minted-in-epoch-by { epoch: current-epoch, who: owner })))
      )
        (map-set minted-in-epoch { epoch: current-epoch }
          (if (> prev-total weighted-amount) (- prev-total weighted-amount) u0))
        (map-set minted-in-epoch-by { epoch: current-epoch, who: owner }
          (if (> prev-user weighted-amount) (- prev-user weighted-amount) u0))
      )
      ;; update running weighted total
      (let ((prev (var-get weighted-supply)))
        (if (> prev weighted-amount)
            (var-set weighted-supply (- prev weighted-amount))
            (var-set weighted-supply u0)))

      (let ((prev-total (default-to u0 (map-get? total-weighted-supply { epoch: current-epoch }))))
        (map-set total-weighted-supply
          { epoch: current-epoch }
          (if (> prev-total weighted-amount)
              (- prev-total weighted-amount)
              u0)))

      (let ((prev-rep (default-to u0 (map-get? user-total-rep { who: owner }))))
        (map-set user-total-rep { who: owner }
          (if (> prev-rep weighted-amount)
              (- prev-rep weighted-amount)
              u0)))

      (try! (nft-burn? bigr-id { token-id: token-id, owner: owner } owner))
      (print { event: "sft_burn", token-id: token-id, amount: amount, sender: owner })
      (ok true)
    )
  )
)

;; ------------------------
;; Transfer (DAO-only)
;; ------------------------
(define-public (transfer (token-id uint) (amount uint) (sender principal) (recipient principal))
  (begin
    (try! (is-dao-or-extension))
    (transfer-core token-id amount sender recipient)
  )
)
(define-private (transfer-core (token-id uint) (amount uint) (sender principal) (recipient principal))
  (begin
    (asserts! (> amount u0) err-zero-amount)
    (let (
        (sender-balance (default-to u0 (map-get? balances { token-id: token-id, owner: sender })))
        (weight (default-to u1 (map-get? tier-weights token-id)))
        (weighted-amount (* amount weight))
        (epoch (/ burn-block-height (var-get epoch-duration)))
      )
      (asserts! (>= sender-balance amount) err-insufficient-balance)
      (try! (ft-transfer? bigr-token amount sender recipient))
      (try! (tag-nft { token-id: token-id, owner: sender }))
      (try! (tag-nft { token-id: token-id, owner: recipient }))
      (map-set balances { token-id: token-id, owner: sender } (- sender-balance amount))
      (map-set balances { token-id: token-id, owner: recipient }
        (+ amount (default-to u0 (map-get? balances { token-id: token-id, owner: recipient }))))

      ;; adjust minted-in-epoch-by so transferred tokens stay new for this epoch
      (let (
        (sender-prev (default-to u0 (map-get? minted-in-epoch-by {epoch: epoch, who: sender})))
        (recipient-prev (default-to u0 (map-get? minted-in-epoch-by {epoch: epoch, who: recipient})))
      )
        (map-set minted-in-epoch-by {epoch: epoch, who: sender}
          (if (> sender-prev weighted-amount) (- sender-prev weighted-amount) u0))
        (map-set minted-in-epoch-by {epoch: epoch, who: recipient}
          (+ recipient-prev weighted-amount))
      )

      ;; adjust user-total-rep for transferred tokens
      (let ((sender-rep (default-to u0 (map-get? user-total-rep { who: sender })))
            (recipient-rep (default-to u0 (map-get? user-total-rep { who: recipient }))))
        (map-set user-total-rep { who: sender }
          (if (> sender-rep weighted-amount)
              (- sender-rep weighted-amount)
              u0))
        (map-set user-total-rep { who: recipient } (+ recipient-rep weighted-amount)))

      (print { event: "sft_transfer", token-id: token-id, amount: amount, sender: sender, recipient: recipient })
      (ok true)
    )
  )
)

(define-public (transfer-memo (token-id uint) (amount uint) (sender principal) (recipient principal) (memo (buff 34)))
  (begin
    (try! (transfer token-id amount sender recipient))
    (print memo)
    (ok true)
  )
)

(define-public (transfer-many (transfers (list 200 { token-id: uint, amount: uint, sender: principal, recipient: principal })))
  (fold transfer-many-iter transfers (ok true))
)

(define-public (transfer-many-memo (transfers (list 200 { token-id: uint, amount: uint, sender: principal, recipient: principal, memo: (buff 34) })))
  (fold transfer-many-memo-iter transfers (ok true))
)

;; -------------------------
;; Claims for big from bigr
;; individual and batch supported..
;; -------------------------

(define-public (claim-big-reward)
  (claim-big-reward-for-user tx-sender)
)

(define-public (claim-big-reward-batch (users (list 100 principal)))
  (fold claim-big-reward-batch-iter users (ok u0))
)

(define-private (claim-big-reward-batch-iter (user principal) (acc (response uint uint)))
  (let (
        (a (unwrap! acc err-claims-zero-total))
        (b (unwrap! (claim-big-reward-for-user user) err-claims-zero-total))
      )
    (ok (+ a b))
  )
)

(define-private (claim-big-reward-for-user (user principal))
  (let (
        (epoch (/ burn-block-height (var-get epoch-duration)))
        (claim-epoch (get-latest-claimable-epoch))
        (last-claim (default-to u0 (map-get? last-claimed-epoch { who: user })))
        (joined (default-to epoch (map-get? join-epoch { who: user })))

        ;; epoch-level
        (weighted-total (var-get weighted-supply))
        (minted-this-epoch (default-to u0 (map-get? minted-in-epoch { epoch: epoch })))
        (total (if (> weighted-total minted-this-epoch)
                   (- weighted-total minted-this-epoch)
                   u0))

        ;; user-level
        (user-total (default-to u0 (map-get? user-total-rep { who: user })))
        (user-this-epoch (default-to u0 (map-get? minted-in-epoch-by { epoch: epoch, who: user })))
        (rep (if (> user-total user-this-epoch)
                 (- user-total user-this-epoch)
                 u0))
    )

    (if (and
          (> total u0)
          (> rep u0)
          (< last-claim claim-epoch)
          (< joined epoch))
      (let (
            ;; scaled proportional share
            (share-scaled (/ (* (* rep (var-get reward-per-epoch)) SCALE) total))
            (share (/ share-scaled SCALE))
          )

        (map-set last-claimed-epoch { who: user } claim-epoch)

        (try! (contract-call? .bme006-0-treasury sip010-transfer share user none .bme000-0-governance-token))
        (print { event: "big-claim", user: user, epoch: epoch, claim-epoch: claim-epoch, rep: rep, total: total, share: share, reward-per-epoch: (var-get reward-per-epoch)})
        (ok share)
      )
      (ok u0)
    )
  )
)

;; ------------------------
;; Helpers
;; ------------------------
(define-private (tag-nft (nft-token-id { token-id: uint, owner: principal }))
  (begin
    (if (is-some (nft-get-owner? bigr-id nft-token-id))
      (try! (nft-burn? bigr-id nft-token-id (get owner nft-token-id)))
      true)
    (nft-mint? bigr-id nft-token-id (get owner nft-token-id))
  )
)

(define-private (transfer-many-iter (item { token-id: uint, amount: uint, sender: principal, recipient: principal }) (prev (response bool uint)))
  (match prev ok-prev (transfer (get token-id item) (get amount item) (get sender item) (get recipient item)) err-prev prev)
)

(define-private (transfer-many-memo-iter (item { token-id: uint, amount: uint, sender: principal, recipient: principal, memo: (buff 34) }) (prev (response bool uint)))
  (match prev ok-prev (transfer-memo (get token-id item) (get amount item) (get sender item) (get recipient item) (get memo item)) err-prev prev)
)

(define-read-only (get-weighted-supply)
  (ok (var-get weighted-supply))
)

;; dynamic weighted totals for user
(define-read-only (get-weighted-rep (user principal))
  (ok (default-to u0 (map-get? user-total-rep { who: user })))
)

;; dynamic weighted totals for overall supply pool
;; (define-read-only (get-weighted-supply)
;;   (let (
;;     (tiers (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20))
;;     (result (fold add-weighted-supply-for-tier tiers u0))
;;   )
;;     (ok result)
;;   )
;; )

;; (define-private (add-weighted-supply-for-tier (token-id uint) (acc uint))
;;   (let (
;;     (tier-supply (default-to u0 (map-get? supplies token-id)))
;;     (weight (default-to u1 (map-get? tier-weights token-id)))
;;   )
;;     (+ acc (* tier-supply weight))
;;   )
;; )

;; --- Extension callback

(define-public (callback (sender principal) (memo (buff 34)))
	(ok true)
)
