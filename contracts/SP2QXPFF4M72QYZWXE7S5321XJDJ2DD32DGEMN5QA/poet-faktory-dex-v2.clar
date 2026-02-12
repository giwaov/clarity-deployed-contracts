;; SP2QXPFF4M72QYZWXE7S5321XJDJ2DD32DGEMN5QA.poet-faktory-dex-v2
;; PoetAI DEX v2 - Bonding curve with 0.05 BTC graduation

(use-trait faktory-token 'SP3XXMS38VTAWTVPE5682XSBFXPTH7XCPEBTX8AN2.faktory-trait-v1.sip-010-trait)

(define-constant ERR-MARKET-CLOSED (err u1001))
(define-constant ERR-STX-NON-POSITIVE (err u1002))
(define-constant ERR-STX-BALANCE-TOO-LOW (err u1003))
(define-constant ERR-FT-NON-POSITIVE (err u1004))
(define-constant ERR-FETCHING-BUY-INFO (err u1005))
(define-constant ERR-FETCHING-SELL-INFO (err u1006))
(define-constant ERR-AMOUNT-TOO-HIGH (err u1007))
(define-constant ERR-AMOUNT-TOO-LOW (err u1008))
(define-constant ERR-TOKEN-NOT-AUTH (err u401))

(define-constant FEE-RECEIVER 'SMHAVPYZ8BVD0BHBBQGY5AQVVGNQY4TNHAKGPYP)
(define-constant G-RECEIVER 'SM3NY5HXXRNCHS1B65R78CYAC1TQ6DEMN3C0DN74S)
(define-constant FAKTORY 'SMH8FRN30ERW1SX26NJTJCKTDR3H27NRJ6W75WQE)
(define-constant ORIGINATOR 'SP2QXPFF4M72QYZWXE7S5321XJDJ2DD32DGEMN5QA)
(define-constant DEX-TOKEN 'SP2QXPFF4M72QYZWXE7S5321XJDJ2DD32DGEMN5QA.poet-faktory)
(define-constant PRE-CONTRACT 'SP2QXPFF4M72QYZWXE7S5321XJDJ2DD32DGEMN5QA.poet-pre-faktory)
(define-constant POOL-CONTRACT 'SP2QXPFF4M72QYZWXE7S5321XJDJ2DD32DGEMN5QA.xyk-pool-sbtc-poet-v-1-2)

(define-constant TARGET_STX u5000000)
(define-constant FAK_STX u1000000)
(define-constant GRAD-FEE u100000)
(define-constant DEX-AMOUNT u250000)

(define-data-var open bool false)
(define-data-var bonded bool false)
(define-data-var fak-ustx uint u0)
(define-data-var ft-balance uint u0)
(define-data-var stx-balance uint u0)
(define-data-var premium uint u25)

(define-read-only (get-open) (ok (var-get open)))
(define-read-only (get-bonded) (ok (var-get bonded)))

(define-read-only (get-in (ubtc uint))
  (let ((total-stx (var-get stx-balance))
        (total-stk (+ total-stx (var-get fak-ustx)))
        (total-ft (var-get ft-balance))
        (k (* total-ft total-stk))
        (feek (/ (* ubtc u2) u100))
        (fee (if (>= feek u3) feek u3))
        (stx-in (if (> ubtc fee) (- ubtc fee) u0))
        (new-stk (+ total-stk stx-in))
        (new-ft (if (> new-stk u0) (/ k new-stk) u0))
        (tokens-out (if (> total-ft new-ft) (- total-ft new-ft) u0))
        (stx-to-grad (/ (* (if (> TARGET_STX total-stx) (- TARGET_STX total-stx) u0) u103) u100)))
    (ok {total-stx: total-stx, total-stk: total-stk, ft-balance: total-ft, k: k, fee: fee,
         stx-in: stx-in, new-stk: new-stk, new-ft: new-ft, tokens-out: tokens-out,
         new-stx: (+ total-stx stx-in), stx-to-grad: stx-to-grad})))

(define-read-only (get-out (amount uint))
  (let ((total-stx (var-get stx-balance))
        (total-stk (+ total-stx (var-get fak-ustx)))
        (total-ft (var-get ft-balance))
        (k (* total-ft total-stk))
        (new-ft (+ total-ft amount))
        (new-stk (if (> new-ft u0) (/ k new-ft) u0))
        (stx-out (if (>= total-stk (+ new-stk u5)) (- (- total-stk new-stk) u1) u0))
        (feek (/ (* stx-out u2) u100))
        (fee (if (>= feek u3) feek u3))
        (stx-to-receiver (if (> stx-out fee) (- stx-out fee) u0)))
    (ok {total-stx: total-stx, total-stk: total-stk, ft-balance: total-ft, k: k,
         new-ft: new-ft, new-stk: new-stk, stx-out: stx-out, fee: fee,
         stx-to-receiver: stx-to-receiver, new-stx: (if (> total-stx stx-out) (- total-stx stx-out) u0)})))

(define-public (open-market)
  (begin
    (asserts! (not (var-get bonded)) ERR-MARKET-CLOSED)
    (var-set open true)
    (ok true)))

(define-public (buy (ft <faktory-token>) (ubtc uint))
  (begin
    (if (not (var-get open)) (try! (open-market)) true)
    (asserts! (is-eq DEX-TOKEN (contract-of ft)) ERR-TOKEN-NOT-AUTH)
    (asserts! (var-get open) ERR-MARKET-CLOSED)
    (asserts! (>= ubtc u4) ERR-STX-NON-POSITIVE)
    (let ((info (unwrap! (get-in ubtc) ERR-FETCHING-BUY-INFO))
          (fee (get fee info))
          (pre-fee (/ (* fee u40) u100))
          (stx-in (get stx-in info))
          (tokens-out (get tokens-out info))
          (new-stx (get new-stx info))
          (new-ft (get new-ft info))
          (stx-max (/ (* (get stx-to-grad info) u115) u100)))
      (asserts! (<= ubtc stx-max) ERR-AMOUNT-TOO-HIGH)
      (asserts! (> tokens-out u0) ERR-AMOUNT-TOO-LOW)
      ;; Transfer fees
      (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token transfer (- fee pre-fee) tx-sender FEE-RECEIVER none))
      (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token transfer pre-fee tx-sender PRE-CONTRACT none))
      ;; Transfer sBTC to DEX
      (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token transfer stx-in tx-sender (as-contract tx-sender) none))
      ;; Transfer tokens to buyer
      (try! (as-contract (contract-call? ft transfer tokens-out tx-sender tx-sender none)))
      ;; Check graduation
      (if (>= new-stx TARGET_STX)
          (let ((premium-amount (/ (* new-ft (var-get premium)) u100))
                (amm-amount (- new-ft premium-amount))
                (agent-amount (/ (* premium-amount u60) u100))
                (originator-amount (- premium-amount agent-amount))
                (amm-ustx (- new-stx GRAD-FEE))
                (xyk-burn-amount (- (sqrti (* amm-ustx amm-amount)) u1)))
            (try! (as-contract (contract-call? ft transfer agent-amount tx-sender FAKTORY none)))
            (try! (as-contract (contract-call? ft transfer originator-amount tx-sender ORIGINATOR none)))
            (try! (as-contract (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2 create-pool
                   'SP2QXPFF4M72QYZWXE7S5321XJDJ2DD32DGEMN5QA.xyk-pool-sbtc-poet-v-1-2 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token ft amm-ustx amm-amount xyk-burn-amount
                   u10 u40 u10 u40 'SP31C60QVZKZ9CMMZX73TQ3F3ZZNS89YX2DCCFT8P
                   u"https://aibtc.dev/tokens/poet.json" true)))
            (try! (as-contract (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token transfer GRAD-FEE tx-sender G-RECEIVER none)))
            (var-set open false)
            (var-set bonded true)
            (var-set stx-balance u0)
            (var-set ft-balance u0)
            (print {type: "graduated", pool: POOL-CONTRACT})
            (ok true))
          (begin
            (var-set stx-balance new-stx)
            (var-set ft-balance new-ft)
            (print {type: "buy", tokens-out: tokens-out, stx-in: stx-in})
            (ok true))))))

(define-public (sell (ft <faktory-token>) (amount uint))
  (begin
    (asserts! (is-eq DEX-TOKEN (contract-of ft)) ERR-TOKEN-NOT-AUTH)
    (asserts! (var-get open) ERR-MARKET-CLOSED)
    (asserts! (> amount u0) ERR-FT-NON-POSITIVE)
    (let ((info (unwrap! (get-out amount) ERR-FETCHING-SELL-INFO))
          (stx-out (get stx-out info))
          (fee (get fee info))
          (pre-fee (/ (* fee u40) u100))
          (stx-to-receiver (get stx-to-receiver info))
          (new-stx (get new-stx info))
          (new-ft (get new-ft info)))
      (asserts! (>= stx-out u4) ERR-AMOUNT-TOO-LOW)
      (asserts! (>= (var-get stx-balance) stx-out) ERR-STX-BALANCE-TOO-LOW)
      ;; Transfer tokens to DEX
      (try! (contract-call? ft transfer amount tx-sender (as-contract tx-sender) none))
      ;; Transfer sBTC to seller
      (try! (as-contract (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token transfer stx-to-receiver tx-sender tx-sender none)))
      ;; Transfer fees
      (try! (as-contract (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token transfer (- fee pre-fee) tx-sender FEE-RECEIVER none)))
      (try! (as-contract (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token transfer pre-fee tx-sender PRE-CONTRACT none)))
      (var-set stx-balance new-stx)
      (var-set ft-balance new-ft)
      (print {type: "sell", amount: amount, stx-out: stx-to-receiver})
      (ok true))))

(begin
  (var-set fak-ustx FAK_STX)
  (var-set stx-balance DEX-AMOUNT)
  (var-set ft-balance u16000000000000000)
  (print {type: "faktory-dex", token: DEX-TOKEN, pool: POOL-CONTRACT, target: TARGET_STX}))