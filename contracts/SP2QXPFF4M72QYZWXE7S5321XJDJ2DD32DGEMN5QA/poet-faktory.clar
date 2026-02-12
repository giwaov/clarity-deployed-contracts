;; SP2QXPFF4M72QYZWXE7S5321XJDJ2DD32DGEMN5QA.poet-faktory
;; PoetAI Token - Powered By Faktory.fun
;;
;; Tokenomics:
;; - 80% retained by PoetAI (treasury)
;; - 16% to DEX for bonding curve
;; - 4% to pre-launch participants
;; - 1 POET = 1 governance vote
;; - 75% profits to holders, 25% reinvested
;; - 95% required to change core provisions

(impl-trait 'SP3XXMS38VTAWTVPE5682XSBFXPTH7XCPEBTX8AN2.faktory-trait-v1.sip-010-trait)

(define-constant ERR-NOT-AUTHORIZED u401)
(define-fungible-token poet MAX)
(define-constant MAX u100000000000000000)

(define-data-var contract-owner principal tx-sender)
(define-data-var token-uri (optional (string-utf8 256)) (some u"https://aibtc.dev/tokens/poet.json"))

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR-NOT-AUTHORIZED))
    (try! (ft-transfer? poet amount sender recipient))
    (match memo m (print m) 0x)
    (ok true)))

(define-public (set-token-uri (value (string-utf8 256)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (var-set token-uri (some value))
    (ok (print {notification: "token-metadata-update", payload: {contract-id: (as-contract tx-sender), token-class: "ft"}}))))

(define-read-only (get-balance (account principal)) (ok (ft-get-balance poet account)))
(define-read-only (get-name) (ok "PoetAI"))
(define-read-only (get-symbol) (ok "POET"))
(define-read-only (get-decimals) (ok u8))
(define-read-only (get-total-supply) (ok (ft-get-supply poet)))
(define-read-only (get-token-uri) (ok (var-get token-uri)))

(define-public (set-contract-owner (new-owner principal))
  (begin (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED)) (ok (var-set contract-owner new-owner))))

(define-public (send-many (recipients (list 200 {to: principal, amount: uint, memo: (optional (buff 34))})))
  (fold check-err (map send-token recipients) (ok true)))

(define-private (check-err (result (response bool uint)) (prior (response bool uint)))
  (match prior ok-value result err-value (err err-value)))

(define-private (send-token (recipient {to: principal, amount: uint, memo: (optional (buff 34))}))
  (transfer (get amount recipient) tx-sender (get to recipient) (get memo recipient)))

(begin
  ;; 80% to treasury (PoetAI retained), 16% to DEX, 4% to pre-launch
  (try! (ft-mint? poet (/ (* MAX u80) u100) 'SP2QXPFF4M72QYZWXE7S5321XJDJ2DD32DGEMN5QA))
  (try! (ft-mint? poet (/ (* MAX u16) u100) 'SP2QXPFF4M72QYZWXE7S5321XJDJ2DD32DGEMN5QA.poet-faktory-dex))
  (try! (ft-mint? poet (/ (* MAX u4) u100) 'SP2QXPFF4M72QYZWXE7S5321XJDJ2DD32DGEMN5QA.poet-pre-faktory))
  (print {
    type: "faktory-trait-v1",
    name: "poet",
    symbol: "POET",
    token-uri: u"https://aibtc.dev/tokens/poet.json",
    tokenContract: (as-contract tx-sender),
    supply: MAX,
    decimals: u8,
    targetStx: u5000000,
    tokenToDex: (/ (* MAX u16) u100),
    tokenToPrelaunch: (/ (* MAX u4) u100),
    treasuryRetained: (/ (* MAX u80) u100),
    profitToHolders: u75,
    reinvested: u25,
    coreChangeThreshold: u95
  }))