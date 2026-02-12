;; ---------------------------------
;; Fixed Addresses
;; ---------------------------------
(define-constant SENDER 'SZ2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKQ9H6DPR)
(define-constant RECIPIENT 'SM2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKQVX8X0G)

;; ---------------------------------
;; Fungible Token
;; ---------------------------------
(define-fungible-token novel-token-19)

(define-public (mint-ft (amount uint))
  (begin
    (asserts! (is-eq tx-sender SENDER) (err u401))
    (ft-mint? novel-token-19 amount SENDER)
  )
)

(define-public (transfer-ft (amount uint))
  (ft-transfer? novel-token-19 amount SENDER RECIPIENT)
)

;; ---------------------------------
;; Non-Fungible Token
;; ---------------------------------
(define-non-fungible-token hello-nft uint)

(define-public (mint-nft (id uint))
  (begin
    (asserts! (is-eq tx-sender SENDER) (err u401))
    (nft-mint? hello-nft id SENDER)
  )
)

(define-public (transfer-nft (id uint))
  (nft-transfer? hello-nft id SENDER RECIPIENT)
)

;; ---------------------------------
;; Event
;; ---------------------------------
(define-public (emit-event)
  (begin
    (print "Event! Hello world")
    (ok u1)
  )
)

;; ---------------------------------
;; STX Test Operations
;; ---------------------------------
(define-public (test-stx)
  (begin
    (asserts! (is-eq tx-sender SENDER) (err u401))
    (unwrap-panic (stx-transfer? u60 SENDER RECIPIENT))
    (unwrap-panic (stx-burn? u20 SENDER))
    (ok u1)
  )
)

;; ---------------------------------
;; Key-Value Storage
;; ---------------------------------
(define-map store
  { key: (buff 32) }
  { value: (buff 32) }
)

(define-public (set-value (key (buff 32)) (value (buff 32)))
  (begin
    (map-set store { key: key } { value: value })
    (ok u1)
  )
)

(define-read-only (get-value (key (buff 32)))
  (map-get? store { key: key })
)
